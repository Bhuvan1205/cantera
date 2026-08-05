import pytest
from unittest.mock import patch, MagicMock
from fastapi.testclient import TestClient
from fastapi import HTTPException

from main import app
from auth.dependencies import get_current_user
from features.users.schemas import UserProfile, PickupPinInfo

client = TestClient(app, raise_server_exceptions=False)

def override_user():
    return {"uid": "user_test_pin_123", "email": "user@example.com"}

app.dependency_overrides[get_current_user] = override_user


def test_user_profile_creation_success():
    with patch("features.users.service.UserService.create_or_update_profile") as mock_create:
        mock_create.return_value = UserProfile(
            uid="user_test_pin_123",
            name="John Doe",
            email="user@example.com",
            phone="9876543210",
            is_admin=False,
            pickup_pin="1234",
        )
        payload = {
            "name": "John Doe",
            "email": "user@example.com",
            "phone": "9876543210",
            "pickup_pin": "1234",
        }
        res = client.post("/api/users/profile", json=payload)
        assert res.status_code == 200
        data = res.json()
        assert data["uid"] == "user_test_pin_123"
        assert data["name"] == "John Doe"


def test_user_pin_invalid_length_fails():
    res = client.post("/api/users/change-pin", json={"new_pin": "12"})
    assert res.status_code == 400
    assert "4 numeric digits" in res.json()["detail"]


def test_user_pin_non_numeric_fails():
    res = client.post("/api/users/change-pin", json={"new_pin": "abcd"})
    assert res.status_code == 400
    assert "4 numeric digits" in res.json()["detail"]


def test_user_pin_change_cooldown_active_429():
    with patch("features.users.repository.UserRepository.get_pickup_pin_info") as mock_info:
        mock_info.return_value = ({}, PickupPinInfo(has_pin=True, last_changed="2026-08-01T00:00:00Z", can_change_in_days=27))
        res = client.post("/api/users/change-pin", json={"new_pin": "4321"})
        assert res.status_code == 429
        assert "PIN can only be changed once every 30 days" in res.json()["detail"]


def test_user_pin_change_success():
    with patch("features.users.repository.UserRepository.get_pickup_pin_info") as mock_info, \
         patch("features.users.repository.UserRepository.update_pickup_pin") as mock_update:
        mock_info.return_value = ({}, PickupPinInfo(has_pin=True, last_changed=None, can_change_in_days=0))
        res = client.post("/api/users/change-pin", json={"new_pin": "4321"})
        assert res.status_code == 200
        assert res.json()["status"] == "success"
