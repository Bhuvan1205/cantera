import pytest
from unittest.mock import patch
from fastapi.testclient import TestClient
from fastapi import HTTPException

from main import app
from auth.dependencies import get_current_user
from features.orders.schemas import (
    CheckoutRequest,
    CheckoutCartItem,
    CheckoutResponse,
    CheckoutTokenDetail,
)

client = TestClient(app, raise_server_exceptions=False)

def override_customer():
    return {"uid": "test-user-456", "email": "customer@example.com", "role": "customer"}




@pytest.fixture(autouse=True)
def apply_overrides():
    app.dependency_overrides[get_current_user] = override_customer
    yield
    app.dependency_overrides.clear()

def test_checkout_empty_cart_fails():
    response = client.post("/api/orders/checkout", json={"items": [], "payment_method": "wallet"})
    assert response.status_code == 422


def test_checkout_invalid_quantity_fails():
    response = client.post(
        "/api/orders/checkout",
        json={"items": [{"menu_item_id": "item_1", "quantity": 0}], "payment_method": "wallet"},
    )
    assert response.status_code == 422


def test_checkout_successful_orchestration():
    with patch("features.orders.checkout_service.CheckoutService.execute_checkout") as mock_exec:
        mock_exec.return_value = CheckoutResponse(
            order_id="ord_mock_abc123",
            total=120,
            token_number=42,
            status="placed",
            payment_method="wallet",
            tokens=[
                CheckoutTokenDetail(
                    counter="bakery",
                    token_number=42,
                    qr_valid=True,
                )
            ],
        )
        payload = {
            "items": [{"menu_item_id": "item_123", "quantity": 2}],
            "payment_method": "wallet",
            "user_name": "Test User",
        }
        response = client.post("/api/orders/checkout", json=payload)
        assert response.status_code == 201
        data = response.json()
        assert data["order_id"] == "ord_mock_abc123"
        assert data["token_number"] == 42
        assert data["total"] == 120


def test_checkout_insufficient_stock_409_conflict():
    with patch("features.orders.checkout_service.CheckoutService.execute_checkout") as mock_exec:
        mock_exec.side_effect = HTTPException(status_code=409, detail="Insufficient stock for item_123")
        payload = {
            "items": [{"menu_item_id": "item_123", "quantity": 50}],
            "payment_method": "wallet",
        }
        response = client.post("/api/orders/checkout", json=payload)
        assert response.status_code == 409
        assert "Insufficient stock" in response.json()["detail"]


def test_checkout_insufficient_wallet_balance_409_conflict():
    with patch("features.orders.checkout_service.CheckoutService.execute_checkout") as mock_exec:
        mock_exec.side_effect = HTTPException(status_code=409, detail="Insufficient wallet balance. Required: INR 500, Available: INR 50")
        payload = {
            "items": [{"menu_item_id": "item_123", "quantity": 5}],
            "payment_method": "wallet",
        }
        response = client.post("/api/orders/checkout", json=payload)
        assert response.status_code == 409
        assert "Insufficient wallet balance" in response.json()["detail"]


def test_checkout_server_error_500():
    with patch("features.orders.checkout_service.CheckoutService.execute_checkout") as mock_exec:
        mock_exec.side_effect = Exception("Firestore transaction abort")
        payload = {
            "items": [{"menu_item_id": "item_123", "quantity": 1}],
            "payment_method": "wallet",
        }
        response = client.post("/api/orders/checkout", json=payload)
        assert response.status_code == 500
