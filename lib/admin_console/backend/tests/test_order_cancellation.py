import pytest
from unittest.mock import patch
from fastapi.testclient import TestClient
from fastapi import HTTPException

from main import app
from auth.dependencies import get_current_user
from features.orders.schemas import OrderDetail, OrderItem

client = TestClient(app, raise_server_exceptions=False)

def override_user():
    return {"uid": "cust_cancel_user", "email": "customer@example.com"}

app.dependency_overrides[get_current_user] = override_user


def test_order_cancellation_order_not_found():
    with patch("features.orders.repository.OrderRepository.cancel_order") as mock_cancel:
        mock_cancel.side_effect = HTTPException(status_code=404, detail="Order 'missing_ord' not found.")
        res = client.post("/api/orders/missing_ord/cancel")
        assert res.status_code == 404
        assert "not found" in res.json()["detail"]


def test_order_cancellation_not_in_placed_status():
    with patch("features.orders.repository.OrderRepository.cancel_order") as mock_cancel:
        mock_cancel.side_effect = HTTPException(
            status_code=400,
            detail="Order cannot be cancelled because it is in 'preparing' status.",
        )
        res = client.post("/api/orders/ord_prep_123/cancel")
        assert res.status_code == 400
        assert "preparing" in res.json()["detail"]


def test_order_cancellation_success():
    with patch("features.orders.repository.OrderRepository.cancel_order") as mock_cancel:
        mock_cancel.return_value = OrderDetail(
            order_id="ord_placed_123",
            user_id="cust_cancel_user",
            items=[OrderItem(name="Masala Dosa", price=60.0, quantity=2, category="Tiffins")],
            total=120.0,
            status="cancelled",
            overall_status="cancelled",
            token_number=10,
            payment_method="wallet",
            timestamp="1700000000",
            tokens=[],
        )
        res = client.post("/api/orders/ord_placed_123/cancel")
        assert res.status_code == 200
        data = res.json()
        assert data["order_id"] == "ord_placed_123"
        assert data["status"] == "cancelled"
        assert data["overall_status"] == "cancelled"
