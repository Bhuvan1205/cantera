import pytest
import os
from google.cloud import firestore

from config.firebase import db
from features.orders.repository import OrderRepository
from features.orders.schemas import CreateManualOrderRequest, ManualOrderItem

# Ensure we're using emulator
assert os.environ.get('FIRESTORE_EMULATOR_HOST'), "MUST USE EMULATOR"

# Item names used across all queue regression tests — must exist in Menu.
_QUEUE_TEST_MENU_ITEMS = [
    {"name": "Masala Dosa",    "price": 50,  "category": "mess",        "isAvailable": True, "stock": None, "prep_units": 4.0},
    {"name": "Onion Dosa",     "price": 50,  "category": "mess",        "isAvailable": True, "stock": None, "prep_units": 4.0},
    {"name": "Plain Dosa",     "price": 40,  "category": "mess",        "isAvailable": True, "stock": None, "prep_units": 3.0},
    {"name": "Veg Meals",      "price": 80,  "category": "mess",        "isAvailable": True, "stock": None, "prep_units": 6.0},
    {"name": "Pizza",          "price": 100, "category": "continental", "isAvailable": True, "stock": None, "prep_units": 5.0},
    {"name": "Old Item",       "price": 50,  "category": "mess",        "isAvailable": True, "stock": None, "prep_units": 3.0},
]

@pytest.fixture(scope="session", autouse=True)
def seed_queue_test_menu_items():
    """Seed Menu items required by queue regression tests (P1 fix compatibility)."""
    seeded_ids = []
    for item in _QUEUE_TEST_MENU_ITEMS:
        ref = db.collection("Menu").document()
        ref.set(item)
        seeded_ids.append(ref.id)
    yield
    for doc_id in seeded_ids:
        db.collection("Menu").document(doc_id).delete()

@pytest.fixture(autouse=True)
def clean_db():
    # Clean relevant collections before each test
    for doc in db.collection('Orders').stream(): doc.reference.delete()
    for doc in db.collection('queues').stream(): doc.reference.delete()
    yield

def _make_manual_order(items, payment_method="wallet"):
    req_items = [
        ManualOrderItem(name=it["name"], quantity=it["qty"], price=it["price"], category=it["cat"])
        for it in items
    ]
    req = CreateManualOrderRequest(items=req_items, payment_method=payment_method)
    return OrderRepository.create_manual_order(req)


def test_case_a_same_category_different_items():
    # Case A: Same category, different items
    _make_manual_order([{"name": "Masala Dosa", "qty": 1, "price": 50, "cat": "mess"}])
    _make_manual_order([{"name": "Onion Dosa", "qty": 1, "price": 50, "cat": "mess"}])
    _make_manual_order([{"name": "Plain Dosa", "qty": 1, "price": 40, "cat": "mess"}])

    queues = list(db.collection('queues').stream())
    assert len(queues) == 1
    assert queues[0].id == "mess"

    queue_data = queues[0].to_dict()
    assert len(queue_data.get("queue", [])) == 3
    # All 3 items should be stored under the 'mess' queue
    items_in_queue = []
    for entry in queue_data["queue"]:
        assert "items" in entry
        assert len(entry["items"]) == 1
        items_in_queue.append(entry["items"][0]["item_name"])
    
    assert "Masala Dosa" in items_in_queue
    assert "Onion Dosa" in items_in_queue
    assert "Plain Dosa" in items_in_queue

def test_case_b_multiple_items_one_token():
    # Case B: Multiple items in one token
    _make_manual_order([
        {"name": "Masala Dosa", "qty": 1, "price": 50, "cat": "mess"},
        {"name": "Veg Meals", "qty": 1, "price": 80, "cat": "mess"},
    ])

    queues = list(db.collection('queues').stream())
    assert len(queues) == 1
    assert queues[0].id == "mess"

    queue_data = queues[0].to_dict()
    assert len(queue_data.get("queue", [])) == 1

    entry = queue_data["queue"][0]
    assert "items" in entry
    assert len(entry["items"]) == 2
    item_names = [i["item_name"] for i in entry["items"]]
    assert "Masala Dosa" in item_names
    assert "Veg Meals" in item_names

def test_case_c_different_categories():
    # Case C: Different categories
    _make_manual_order([
        {"name": "Masala Dosa", "qty": 1, "price": 50, "cat": "mess"},
        {"name": "Pizza", "qty": 1, "price": 100, "cat": "continental"},
    ])

    queues = list(db.collection('queues').stream())
    queue_ids = [q.id for q in queues]
    print(f"DEBUG queues: {queue_ids}")
    assert len(queues) == 2
    queue_ids = [q.id for q in queues]
    assert "mess" in queue_ids
    assert "continental" in queue_ids

def test_case_d_mark_ready():
    # Case D: Mark Ready removes correct entry
    order = _make_manual_order([{"name": "Masala Dosa", "qty": 1, "price": 50, "cat": "mess"}])
    
    # Transition it to preparing using mark_prepared preconditions
    # Manual orders are placed as 'placed', wait, 'create_manual_order' puts them in queue as 'waiting'.
    # We need to transition token to preparing for mark_prepared to work, or we can just call start_preparation.
    # Manual orders put them in queue with status "waiting". 
    # Let's call start_preparation, but wait, start_preparation only transitions from 'placed'.
    # Actually, create_manual_order creates tokens with token_status 'placed', but puts in queue with 'waiting'.
    
    # Let's just create a normal order using the repository bypass or just update status manually to 'preparing'.
    db.collection('Orders').document(order.order_id).collection('tokens').document('mess').update({"token_status": "preparing"})
    # Also update the queue entry to 'preparing'
    q_doc = db.collection('queues').document('mess').get().to_dict()
    q_entry = q_doc["queue"][0]
    
    # Let's test mark_prepared directly (which will attempt to remove the entry)
    OrderRepository.mark_prepared(order.order_id, "mess", "staff_123")

    q_doc_after = db.collection('queues').document('mess').get().to_dict()
    # It should have removed the entry (Wait, the entry was 'waiting' in DB, so mark_prepared removes the 'waiting' dict too!)
    assert len(q_doc_after.get("queue", [])) == 0
    
    token_doc = db.collection('Orders').document(order.order_id).collection('tokens').document('mess').get().to_dict()
    assert token_doc["token_status"] == "ready_for_pickup"

def test_case_e_old_queue_schema():
    # Case E: Old queue schema without "items" field
    # Create order
    order = _make_manual_order([{"name": "Old Item", "qty": 1, "price": 50, "cat": "mess"}])
    token_doc_ref = db.collection('Orders').document(order.order_id).collection('tokens').document('mess')
    token_doc_ref.update({"token_status": "preparing"})
    
    # Now artificially modify the queue to simulate old schema by removing "items"
    q_ref = db.collection('queues').document('mess')
    q_doc = q_ref.get().to_dict()
    entry = q_doc["queue"][0]
    entry_without_items = {k: v for k, v in entry.items() if k != "items"}
    entry_without_items["status"] = "preparing" # simulate old preparing state
    
    # Override queue
    q_ref.set({"queue": [entry_without_items]}, merge=True)
    
    # Now call mark_prepared
    OrderRepository.mark_prepared(order.order_id, "mess", "staff_123")
    
    # Ensure it was removed
    q_doc_after = q_ref.get().to_dict()
    assert len(q_doc_after.get("queue", [])) == 0

