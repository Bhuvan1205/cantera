"""
Tests for GET /api/recommendations

Covers:
  - Authentication (missing / invalid / valid token)
  - UID derived from token only (never from query params)
  - User isolation
  - orderCount >= 7  → personalized mode
  - orderCount <  7  → discovery mode
  - CanteenBuzz present / missing / empty
  - Quantity aggregation
  - Top-5 limit enforced
  - Ranking: frequency desc, alphabetical tie-break

Testing pattern: pytest + TestClient + dependency_overrides + unittest.mock.patch
(identical to test_checkout.py, test_auth_stateless.py, etc.)
"""
import pytest
from unittest.mock import patch, MagicMock
from fastapi.testclient import TestClient
from fastapi import HTTPException

from main import app
from auth.dependencies import get_current_user

# ── TestClient (raise_server_exceptions=False so we can assert 5xx) ───────────
client = TestClient(app)

# ── Auth override helpers ─────────────────────────────────────────────────────

def _override_user_a():
    return {"uid": "user-a-uid", "email": "usera@test.com"}


def _override_user_b():
    return {"uid": "user-b-uid", "email": "userb@test.com"}


# ── Firestore mock helpers ────────────────────────────────────────────────────

def _make_order(items: list[dict]) -> dict:
    """Build a minimal Orders document dict."""
    return {"userId": "user-a-uid", "items": items, "timestamp": "2026-01-01"}


def _buzz_doc(top_items: list[dict]) -> tuple[list[dict], str]:
    """Return (top_items, updated_at) tuple as returned by the repository."""
    return top_items, "2026-01-01T00:00:00"


# ══════════════════════════════════════════════════════════════════════════════
# 1. AUTHENTICATION TESTS
# ══════════════════════════════════════════════════════════════════════════════


@pytest.fixture(autouse=True)
def cleanup_overrides():
    yield
    app.dependency_overrides.clear()

class TestAuthentication:

    def test_missing_token_returns_403(self):
        """No Authorization header → HTTPBearer raises 403."""
        # Remove any override so real bearer dependency runs
        app.dependency_overrides.pop(get_current_user, None)
        resp = client.get("/api/recommendations")
        assert resp.status_code in (401, 403), (
            f"Expected 401 or 403 for missing token, got {resp.status_code}"
        )

    def test_invalid_token_returns_401(self):
        """Malformed / expired token → 401 from verify_firebase_token."""
        app.dependency_overrides.pop(get_current_user, None)
        with patch("auth.verify.auth.verify_id_token") as mock_verify:
            mock_verify.side_effect = Exception("Token expired")
            resp = client.get(
                "/api/recommendations",
                headers={"Authorization": "Bearer bad.token.here"},
            )
        assert resp.status_code in (401, 403)

    def test_valid_token_returns_200(self):
        """Valid token accepted; service is called."""
        app.dependency_overrides[get_current_user] = _override_user_a
        with (
            patch("features.recommendations.repository.RecommendationRepository.get_user_orders",
                  return_value=[]),
            patch("features.recommendations.repository.RecommendationRepository.get_canteen_buzz",
                  return_value=([], None)),
        ):
            resp = client.get("/api/recommendations")
        assert resp.status_code == 200

    def test_no_userid_query_param_accepted(self):
        """
        The endpoint must NOT honour a ?userId= query param.
        Identity comes exclusively from the verified Firebase token.
        """
        app.dependency_overrides[get_current_user] = _override_user_a
        with (
            patch("features.recommendations.repository.RecommendationRepository.get_user_orders",
                  return_value=[]) as mock_get_orders,
            patch("features.recommendations.repository.RecommendationRepository.get_canteen_buzz",
                  return_value=([], None)),
        ):
            resp = client.get("/api/recommendations?userId=attacker-uid")
        assert resp.status_code == 200
        # The repository must have been called with the token-derived UID, not the query param
        mock_get_orders.assert_called_once_with("user-a-uid")


# ══════════════════════════════════════════════════════════════════════════════
# 2. USER ISOLATION TESTS
# ══════════════════════════════════════════════════════════════════════════════

