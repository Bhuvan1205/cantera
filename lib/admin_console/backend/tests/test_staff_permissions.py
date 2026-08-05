import pytest
from unittest.mock import patch
from fastapi.testclient import TestClient

from main import app
from auth.dependencies import get_current_staff_or_admin
from features.inventory.schemas import MenuItem
from features.orders.schemas import ScanQrResponse

client = TestClient(app, raise_server_exceptions=False)

def override_staff():
    return {"uid": "staff_member_1", "email": "staff@example.com", "role": "staff"}

app.dependency_overrides[get_current_staff_or_admin] = override_staff


def test_staff_can_list_inventory():
    with patch("features.inventory.service.InventoryService.list_items") as mock_list:
        mock_list.return_value = [
            MenuItem(menu_id="item_1", name="Idly", price=40, stock=20, category="Tiffins", is_available=True)
        ]
        res = client.get("/api/inventory/")
        assert res.status_code == 200
        assert len(res.json()) == 1
        assert res.json()[0]["name"] == "Idly"


def test_staff_can_update_inventory_stock():
    with patch("features.inventory.service.InventoryService.update_item") as mock_update:
        mock_update.return_value = MenuItem(
            menu_id="item_1", name="Idly", price=40, stock=15, category="Tiffins", is_available=True
        )
        res = client.patch("/api/inventory/item_1", json={"stock": 15})
        assert res.status_code == 200
        assert res.json()["stock"] == 15



def test_staff_can_scan_qr():
    with patch("features.orders.qr_service.QrService.process_qr_scan") as mock_scan:
        mock_scan.return_value = ScanQrResponse(
            order_id="ord_123",
            counter="bakery",
            status="delivered",
            requires_otp=False,
            message="Token marked delivered successfully.",
        )
        res = client.post("/api/orders/scan-qr", json={"qr_payload": "ord_123:bakery:42:hash"})
        assert res.status_code == 200
        assert res.json()["status"] == "delivered"
