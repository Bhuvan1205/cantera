from features.orders.group_schemas import GroupCartItem, JoinGroupRequest
from fastapi import HTTPException
from features.orders import group_service
from features.orders.group_service import GroupOrderService, _expires_at, _normalise_items
from config.settings import BUSINESS_DAY_CLOSE_UTC_HOUR, BUSINESS_DAY_CLOSE_UTC_MINUTE
from datetime import datetime, timezone


def test_group_cart_migration_marks_item_owner():
    items = _normalise_items([GroupCartItem(menu_item_id='tea', quantity=2)], 'member-a')
    assert items == [{'menuItemId': 'tea', 'quantity': 2, 'addedByUid': 'member-a'}]


def test_group_code_input_is_constrained_to_six_characters():
    request = JoinGroupRequest(group_code='ABC123')
    assert request.group_code == 'ABC123'


def test_expiry_reuses_next_configured_operational_close():
    before_close = datetime(2026, 1, 1, 10, tzinfo=timezone.utc)
    after_close = datetime(2026, 1, 1, 20, tzinfo=timezone.utc)
    assert _expires_at(before_close).hour == BUSINESS_DAY_CLOSE_UTC_HOUR
    assert _expires_at(before_close).minute == BUSINESS_DAY_CLOSE_UTC_MINUTE
    assert _expires_at(before_close).date() == before_close.date()
    assert _expires_at(after_close).date().day == 2


class _Snapshot:
    exists = True
    def __init__(self, data): self._data = data
    def to_dict(self): return self._data


class _GroupRef:
    def __init__(self, data): self.data, self.updates = data, []
    def get(self, transaction=None): return _Snapshot(self.data)


class _Groups:
    def __init__(self, ref): self.ref = ref
    def document(self, _): return self.ref


class _Db:
    def __init__(self, ref): self.ref = ref
    def collection(self, _): return _Groups(self.ref)
    def transaction(self): return self
    def update(self, ref, values): ref.updates.append(values)


def test_initiator_leave_is_rejected_without_cancelling(monkeypatch):
    ref = _GroupRef({
        'status': 'OPEN', 'initiatorUid': 'initiator', 'memberUids': ['initiator'],
        'members': [{'uid': 'initiator'}], 'items': [],
    })
    monkeypatch.setattr(group_service, 'db', _Db(ref))
    monkeypatch.setattr(group_service.firestore, 'transactional', lambda fn: fn)

    try:
        GroupOrderService.leave({'uid': 'initiator'}, 'grp_1')
        assert False, 'initiator leave must fail'
    except HTTPException as exc:
        assert exc.status_code == 409
        assert 'cancel' in exc.detail.lower()
    assert ref.updates == []