class TestUserIsolation:

    def test_user_a_only_sees_their_own_orders(self):
        """User A's request must query Orders with User A's UID."""
        app.dependency_overrides[get_current_user] = _override_user_a
        with (
            patch("features.recommendations.repository.RecommendationRepository.get_user_orders",
                  return_value=[]) as mock_get,
            patch("features.recommendations.repository.RecommendationRepository.get_canteen_buzz",
                  return_value=([], None)),
        ):
            client.get("/api/recommendations")
        mock_get.assert_called_once_with("user-a-uid")

    def test_user_b_cannot_get_user_a_recommendations(self):
        """Even if User B sends a request, only User B's UID is used."""
        app.dependency_overrides[get_current_user] = _override_user_b
        with (
            patch("features.recommendations.repository.RecommendationRepository.get_user_orders",
                  return_value=[]) as mock_get,
            patch("features.recommendations.repository.RecommendationRepository.get_canteen_buzz",
                  return_value=([], None)),
        ):
            client.get("/api/recommendations")
        mock_get.assert_called_once_with("user-b-uid")
        mock_get.assert_called_once()
        assert "user-a-uid" not in str(mock_get.call_args)


# ══════════════════════════════════════════════════════════════════════════════
# 3. orderCount THRESHOLD TESTS
# ══════════════════════════════════════════════════════════════════════════════

class TestOrderCountThreshold:

    def _item(self, name: str, qty: int = 1) -> dict:
        return {"name": name, "quantity": qty}

    def test_six_orders_uses_discovery_mode(self):
        """orderCount < 7 → source == 'discovery'."""
        app.dependency_overrides[get_current_user] = _override_user_a
        orders = [_make_order([self._item("Masala Dosa")]) for _ in range(6)]
        buzz = [{"name": "idly", "count": 10}]
        with (
            patch("features.recommendations.repository.RecommendationRepository.get_user_orders",
                  return_value=orders),
            patch("features.recommendations.repository.RecommendationRepository.get_canteen_buzz",
                  return_value=_buzz_doc(buzz)),
        ):
            resp = client.get("/api/recommendations")
        assert resp.status_code == 200
        assert resp.json()["source"] == "discovery"

    def test_seven_orders_uses_personalized_mode(self):
        """orderCount >= 7 → source == 'personalized'."""
        app.dependency_overrides[get_current_user] = _override_user_a
        orders = [_make_order([self._item("Masala Dosa")]) for _ in range(7)]
        with (
            patch("features.recommendations.repository.RecommendationRepository.get_user_orders",
                  return_value=orders),
            patch("features.recommendations.repository.RecommendationRepository.get_canteen_buzz",
                  return_value=([], None)),
        ):
            resp = client.get("/api/recommendations")
        assert resp.status_code == 200
        assert resp.json()["source"] == "personalized"

    def test_exactly_seven_is_personalized(self):
        """Boundary: 7 is personalized, not discovery."""
        app.dependency_overrides[get_current_user] = _override_user_a
        orders = [_make_order([self._item(f"Item{i}")]) for i in range(7)]
        with (
            patch("features.recommendations.repository.RecommendationRepository.get_user_orders",
                  return_value=orders),
            patch("features.recommendations.repository.RecommendationRepository.get_canteen_buzz",
                  return_value=([], None)),
        ):
            resp = client.get("/api/recommendations")
        assert resp.json()["source"] == "personalized"


# ══════════════════════════════════════════════════════════════════════════════
# 4. CANTEEN BUZZ INTEGRATION TESTS
# ══════════════════════════════════════════════════════════════════════════════

