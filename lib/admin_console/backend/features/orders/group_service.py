"""Server-authoritative Group Order V1 operations."""
import random
import string
import uuid
from datetime import datetime, timedelta, timezone
from typing import Callable

from fastapi import HTTPException, status
from google.cloud import firestore

from config.firebase import db
from config.settings import BUSINESS_DAY_CLOSE_UTC_HOUR, BUSINESS_DAY_CLOSE_UTC_MINUTE
from .checkout_service import CheckoutService
from .schemas import CheckoutCartItem, CheckoutRequest

ACTIVE = {'OPEN', 'PAYING'}


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _expires_at(now: datetime) -> datetime:
    """Return the next configured business-day close in UTC."""
    close = now.replace(
        hour=BUSINESS_DAY_CLOSE_UTC_HOUR,
        minute=BUSINESS_DAY_CLOSE_UTC_MINUTE,
        second=0,
        microsecond=0,
    )
    return close if now < close else close + timedelta(days=1)


def _error(detail: str, code: int = status.HTTP_400_BAD_REQUEST):
    raise HTTPException(status_code=code, detail=detail)


def _normalise_items(items, uid: str) -> list[dict]:
    return [{'menuItemId': x.menu_item_id, 'quantity': x.quantity, 'addedByUid': uid} for x in items]


def _resolve_user_name(uid: str, caller: dict, payload_name: str | None) -> str:
    if payload_name:
        return payload_name
    if caller.get('name'):
        return caller.get('name')
    try:
        user_snap = db.collection('Users').document(uid).get()
        if user_snap.exists:
            name = (user_snap.to_dict() or {}).get('name')
            if name:
                return name
    except Exception:
        pass
    return caller.get('email') or 'Customer'


