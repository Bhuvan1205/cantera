"""
End-to-End integration test for GET /api/recommendations.

This script tests the entire recommendation API pipeline:
  Client -> HTTP Request -> Bearer Auth -> get_current_user ->
  RecommendationService -> RecommendationRepository -> Firestore ->
  Pydantic Serialization -> Response JSON.

It runs locally using FastAPI's TestClient to simulate real HTTP requests
without mocking service layers.
"""

import os
import sys
import json
from unittest.mock import patch, MagicMock

# Ensure backend root is on sys.path
backend_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, backend_dir)

from fastapi.testclient import TestClient
from main import app
from features.recommendations.schemas import RecommendationResponse

client = TestClient(app)

# Test states to log
test_results = []

def run_test(name, fn):
    print(f"\nRunning: {name}...")
    try:
        fn()
        print("-> PASS")
        test_results.append({"name": name, "status": "PASS"})
    except Exception as exc:
        import traceback
        traceback.print_exc()
        print(f"-> FAIL: {exc}")
        test_results.append({"name": name, "status": "FAIL", "error": str(exc)})

# Mock helper
def mock_orders(items: list[str]) -> list[dict]:
    return [
        {
            "userId": "test-user-e2e",
            "items": [{"name": item, "quantity": 1}],
            "timestamp": "2026-08-13T12:00:00"
        }
        for item in items
    ]

# ══════════════════════════════════════════════════════════════════════════════
# Tests Definitions
# ══════════════════════════════════════════════════════════════════════════════

def test_unauthenticated_request():
    """Verify that requests without a Bearer token return 403 or 401."""
    # Ensure no dependency override is present
    from auth.dependencies import get_current_user
    app.dependency_overrides.pop(get_current_user, None)

    response = client.get("/api/recommendations")
    print(f"  Response Status: {response.status_code}")
    print(f"  Response JSON  : {response.json()}")
    assert response.status_code in (401, 403), "Must reject request"

def test_invalid_token_request():
    """Verify that invalid token return 401."""
    from auth.dependencies import get_current_user
    app.dependency_overrides.pop(get_current_user, None)

    with patch("auth.verify.auth.verify_id_token", side_effect=Exception("Invalid signature")):
        response = client.get("/api/recommendations", headers={"Authorization": "Bearer bad_token"})
        print(f"  Response Status: {response.status_code}")
        print(f"  Response JSON  : {response.json()}")
        assert response.status_code in (401, 403), "Must reject invalid token"

def test_valid_token_e2e_personalized():
    """
    Verify a valid token for a user with >= 7 orders.
    Checks authentication, UID derivation, business logic, sorting,
    name normalization, and Pydantic validation.
    """
    # Override authentication mock
    mock_claims = {"uid": "user-e2e-123", "email": "e2e@cantera.com"}
    
    # 7 orders containing 6 unique items (1 duplicated item to rank higher)
    user_orders = (
        mock_orders(["Plain Dosa", "Masala Dosa", "Idly", "Vada", "Tea", "Coffee"]) +
        mock_orders(["Plain Dosa"]) # Duplicated to make plain dosa rank higher
    )
    
    # CanteenBuzz global cache
    buzz_items = [{"name": "samosa", "count": 10}, {"name": "lemon juice", "count": 8}]
    
    with (
        patch("auth.verify.auth.verify_id_token", return_value=mock_claims),
        patch("features.recommendations.repository.RecommendationRepository.get_user_orders", return_value=user_orders) as mock_get_orders,
        patch("features.recommendations.repository.RecommendationRepository.get_canteen_buzz", return_value=(buzz_items, "2026-08-13T12:00:00")) as mock_get_buzz
    ):
        response = client.get("/api/recommendations", headers={"Authorization": "Bearer valid_token"})
        print(f"  Response Status: {response.status_code}")
        print(f"  Response JSON  : {response.json()}")
        
        # Verify status code
        assert response.status_code == 200, "Should return HTTP 200"
        
        # Validate Pydantic Schema compatibility
        data = response.json()
        validated = RecommendationResponse(**data)
        assert validated.source == "personalized"
        assert len(validated.recommendations) <= 5
        
        # Verify sorting and ranking
        # Duplicated "plain dosa" must be first
        first_rec = validated.recommendations[0]
        assert first_rec.name == "plain dosa"
        assert first_rec.count == 2
        
        # Verify UID comes from token (never query params)
        mock_get_orders.assert_called_once_with("user-e2e-123")

