import pytest
from unittest.mock import patch
from fastapi.testclient import TestClient
from fastapi import HTTPException

from main import app
from auth.dependencies import get_current_user
from features.orders.schemas import ScanQrResponse, VerifyOtpResponse

client = TestClient(app, raise_server_exceptions=False)

def override_staff():
    return {"uid": "staff-user-789", "email": "staff@example.com", "role": "staff"}

def override_customer():
    return {"uid": "customer-user-123", "email": "customer@example.com", "role": "customer"}




@pytest.fixture(autouse=True)
def apply_overrides():
    app.dependency_overrides[get_current_user] = override_staff
    yield
    app.dependency_overrides.clear()

def test_scan_qr_empty_fails_422():
    response = client.post("/api/orders/scan-qr", json={"qr_payload": ""})
    assert response.status_code == 422


def test_scan_qr_direct_counter_success():
    with patch("features.orders.qr_service.QrService.process_qr_scan") as mock_scan:
        mock_scan.return_value = ScanQrResponse(
            order_id="ord_123",
            counter="bakery",
            status="delivered",
            requires_otp=False,
            message="Counter 'bakery' order successfully delivered.",
        )
        response = client.post("/api/orders/scan-qr", json={"qr_payload": "ord_123:bakery:1"})
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "delivered"
        assert data["requires_otp"] is False


def test_scan_qr_order_not_found_404():
    with patch("features.orders.qr_service.QrService.process_qr_scan") as mock_scan:
        mock_scan.side_effect = HTTPException(status_code=404, detail="Order ord_nonexistent not found.")
        response = client.post("/api/orders/scan-qr", json={"qr_payload": "ord_nonexistent:bakery:1"})
        assert response.status_code == 404
        assert "not found" in response.json()["detail"]


def test_scan_qr_already_delivered_409():
    with patch("features.orders.qr_service.QrService.process_qr_scan") as mock_scan:
        mock_scan.side_effect = HTTPException(status_code=409, detail="Token has already been delivered.")
        response = client.post("/api/orders/scan-qr", json={"qr_payload": "ord_123:bakery:1"})
        assert response.status_code == 409
        assert "already been delivered" in response.json()["detail"]


def test_verify_otp_success():
    with patch("features.orders.qr_service.QrService.verify_otp") as mock_otp:
        mock_otp.return_value = VerifyOtpResponse(
            order_id="ord_123",
            counter="mess",
            status="delivered",
            message="OTP verified successfully. Order marked as delivered.",
        )
        response = client.post(
            "/api/orders/verify-otp",
            json={"order_id": "ord_123", "counter": "mess", "otp": "4567"},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "delivered"


def test_verify_otp_invalid_otp_409():
    with patch("features.orders.qr_service.QrService.verify_otp") as mock_otp:
        mock_otp.side_effect = HTTPException(status_code=409, detail="Invalid OTP provided.")
        response = client.post(
            "/api/orders/verify-otp",
            json={"order_id": "ord_123", "counter": "mess", "otp": "0000"},
        )
        assert response.status_code == 409
        assert "Invalid OTP" in response.json()["detail"]


def test_verify_otp_token_not_found_404():
    with patch("features.orders.qr_service.QrService.verify_otp") as mock_otp:
        mock_otp.side_effect = HTTPException(status_code=404, detail="Token for counter 'mess' not found in order ord_123.")
        response = client.post(
            "/api/orders/verify-otp",
            json={"order_id": "ord_123", "counter": "mess", "otp": "4567"},
        )
        assert response.status_code == 404
