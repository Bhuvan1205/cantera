import pytest
from unittest.mock import patch
from fastapi.testclient import TestClient
from fastapi import HTTPException

from main import app
from auth.dependencies import get_current_user, get_current_admin
from features.wallet.schemas import RefundRequestItem

client = TestClient(app, raise_server_exceptions=False)

def override_user():
    return {"uid": "cust_refund_user", "email": "customer@example.com"}

def override_admin():
    return {"uid": "admin_user_1", "email": "admin@example.com", "isAdmin": True}

app.dependency_overrides[get_current_user] = override_user
app.dependency_overrides[get_current_admin] = override_admin


def test_user_refund_request_order_not_found():
    with patch("features.wallet.repository.WalletRepository.create_refund_request") as mock_req:
        mock_req.side_effect = HTTPException(status_code=404, detail="Order 'missing_ord' not found.")
        res = client.post("/api/wallet/refunds/request", json={"order_id": "missing_ord", "reason": "Accidental order"})
        assert res.status_code == 404
        assert "not found" in res.json()["detail"]


def test_user_refund_request_not_owner():
    with patch("features.wallet.repository.WalletRepository.create_refund_request") as mock_req:
        mock_req.side_effect = HTTPException(status_code=403, detail="You can only request a refund for your own orders.")
        res = client.post("/api/wallet/refunds/request", json={"order_id": "other_user_ord"})
        assert res.status_code == 403
        assert "your own orders" in res.json()["detail"]


def test_user_refund_request_not_in_placed_status():
    with patch("features.wallet.repository.WalletRepository.create_refund_request") as mock_req:
        mock_req.side_effect = HTTPException(
            status_code=400,
            detail="Refund can only be requested for orders in 'placed' status (current: delivered).",
        )
        res = client.post("/api/wallet/refunds/request", json={"order_id": "delivered_ord"})
        assert res.status_code == 400
        assert "current: delivered" in res.json()["detail"]


def test_user_refund_request_success():
    with patch("features.wallet.repository.WalletRepository.create_refund_request") as mock_req:
        mock_req.return_value = RefundRequestItem(
            request_id="ref_req_999",
            user_uid="cust_refund_user",
            order_id="ord_placed_123",
            amount=250.0,
            status="refund_requested",
            reason="Cold food",
        )
        res = client.post("/api/wallet/refunds/request", json={"order_id": "ord_placed_123", "reason": "Cold food"})
        assert res.status_code == 201
        data = res.json()
        assert data["request_id"] == "ref_req_999"
        assert data["amount"] == 250.0
        assert data["status"] == "refund_requested"


def test_admin_manual_adjustment_success():
    with patch("features.wallet.repository.WalletRepository.create_manual_adjustment") as mock_adj:
        mock_adj.return_value = {
            "user_uid": "cust_refund_user",
            "amount": 100.0,
            "balance_before": 50.0,
            "balance_after": 150.0,
            "transaction_id": "txn_adj_123",
        }
        res = client.post(
            "/api/wallet/adjustments",
            json={"user_uid": "cust_refund_user", "amount": 100.0, "description": "Compensation credit"},
        )
        assert res.status_code == 200
        assert res.json()["balance_after"] == 150.0
