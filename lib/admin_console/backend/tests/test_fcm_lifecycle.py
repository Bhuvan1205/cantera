import pytest
from unittest.mock import patch
from fastapi.testclient import TestClient

from main import app
from auth.dependencies import get_current_user
import hashlib
from config.firebase import db

client = TestClient(app, raise_server_exceptions=False)

def override_user_a():
    return {"uid": "user_a", "email": "usera@example.com"}

def override_user_b():
    return {"uid": "user_b", "email": "userb@example.com"}


def test_fcm_cross_user_leakage_prevention():
    """
    Regression test: User A -> logs in -> gets FCM token -> logs out (deletes token) -> 
    User B -> logs in on SAME device -> gets SAME FCM token.
    Verifies that the backend correctly deletes User A's token and assigns it to User B.
    """
    device_token = "device_token_xyz_123"
    token_hash = hashlib.sha256(device_token.encode("utf-8")).hexdigest()

    old_override = app.dependency_overrides.get(get_current_user)
    try:
        # Step 1: User A logs in and registers the token
        app.dependency_overrides[get_current_user] = override_user_a
        with patch("features.users.repository.UserRepository.upsert_fcm_token") as mock_upsert:
            res = client.post("/api/users/fcm-token", json={"token": device_token})
            assert res.status_code == 200
            mock_upsert.assert_called_once_with("user_a", device_token)

        # Step 2: User A logs out and the Flutter client sends DELETE /fcm-token
        with patch("features.users.repository.UserRepository.delete_fcm_token") as mock_delete:
            res = client.request("DELETE", "/api/users/fcm-token", json={"token": device_token})
            assert res.status_code == 200
            mock_delete.assert_called_once_with("user_a", device_token)

        # Step 3: User B logs into the same device and registers the SAME token
        app.dependency_overrides[get_current_user] = override_user_b
        with patch("features.users.repository.UserRepository.upsert_fcm_token") as mock_upsert_b:
            res = client.post("/api/users/fcm-token", json={"token": device_token})
            assert res.status_code == 200
            mock_upsert_b.assert_called_once_with("user_b", device_token)
    finally:
        if old_override:
            app.dependency_overrides[get_current_user] = old_override
        elif get_current_user in app.dependency_overrides:
            del app.dependency_overrides[get_current_user]
