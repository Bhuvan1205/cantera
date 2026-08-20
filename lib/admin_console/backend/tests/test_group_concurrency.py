import pytest
import os
import uuid
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta, timezone

from fastapi import HTTPException
from google.cloud import firestore

from config.firebase import db
from features.orders.group_service import GroupOrderService, _now
from features.orders.group_schemas import JoinGroupRequest

# Ensure we're using emulator
assert os.environ.get('FIRESTORE_EMULATOR_HOST'), "MUST USE EMULATOR"

@pytest.fixture(autouse=True)
def clean_db():
    # Clean relevant collections before each test
    for doc in db.collection('user_group_locks').stream(): doc.reference.delete()
    for doc in db.collection('group_orders').stream(): doc.reference.delete()
    for doc in db.collection('group_order_codes').stream(): doc.reference.delete()
    yield

def _make_payload():
    class DummyPayload:
        items = []
        user_name = "Test User"
    return DummyPayload()

def _make_join_payload(code):
    class DummyPayload:
        group_code = code
        items = []
        user_name = "Test User"
    return DummyPayload()

def test_1_create_with_no_lock():
    res = GroupOrderService.create({'uid': 'u1'}, _make_payload())
    assert res['initiatorUid'] == 'u1'
    assert db.collection('user_group_locks').document('u1').get().exists

def test_2_create_with_active_open_lock():
    # Setup lock and active group
    g = GroupOrderService.create({'uid': 'u2'}, _make_payload())
    with pytest.raises(HTTPException) as exc:
        GroupOrderService.create({'uid': 'u2'}, _make_payload())
    assert exc.value.status_code == 409

def test_3_create_with_expired_open_lock():
    g = GroupOrderService.create({'uid': 'u3'}, _make_payload())
    # Manually expire it
    db.collection('group_orders').document(g['groupId']).update({'expiresAt': _now() - timedelta(days=1)})
    
    # Should succeed and reuse lock
    g2 = GroupOrderService.create({'uid': 'u3'}, _make_payload())
    assert g2['groupId'] != g['groupId']

def test_4_create_with_paying_lock():
    g = GroupOrderService.create({'uid': 'u4'}, _make_payload())
    db.collection('group_orders').document(g['groupId']).update({'status': 'PAYING'})
    with pytest.raises(HTTPException) as exc:
        GroupOrderService.create({'uid': 'u4'}, _make_payload())
    assert exc.value.status_code == 409

def test_5_create_with_completed_lock():
    g = GroupOrderService.create({'uid': 'u5'}, _make_payload())
    db.collection('group_orders').document(g['groupId']).update({'status': 'COMPLETED'})
    g2 = GroupOrderService.create({'uid': 'u5'}, _make_payload())
    assert g2['groupId'] != g['groupId']

def test_6_create_with_cancelled_lock():
    g = GroupOrderService.create({'uid': 'u6'}, _make_payload())
    db.collection('group_orders').document(g['groupId']).update({'status': 'CANCELLED'})
    g2 = GroupOrderService.create({'uid': 'u6'}, _make_payload())
    assert g2['groupId'] != g['groupId']

def test_7_create_with_nonexistent_group_lock():
    db.collection('user_group_locks').document('u7').set({'activeGroupId': 'grp_ghost'})
    g = GroupOrderService.create({'uid': 'u7'}, _make_payload())
    assert g['groupId'] != 'grp_ghost'

def test_8_join_with_no_lock():
    g = GroupOrderService.create({'uid': 'u8_creator'}, _make_payload())
    res = GroupOrderService.join({'uid': 'u8_joiner'}, _make_join_payload(g['groupCode']))
    assert 'u8_joiner' in res['memberUids']
    assert db.collection('user_group_locks').document('u8_joiner').get().exists