class GroupOrderService:
    @staticmethod
    def _active_group_for(uid: str):
        # Status filter makes the query index-free and avoids accepting stale
        # terminal groups as active participation.
        for group in db.collection('group_orders').where('memberUids', 'array_contains', uid).stream():
            if (group.to_dict() or {}).get('status') in ACTIVE:
                return group
        return None

    @staticmethod
    def _generate_code() -> str:
        return ''.join(random.SystemRandom().choice(string.ascii_uppercase + string.digits) for _ in range(6))

    @staticmethod
    def create(caller: dict, payload):
        uid = caller['uid']
        if GroupOrderService._active_group_for(uid):
            _error('You already participate in an active group order.', status.HTTP_409_CONFLICT)
        now, group_id = _now(), f'grp_{uuid.uuid4().hex[:16]}'
        user_name = _resolve_user_name(uid, caller, payload.user_name)
        # Reservation creation is transactional: document IDs are the codes,
        # so concurrent creators cannot claim the same code.
        for _ in range(12):
            code = GroupOrderService._generate_code()
            reservation = db.collection('group_order_codes').document(code)
            group_ref = db.collection('group_orders').document(group_id)
            tx = db.transaction()
            @firestore.transactional
            def reserve(transaction):
                if reservation.get(transaction=transaction).exists:
                    return False
                transaction.set(reservation, {'groupId': group_id, 'createdAt': firestore.SERVER_TIMESTAMP})
                transaction.set(group_ref, {
                    'groupId': group_id, 'groupCode': code, 'initiatorUid': uid,
                    'initiatorName': user_name,
                    'status': 'OPEN', 'createdAt': firestore.SERVER_TIMESTAMP, 'updatedAt': firestore.SERVER_TIMESTAMP,
                    'expiresAt': _expires_at(now),
                    'members': [{'uid': uid, 'name': user_name}],
                    'memberUids': [uid], 'items': _normalise_items(payload.items, uid),
                    'orderId': None, 'paidAt': None,
                })
                return True
            if reserve(tx):
                return group_ref.get().to_dict()
        _error('Unable to allocate a unique group code. Please retry.', status.HTTP_503_SERVICE_UNAVAILABLE)

    @staticmethod
    def join(caller: dict, payload):
        uid, code = caller['uid'], payload.group_code.upper()
        if GroupOrderService._active_group_for(uid):
            _error('You already participate in an active group order.', status.HTTP_409_CONFLICT)
        user_name = _resolve_user_name(uid, caller, payload.user_name)
        reservation = db.collection('group_order_codes').document(code).get()
        if not reservation.exists:
            _error('Group code was not found.', status.HTTP_404_NOT_FOUND)
        ref = db.collection('group_orders').document(reservation.to_dict()['groupId'])
        tx = db.transaction()
        @firestore.transactional
        def join_tx(transaction):
            snap = ref.get(transaction=transaction)
            if not snap.exists: _error('Group order was not found.', 404)
            data = snap.to_dict() or {}
            if data.get('status') != 'OPEN': _error('This group is no longer open.', 409)
            if data.get('expiresAt') and data['expiresAt'] <= _now(): _error('This group has expired.', 409)
            if uid in data.get('memberUids', []): _error('You already joined this group.', 409)
            members = data.get('members', []) + [{'uid': uid, 'name': user_name}]
            transaction.update(ref, {'members': members, 'memberUids': data.get('memberUids', []) + [uid],
                                    'items': data.get('items', []) + _normalise_items(payload.items, uid), 'updatedAt': firestore.SERVER_TIMESTAMP})
        join_tx(tx)
        return ref.get().to_dict()

    @staticmethod
    def leave(caller: dict, group_id: str):
        uid, ref = caller['uid'], db.collection('group_orders').document(group_id)
        tx = db.transaction()
        @firestore.transactional
        def leave_tx(transaction):
            snap = ref.get(transaction=transaction)
            if not snap.exists: _error('Group order was not found.', 404)
            data = snap.to_dict() or {}
            if data.get('status') == 'PAYING': _error('A payment is in progress.', 409)
            if data.get('status') != 'OPEN': _error('Group is locked.', 409)
            if uid not in data.get('memberUids', []): _error('You are not a group member.', 403)
            if data.get('initiatorUid') == uid:
                _error('The initiator cannot leave; use cancel instead.', status.HTTP_409_CONFLICT)
            transaction.update(ref, {'members': [m for m in data.get('members', []) if m.get('uid') != uid],
                'memberUids': [x for x in data.get('memberUids', []) if x != uid],
                'items': [x for x in data.get('items', []) if x.get('addedByUid') != uid], 'updatedAt': firestore.SERVER_TIMESTAMP})
        leave_tx(tx); return ref.get().to_dict()

    @staticmethod
    def cancel(caller: dict, group_id: str):
        uid, ref = caller['uid'], db.collection('group_orders').document(group_id)
        tx = db.transaction()
        @firestore.transactional
        def cancel_tx(transaction):
            snap = ref.get(transaction=transaction)
            if not snap.exists: _error('Group order was not found.', 404)
            data = snap.to_dict() or {}
            if data.get('initiatorUid') != uid: _error('Only the initiator can cancel.', 403)
            if data.get('status') != 'OPEN': _error('Only an open group can be cancelled.', 409)
            transaction.update(ref, {'status': 'CANCELLED', 'updatedAt': firestore.SERVER_TIMESTAMP})
        cancel_tx(tx); return ref.get().to_dict()

    @staticmethod
    def mutate_items(caller: dict, payload):
        uid, ref = caller['uid'], db.collection('group_orders').document(payload.group_id)
        tx = db.transaction()
        @firestore.transactional
        def items_tx(transaction):
            snap = ref.get(transaction=transaction)
            if not snap.exists: _error('Group order was not found.', 404)
            data = snap.to_dict() or {}
            if uid not in data.get('memberUids', []): _error('Only group members can edit items.', 403)
            if data.get('status') != 'OPEN' or (data.get('expiresAt') and data['expiresAt'] <= _now()): _error('Group is not open for changes.', 409)
            items = list(data.get('items', [])); matches = [i for i, x in enumerate(items) if x.get('menuItemId') == payload.menu_item_id and x.get('addedByUid') == uid]
            if payload.operation == 'add':
                if matches: items[matches[0]]['quantity'] += payload.quantity or 1
                else: items.append({'menuItemId': payload.menu_item_id, 'quantity': payload.quantity or 1, 'addedByUid': uid})
            elif not matches: _error('You can only modify items you added.', 403)
            elif payload.operation == 'remove': items.pop(matches[0])
            else: items[matches[0]]['quantity'] = payload.quantity or 1
            transaction.update(ref, {'items': items, 'updatedAt': firestore.SERVER_TIMESTAMP})
        items_tx(tx); return ref.get().to_dict()

    @staticmethod
    def checkout(caller: dict, payload):
        uid, ref = caller['uid'], db.collection('group_orders').document(payload.group_id)
        tx = db.transaction()
        @firestore.transactional
        def lock_tx(transaction):
            snap = ref.get(transaction=transaction)
            if not snap.exists: _error('Group order was not found.', 404)
            data = snap.to_dict() or {}
            if data.get('initiatorUid') != uid: _error('Only the initiator can checkout.', 403)
            if data.get('status') != 'OPEN' or (data.get('expiresAt') and data['expiresAt'] <= _now()): _error('Group is not open for payment.', 409)
            transaction.update(ref, {'status': 'PAYING', 'updatedAt': firestore.SERVER_TIMESTAMP})
            return data
        data = lock_tx(tx)
        try:
            quantities: dict[str, int] = {}
            for item in data.get('items', []): quantities[item['menuItemId']] = quantities.get(item['menuItemId'], 0) + int(item['quantity'])
            result = CheckoutService.execute_checkout(uid, CheckoutRequest(items=[CheckoutCartItem(menu_item_id=k, quantity=v) for k, v in quantities.items()], payment_method=payload.payment_method, user_name=payload.user_name or data.get('initiatorName')), caller.get('email'))
            tx2 = db.transaction()
            @firestore.transactional
            def complete(transaction):
                snap = ref.get(transaction=transaction)
                if snap.exists and (snap.to_dict() or {}).get('status') == 'PAYING': transaction.update(ref, {'status': 'COMPLETED', 'orderId': result.order_id, 'paidAt': firestore.SERVER_TIMESTAMP, 'updatedAt': firestore.SERVER_TIMESTAMP})
            complete(tx2); return result
        except Exception:
            tx3 = db.transaction()
            @firestore.transactional
            def unlock(transaction):
                snap = ref.get(transaction=transaction)
                if snap.exists and (snap.to_dict() or {}).get('status') == 'PAYING': transaction.update(ref, {'status': 'OPEN', 'updatedAt': firestore.SERVER_TIMESTAMP})
            unlock(tx3); raise