class TestCanteenBuzz:

    def test_canteen_buzz_consumed_in_discovery_mode(self):
        """Global CanteenBuzz items appear in discovery recommendations."""
        app.dependency_overrides[get_current_user] = _override_user_a
        buzz = [{"name": "plain dosa", "count": 20}, {"name": "idly", "count": 15}]
        with (
            patch("features.recommendations.repository.RecommendationRepository.get_user_orders",
                  return_value=[]),   # 0 orders → discovery
            patch("features.recommendations.repository.RecommendationRepository.get_canteen_buzz",
                  return_value=_buzz_doc(buzz)),
        ):
            resp = client.get("/api/recommendations")
        assert resp.status_code == 200
        names = [r["name"] for r in resp.json()["recommendations"]]
        assert "plain dosa" in names
        assert "idly" in names

    def test_missing_canteen_buzz_returns_fallback(self):
        """Missing CanteenBuzz document → source='fallback', empty recommendations."""
        app.dependency_overrides[get_current_user] = _override_user_a
        with (
            patch("features.recommendations.repository.RecommendationRepository.get_user_orders",
                  return_value=[]),
            patch("features.recommendations.repository.RecommendationRepository.get_canteen_buzz",
                  return_value=([], None)),   # missing doc
        ):
            resp = client.get("/api/recommendations")
        assert resp.status_code == 200
        data = resp.json()
        assert data["source"] == "fallback"
        assert data["recommendations"] == []

    def test_empty_canteen_buzz_top_items_safe(self):
        """CanteenBuzz doc exists but topItems is [] → graceful fallback."""
        app.dependency_overrides[get_current_user] = _override_user_a
        with (
            patch("features.recommendations.repository.RecommendationRepository.get_user_orders",
                  return_value=[]),
            patch("features.recommendations.repository.RecommendationRepository.get_canteen_buzz",
                  return_value=([], "2026-01-01T00:00:00")),
        ):
            resp = client.get("/api/recommendations")
        assert resp.status_code == 200
        assert resp.json()["source"] == "fallback"

    def test_canteen_buzz_supplements_sparse_personal_recs(self):
        """
        Personalized mode with < 5 unique candidates should be supplemented
        with CanteenBuzz global data (_merge_frequencies path).
        """
        app.dependency_overrides[get_current_user] = _override_user_a
        # 7 orders but only 3 unique items → candidate_frequencies.length < 5
        orders = [_make_order([{"name": "Item A", "quantity": 1}]) for _ in range(7)]
        buzz = [
            {"name": "item d", "count": 5},
            {"name": "item e", "count": 4},
            {"name": "item f", "count": 3},
        ]
        with (
            patch("features.recommendations.repository.RecommendationRepository.get_user_orders",
                  return_value=orders),
            patch("features.recommendations.repository.RecommendationRepository.get_canteen_buzz",
                  return_value=_buzz_doc(buzz)),
        ):
            resp = client.get("/api/recommendations")
        assert resp.status_code == 200
        data = resp.json()
        assert data["source"] == "personalized"
        names = [r["name"] for r in data["recommendations"]]
        # Personal item + global items should both appear
        assert "item a" in names
        assert len(names) > 1


# ══════════════════════════════════════════════════════════════════════════════
# 5. FREQUENCY AGGREGATION TESTS
# ══════════════════════════════════════════════════════════════════════════════

class TestFrequencyAggregation:

    def test_quantities_are_summed(self):
        """Items ordered in quantities > 1 must be counted by quantity, not occurrence."""
        app.dependency_overrides[get_current_user] = _override_user_a
        orders = [
            _make_order([{"name": "Masala Dosa", "quantity": 3}]),
            _make_order([{"name": "Masala Dosa", "quantity": 2}]),
            _make_order([{"name": "Idly", "quantity": 1}]),
        ] * 3   # 9 orders → personalized mode
        with (
            patch("features.recommendations.repository.RecommendationRepository.get_user_orders",
                  return_value=orders),
            patch("features.recommendations.repository.RecommendationRepository.get_canteen_buzz",
                  return_value=([], None)),
        ):
            resp = client.get("/api/recommendations")
        data = resp.json()
        recs = {r["name"]: r["count"] for r in data["recommendations"]}
        # masala dosa: (3+2)*3 = 15; idly: 1*3 = 3
        assert recs.get("masala dosa") == 15
        assert recs.get("idly") == 3

    def test_missing_quantity_defaults_to_1(self):
        """Items with no quantity field should default to qty=1."""
        app.dependency_overrides[get_current_user] = _override_user_a
        orders = [_make_order([{"name": "Plain Dosa"}]) for _ in range(7)]
        with (
            patch("features.recommendations.repository.RecommendationRepository.get_user_orders",
                  return_value=orders),
            patch("features.recommendations.repository.RecommendationRepository.get_canteen_buzz",
                  return_value=([], None)),
        ):
            resp = client.get("/api/recommendations")
        recs = {r["name"]: r["count"] for r in resp.json()["recommendations"]}
        assert recs.get("plain dosa") == 7

    def test_names_are_lowercased(self):
        """Item names must be normalised to lowercase (mirrors Dart .toLowerCase().trim())."""
        app.dependency_overrides[get_current_user] = _override_user_a
        orders = [
            _make_order([{"name": "MASALA DOSA", "quantity": 1}]),
            _make_order([{"name": "Masala Dosa", "quantity": 1}]),
        ] * 4   # 8 orders → personalized
        with (
            patch("features.recommendations.repository.RecommendationRepository.get_user_orders",
                  return_value=orders),
            patch("features.recommendations.repository.RecommendationRepository.get_canteen_buzz",
                  return_value=([], None)),
        ):
            resp = client.get("/api/recommendations")
        recs = {r["name"]: r["count"] for r in resp.json()["recommendations"]}
        # Both "MASALA DOSA" and "Masala Dosa" → aggregated under "masala dosa"
        assert "masala dosa" in recs
        assert recs["masala dosa"] == 8