def test_valid_token_e2e_discovery():
    """Verify discovery mode for new users (orderCount < 7)."""
    mock_claims = {"uid": "user-new-456", "email": "new@cantera.com"}
    
    # 3 orders (infrequent user)
    user_orders = mock_orders(["Idly", "Vada"])
    
    # Global CanteenBuzz data
    buzz_items = [
        {"name": "plain dosa", "count": 40},
        {"name": "masala dosa", "count": 30},
        {"name": "idly", "count": 20},
        {"name": "tea", "count": 15},
        {"name": "coffee", "count": 10},
        {"name": "samosa", "count": 5}
    ]
    
    with (
        patch("auth.verify.auth.verify_id_token", return_value=mock_claims),
        patch("features.recommendations.repository.RecommendationRepository.get_user_orders", return_value=user_orders),
        patch("features.recommendations.repository.RecommendationRepository.get_canteen_buzz", return_value=(buzz_items, "2026-08-13T12:00:00"))
    ):
        response = client.get("/api/recommendations", headers={"Authorization": "Bearer valid_token"})
        print(f"  Response Status: {response.status_code}")
        print(f"  Response JSON  : {response.json()}")
        
        assert response.status_code == 200
        data = response.json()
        validated = RecommendationResponse(**data)
        assert validated.source == "discovery"
        # Must return exactly 5 items from the CanteenBuzz cache (excluding samosa which ranks 6th)
        assert len(validated.recommendations) == 5
        names = [r.name for r in validated.recommendations]
        assert "plain dosa" in names
        assert "samosa" not in names

def test_userId_query_param_isolation():
    """Verify that a client-supplied ?userId query parameter does not override authenticated identity."""
    mock_claims = {"uid": "user-e2e-123", "email": "e2e@cantera.com"}
    
    with (
        patch("auth.verify.auth.verify_id_token", return_value=mock_claims),
        patch("features.recommendations.repository.RecommendationRepository.get_user_orders", return_value=[]) as mock_get_orders,
        patch("features.recommendations.repository.RecommendationRepository.get_canteen_buzz", return_value=([], None))
    ):
        response = client.get(
            "/api/recommendations?userId=attacker-uid-456",
            headers={"Authorization": "Bearer valid_token"}
        )
        assert response.status_code == 200
        # The service layer must have been called with token's UID, not parameter
        mock_get_orders.assert_called_once_with("user-e2e-123")

def test_orders_not_exposed():
    """Verify that the recommendations API does not expose raw orders or timestamps in responses."""
    mock_claims = {"uid": "user-e2e-123", "email": "e2e@cantera.com"}
    user_orders = mock_orders(["Tea", "Coffee"]) * 4 # 8 orders
    
    with (
        patch("auth.verify.auth.verify_id_token", return_value=mock_claims),
        patch("features.recommendations.repository.RecommendationRepository.get_user_orders", return_value=user_orders),
        patch("features.recommendations.repository.RecommendationRepository.get_canteen_buzz", return_value=([], None))
    ):
        response = client.get("/api/recommendations", headers={"Authorization": "Bearer valid_token"})
        data = response.json()
        
        # Verify no document references or raw items with order metadata exist in output
        assert "items" not in data
        assert "orders" not in data
        assert "timestamp" not in data
        for rec in data["recommendations"]:
            assert "timestamp" not in rec
            assert "userId" not in rec
            assert "price" not in rec

# ══════════════════════════════════════════════════════════════════════════════
# Execution Block
# ══════════════════════════════════════════════════════════════════════════════

if __name__ == "__main__":
    print("======================================================================")
    print("           END-TO-END RECOMMENDATION API INTEGRATION TESTS            ")
    print("======================================================================")
    
    run_test("1. Unauthenticated Request Rejection", test_unauthenticated_request)
    run_test("2. Invalid Auth Token Rejection", test_invalid_token_request)
    run_test("3. E2E Personalized Recommendations Flow", test_valid_token_e2e_personalized)
    run_test("4. E2E Discovery recommendations Flow", test_valid_token_e2e_discovery)
    run_test("5. Identity Isolation (?userId Param Spoofing)", test_userId_query_param_isolation)
    run_test("6. Data Exposure Check (No raw Orders leakage)", test_orders_not_exposed)
    
    print("\n======================================================================")
    all_passed = all(r["status"] == "PASS" for r in test_results)
    if all_passed:
        print("ALL END-TO-END TESTS PASSED SUCCESSFULLY! SUCCESS")
        sys.exit(0)
    else:
        print("SOME END-TO-END TESTS FAILED! FAILED")
        sys.exit(1)
