import os
import uuid
from unittest.mock import patch
import pytest
from fastapi.testclient import TestClient
from main import app
from config.firebase import db
from features.orders.checkout_service import CheckoutService

client = TestClient(app, raise_server_exceptions=False)

def _mock_token(uid):
    return {"uid": uid, "email": f"{uid}@mvsrec.edu.in", "sub": uid}

@pytest.fixture
def setup_users():
    uid = f"user_{uuid.uuid4().hex[:8]}"
    db.collection("Users").document(uid).set({"name": "Test User", "role": "student"})
    db.collection("wallets").document(uid).set({"balance": 1000.0, "total_spent": 0.0, "version": 1})
    menu_id = f"menu_{uuid.uuid4().hex[:8]}"
    db.collection("Menu").document(menu_id).set({"name": "Dosa", "price": 50, "stock": 10, "category": "mess", "isAvailable": True})
    return uid, menu_id

def test_group_checkout_double_charge_prevention(setup_users):
    uid, menu_id = setup_users
    
    with patch("auth.dependencies.verify_firebase_token", return_value=_mock_token(uid)):
        # 1. Create group
        r1 = client.post("/api/orders/group/create", headers={"Authorization": "Bearer fake"}, json={"items": [{"menu_item_id": menu_id, "quantity": 1}], "user_name": "Test"})
        assert r1.status_code == 201, r1.json()
        group_id = r1.json()["group_id"]
        
        # 2. Inject a failure in the complete(tx2) phase
        from google.cloud.firestore_v1.transaction import Transaction
        original_update = Transaction.update
        failure_injected = False
        
        def mock_update(self, ref, kwargs, *args, **kw):
            nonlocal failure_injected
            if hasattr(ref, "id") and ref.id == group_id and kwargs.get("status") == "COMPLETED":
                failure_injected = True
                raise RuntimeError("Injected transient network failure during complete(tx2)")
            return original_update(self, ref, kwargs, *args, **kw)
            
        with patch("google.cloud.firestore_v1.transaction.Transaction.update", new=mock_update):
            r2 = client.post(f"/api/orders/group/checkout", headers={"Authorization": "Bearer fake", "Idempotency-Key": f"key1_{uuid.uuid4().hex}"}, json={"group_id": group_id, "payment_method": "wallet"})
            assert r2.status_code == 500
            assert failure_injected
            
        # 3. Verify exactly one wallet debit and order
        wallet_doc = db.collection("wallets").document(uid).get().to_dict()
        assert wallet_doc["balance"] == 950.0
        
        orders = list(db.collection("Orders").where("userId", "==", uid).stream())
        assert len(orders) == 1
        order_id = orders[0].id
        
        group_doc = db.collection("group_orders").document(group_id).get().to_dict()
        assert group_doc["status"] == "PAYING"
        assert group_doc["orderId"] == order_id
        
        # 4. Retry checkout
        r3 = client.post(f"/api/orders/group/checkout", headers={"Authorization": "Bearer fake", "Idempotency-Key": f"key2_{uuid.uuid4().hex}"}, json={"group_id": group_id, "payment_method": "wallet"})
        assert r3.status_code == 201
        assert r3.json()["order_id"] == order_id
        
        # 5. Verify no double charge
        wallet_doc2 = db.collection("wallets").document(uid).get().to_dict()
        assert wallet_doc2["balance"] == 950.0
        
        orders2 = list(db.collection("Orders").where("userId", "==", uid).stream())
        assert len(orders2) == 1
        
        group_doc2 = db.collection("group_orders").document(group_id).get().to_dict()
        assert group_doc2["status"] == "COMPLETED"