# ══════════════════════════════════════════════════════════════════════════════
# 6. TOP-5 AND RANKING TESTS
# ══════════════════════════════════════════════════════════════════════════════

class TestRankingAndTopN:

    def test_at_most_five_items_returned(self):
        """Never return more than 5 recommendations."""
        app.dependency_overrides[get_current_user] = _override_user_a
        buzz = [{"name": f"item{i}", "count": 10 - i} for i in range(10)]
        with (
            patch("features.recommendations.repository.RecommendationRepository.get_user_orders",
                  return_value=[]),
            patch("features.recommendations.repository.RecommendationRepository.get_canteen_buzz",
                  return_value=_buzz_doc(buzz)),
        ):
            resp = client.get("/api/recommendations")
        assert len(resp.json()["recommendations"]) <= 5

    def test_higher_count_ranked_first(self):
        """Items with higher frequency must appear before lower-frequency items."""
        app.dependency_overrides[get_current_user] = _override_user_a
        buzz = [
            {"name": "banana milkshake", "count": 1},
            {"name": "masala dosa", "count": 50},
            {"name": "idly", "count": 30},
        ]
        with (
            patch("features.recommendations.repository.RecommendationRepository.get_user_orders",
                  return_value=[]),
            patch("features.recommendations.repository.RecommendationRepository.get_canteen_buzz",
                  return_value=_buzz_doc(buzz)),
        ):
            resp = client.get("/api/recommendations")
        names = [r["name"] for r in resp.json()["recommendations"]]
        assert names.index("masala dosa") < names.index("idly")
        assert names.index("idly") < names.index("banana milkshake")

    def test_alphabetical_tiebreak(self):
        """When counts are equal, items sorted alphabetically (a before z)."""
        app.dependency_overrides[get_current_user] = _override_user_a
        buzz = [
            {"name": "zebra cake", "count": 10},
            {"name": "apple pie", "count": 10},
            {"name": "mango lassi", "count": 10},
        ]
        with (
            patch("features.recommendations.repository.RecommendationRepository.get_user_orders",
                  return_value=[]),
            patch("features.recommendations.repository.RecommendationRepository.get_canteen_buzz",
                  return_value=_buzz_doc(buzz)),
        ):
            resp = client.get("/api/recommendations")
        names = [r["name"] for r in resp.json()["recommendations"]]
        # Alphabetical: apple pie < mango lassi < zebra cake
        assert names.index("apple pie") < names.index("mango lassi")
        assert names.index("mango lassi") < names.index("zebra cake")


# ══════════════════════════════════════════════════════════════════════════════
# 7. RESPONSE SCHEMA TESTS
# ══════════════════════════════════════════════════════════════════════════════

class TestResponseSchema:

    def test_response_has_required_fields(self):
        """Response must contain 'recommendations', 'source'."""
        app.dependency_overrides[get_current_user] = _override_user_a
        with (
            patch("features.recommendations.repository.RecommendationRepository.get_user_orders",
                  return_value=[]),
            patch("features.recommendations.repository.RecommendationRepository.get_canteen_buzz",
                  return_value=([], None)),
        ):
            resp = client.get("/api/recommendations")
        data = resp.json()
        assert "recommendations" in data
        assert "source" in data

    def test_each_recommendation_has_name_and_count(self):
        """Each item in recommendations must have 'name' and 'count'."""
        app.dependency_overrides[get_current_user] = _override_user_a
        buzz = [{"name": "idly", "count": 5}]
        with (
            patch("features.recommendations.repository.RecommendationRepository.get_user_orders",
                  return_value=[]),
            patch("features.recommendations.repository.RecommendationRepository.get_canteen_buzz",
                  return_value=_buzz_doc(buzz)),
        ):
            resp = client.get("/api/recommendations")
        for item in resp.json()["recommendations"]:
            assert "name" in item
            assert "count" in item
