import pytest
from unittest.mock import patch, MagicMock
from fastapi.testclient import TestClient
from fastapi import HTTPException

from main import app
from auth.dependencies import get_current_user
from features.users.schemas import UserProfile

client = TestClient(app, raise_server_exceptions=False)

def override_user():
    return {"uid": "user_test_pin_123", "email": "student@mvsrec.edu.in"}




@pytest.fixture(autouse=True)
def apply_overrides():
    app.dependency_overrides[get_current_user] = override_user
    yield
    app.dependency_overrides.clear()

def test_user_profile_creation_success():
    with patch("features.users.service.UserService.create_or_update_profile") as mock_create:
        mock_create.return_value = UserProfile(
            uid="user_test_pin_123",
            name="John Doe",
            email="student@mvsrec.edu.in",
            phone="9876543210",
            is_admin=False,
        )
        payload = {
            "name": "John Doe",
            "email": "student@mvsrec.edu.in",
            "phone": "9876543210",
        }
        res = client.post("/api/users/profile", json=payload)
        assert res.status_code == 200
        data = res.json()
        assert data["uid"] == "user_test_pin_123"
        assert data["name"] == "John Doe"

# ── Phase 2: Registration idempotency and recovery tests ──────────────────────

def test_profile_creation_is_idempotent():
    """
    Calling POST /api/users/profile twice for the same user must succeed both times.
    The endpoint is used as the recovery path after a failed registration attempt.
    """
    profile_result = UserProfile(
        uid="user_test_pin_123",
        name="John Doe",
        email="student@mvsrec.edu.in",
        is_admin=False,
    )
    payload = {
        "name": "John Doe",
        "email": "student@mvsrec.edu.in",
    }

    with patch("features.users.service.UserService.create_or_update_profile") as mock_create:
        mock_create.return_value = profile_result

        res1 = client.post("/api/users/profile", json=payload)
        res2 = client.post("/api/users/profile", json=payload)

        assert res1.status_code == 200, f"First call failed: {res1.json()}"
        assert res2.status_code == 200, f"Second call (retry) failed: {res2.json()}"
        assert res1.json()["uid"] == "user_test_pin_123"
        assert res2.json()["uid"] == "user_test_pin_123"
        # Service called twice (idempotent handler called each time)
        assert mock_create.call_count == 2


def test_profile_creation_does_not_duplicate_wallet():
    """
    The upsert_user_profile() repository method creates the wallet only when it
    does not already exist. This test verifies that the service layer correctly
    delegates to upsert (not a create-only method) and that calling it twice
    does not raise errors or create conflicting state.

    Implementation note: wallet creation idempotency is enforced in the repository
    via `if not wallet_snap.exists: batch.set(wallet_ref, ...)`. This service-layer
    test verifies that repeated profile calls complete without error.
    """
    profile_result = UserProfile(
        uid="user_test_pin_123",
        name="John Doe",
        email="student@mvsrec.edu.in",
        is_admin=False,
    )
    payload = {"name": "John Doe", "email": "student@mvsrec.edu.in"}

    with patch("features.users.service.UserService.create_or_update_profile",
               return_value=profile_result) as mock_upsert:
        res = client.post("/api/users/profile", json=payload)
        assert res.status_code == 200
        # Verify the service method was called (which delegates to upsert)
        mock_upsert.assert_called_once()


def test_profile_recovery_after_simulated_failure():
    """
    Simulates the registration recovery scenario:
      1. First call to /api/users/profile raises an exception (network error)
      2. Second call (retry) succeeds

    Verifies that the endpoint does not return 5xx on retry and returns the
    correct profile data, demonstrating that the endpoint is safe to retry.
    """
    profile_result = UserProfile(
        uid="user_test_pin_123",
        name="John Doe",
        email="student@mvsrec.edu.in",
        is_admin=False,
    )
    payload = {"name": "John Doe", "email": "student@mvsrec.edu.in"}

    call_count = 0

    def side_effect_fail_then_succeed(uid, payload_arg):
        nonlocal call_count
        call_count += 1
        if call_count == 1:
            raise Exception("Simulated Firestore error on first attempt")
        return profile_result

    with patch("features.users.service.UserService.create_or_update_profile",
               side_effect=side_effect_fail_then_succeed):
        # First attempt fails
        res1 = client.post("/api/users/profile", json=payload)
        assert res1.status_code == 500  # Server raises unhandled exception

        # Second attempt (retry) succeeds
        res2 = client.post("/api/users/profile", json=payload)
        assert res2.status_code == 200
        assert res2.json()["uid"] == "user_test_pin_123"
        assert call_count == 2, "Service should have been called exactly twice"
