import pytest
from unittest.mock import patch, MagicMock
from fastapi.testclient import TestClient
from fastapi import HTTPException

from main import app
from auth.dependencies import get_current_user

client = TestClient(app, raise_server_exceptions=False)

def override_user():
    return {"uid": "test_fcm_uid_123", "email": "user@example.com"}

@pytest.fixture(autouse=True)
def apply_overrides():
    app.dependency_overrides[get_current_user] = override_user
    yield
    app.dependency_overrides.clear()


def test_fcm_token_registration_success():
    """
    Valid FCM token registration succeeds and calls the service layer with
    the correctly derived UID from the dependency.
    """
    payload = {"token": "fcm_test_token_abc123"}
    app.dependency_overrides[get_current_user] = override_user
    
    with patch("features.users.service.UserService.register_fcm_token") as mock_register:
        res = client.post("/api/users/fcm-token", json=payload)
        assert res.status_code == 200
        assert res.json()["status"] == "success"
        
        # Verify that the service was called with the UID from the token, not the client payload
        mock_register.assert_called_once_with("test_fcm_uid_123", "fcm_test_token_abc123")


def test_fcm_token_empty_fails():
    """Empty FCM token string raises 400."""
    payload = {"token": ""}
    res = client.post("/api/users/fcm-token", json=payload)
    assert res.status_code == 400
    assert "must not be empty" in res.json()["detail"].lower()


def test_fcm_token_whitespace_fails():
    """Whitespace-only FCM token string raises 400."""
    payload = {"token": "   "}
    res = client.post("/api/users/fcm-token", json=payload)
    assert res.status_code == 400
    assert "must not be empty" in res.json()["detail"].lower()


def test_fcm_token_missing_payload_fails():
    """Missing token field in payload raises 422 Validation Error."""
    payload = {}
    res = client.post("/api/users/fcm-token", json=payload)
    assert res.status_code == 422
