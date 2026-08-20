import pytest
from fastapi.testclient import TestClient
from fastapi import HTTPException
from unittest.mock import patch
from main import app
from auth.dependencies import get_current_user
from features.wallet.schemas import CreateOrderResponse

client = TestClient(app, raise_server_exceptions=False)

def override_customer():
    return {"uid": "test-user-123", "email": "test@example.com", "role": "customer"}




@pytest.fixture(autouse=True)
def apply_overrides():
    app.dependency_overrides[get_current_user] = override_customer
    yield
    app.dependency_overrides.clear()

def test_deposit_order_min_amount_validation():
    # Amount below minimum INR 20 -> 422
    response = client.post("/api/wallet/orders/deposit", json={"amount": 10.0})
    assert response.status_code == 422


def test_deposit_order_max_amount_validation():
    # Amount above maximum INR 500 -> 422
    response = client.post("/api/wallet/orders/deposit", json={"amount": 1000.0})
    assert response.status_code == 422


def test_deposit_order_success():
    with patch("features.wallet.service.WalletService.create_deposit_order") as mock_create:
        mock_create.return_value = CreateOrderResponse(
            razorpay_order_id="order_mock_test123",
            amount_paise=5000,
            amount_rupees=50.0,
            currency="INR",
            key_id="rzp_test_KEY",
            deposit_id="dep_123",
        )
        response = client.post("/api/wallet/orders/deposit", json={"amount": 50.0})
        assert response.status_code == 200
        data = response.json()
        assert data["razorpay_order_id"] == "order_mock_test123"
        assert data["amount_paise"] == 5000
        assert data["amount_rupees"] == 50.0


def test_deposit_order_service_error_500():
    with patch("features.wallet.service.WalletService.create_deposit_order") as mock_create:
        mock_create.side_effect = Exception("Razorpay API timeout")
        response = client.post("/api/wallet/orders/deposit", json={"amount": 50.0})
        assert response.status_code == 500


def test_cart_checkout_empty_items():
    response = client.post("/api/orders/checkout", json={"items": [], "payment_method": "wallet"})
    assert response.status_code == 422