def test_9_join_with_active_open_lock():
    g1 = GroupOrderService.create({'uid': 'u9_creator'}, _make_payload())
    g2 = GroupOrderService.create({'uid': 'u9_joiner'}, _make_payload()) # Joiner has active lock
    with pytest.raises(HTTPException) as exc:
        GroupOrderService.join({'uid': 'u9_joiner'}, _make_join_payload(g1['groupCode']))
    assert exc.value.status_code == 409

def test_10_join_with_expired_open_lock():
    g1 = GroupOrderService.create({'uid': 'u10_creator'}, _make_payload())
    g2 = GroupOrderService.create({'uid': 'u10_joiner'}, _make_payload())
    db.collection('group_orders').document(g2['groupId']).update({'expiresAt': _now() - timedelta(days=1)})
    
    res = GroupOrderService.join({'uid': 'u10_joiner'}, _make_join_payload(g1['groupCode']))
    assert 'u10_joiner' in res['memberUids']

def test_11_join_with_paying_lock():
    g1 = GroupOrderService.create({'uid': 'u11_creator'}, _make_payload())
    g2 = GroupOrderService.create({'uid': 'u11_joiner'}, _make_payload())
    db.collection('group_orders').document(g2['groupId']).update({'status': 'PAYING'})
    with pytest.raises(HTTPException) as exc:
        GroupOrderService.join({'uid': 'u11_joiner'}, _make_join_payload(g1['groupCode']))
    assert exc.value.status_code == 409

def test_12_leave_releases_lock():
    g = GroupOrderService.create({'uid': 'u12_creator'}, _make_payload())
    GroupOrderService.join({'uid': 'u12_joiner'}, _make_join_payload(g['groupCode']))
    assert db.collection('user_group_locks').document('u12_joiner').get().exists
    
    GroupOrderService.leave({'uid': 'u12_joiner'}, g['groupId'])
    assert not db.collection('user_group_locks').document('u12_joiner').get().exists

def test_13_cancel_releases_initiator_lock():
    g = GroupOrderService.create({'uid': 'u13_creator'}, _make_payload())
    GroupOrderService.join({'uid': 'u13_joiner'}, _make_join_payload(g['groupCode']))
    
    GroupOrderService.cancel({'uid': 'u13_creator'}, g['groupId'])
    assert not db.collection('user_group_locks').document('u13_creator').get().exists
    # Other members locks become stale, which is handled correctly
    assert db.collection('user_group_locks').document('u13_joiner').get().exists

def test_14_multiple_simultaneous_create():
    uid = 'u14'
    def do_create():
        try:
            return GroupOrderService.create({'uid': uid}, _make_payload())
        except Exception as e:
            return 409

    with ThreadPoolExecutor(max_workers=5) as ex:
        results = list(ex.map(lambda _: do_create(), range(5)))
    
    successes = [r for r in results if isinstance(r, dict)]
    assert len(successes) == 1

def test_15_simultaneous_create_and_join():
    uid = 'u15'
    g_target = GroupOrderService.create({'uid': 'u15_creator'}, _make_payload())
    
    def do_create():
        try: return GroupOrderService.create({'uid': uid}, _make_payload())
        except Exception: return 409
        
    def do_join():
        try: return GroupOrderService.join({'uid': uid}, _make_join_payload(g_target['groupCode']))
        except Exception: return 409
        
    with ThreadPoolExecutor(max_workers=2) as ex:
        f1 = ex.submit(do_create)
        f2 = ex.submit(do_join)
        r1 = f1.result()
        r2 = f2.result()
        
    successes = 0
    if isinstance(r1, dict): successes += 1
    if isinstance(r2, dict): successes += 1
    assert successes == 1

def test_legacy_data_handling():
    # User has an active group but no lock
    db.collection('group_orders').document('grp_legacy').set({
        'status': 'OPEN', 'expiresAt': _now() + timedelta(days=1), 'memberUids': ['u_legacy']
    })
    with pytest.raises(HTTPException) as exc:
        GroupOrderService.create({'uid': 'u_legacy'}, _make_payload())
    assert exc.value.status_code == 409

