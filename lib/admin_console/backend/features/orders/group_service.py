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
            d = group.to_dict() or {}
            s = d.get('status')
            if s == 'PAYING':
                return group
            if s == 'OPEN':
                exp = d.get('expiresAt')
                if not exp or exp > _now():
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
        # Pre-query for active memberships outside the transaction to avoid blocking/deadlock in emulator
        # We collect the IDs and read them transactionally inside to guarantee isolation.
        pre_query = db.collection('group_orders').where('memberUids', 'array_contains', uid).stream()
        known_group_ids = [doc.id for doc in pre_query]
        
        for _ in range(12):
            code = GroupOrderService._generate_code()
            reservation = db.collection('group_order_codes').document(code)
            group_ref = db.collection('group_orders').document(group_id)
            lock_ref = db.collection('user_group_locks').document(uid)
            tx = db.transaction()
            @firestore.transactional
            def reserve(transaction):
                # 1. Read user_group_locks/{uid}
                lock_snap = lock_ref.get(transaction=transaction)
                lock_data = lock_snap.to_dict() or {} if lock_snap.exists else None
                
                # 2. If lock exists, read referenced group
                active_group_snap = None
                if lock_data and lock_data.get('activeGroupId'):
                    active_group_snap = db.collection('group_orders').document(lock_data['activeGroupId']).get(transaction=transaction)
                
                # 3. Read pre-discovered memberships
                query_results = []
                for gid in known_group_ids:
                    # Skip if it's the same as the lock's active group to avoid duplicate reads
                    if lock_data and gid == lock_data.get('activeGroupId'):
                        continue
                    doc_snap = db.collection('group_orders').document(gid).get(transaction=transaction)
                    if doc_snap.exists:
                        query_results.append(doc_snap)
                
                # 4. Evaluate ALL discovered memberships
                def is_active(g_snap):
                    if not g_snap.exists: return False
                    d = g_snap.to_dict() or {}
                    if uid not in d.get('memberUids', []): return False
                    s = d.get('status')
                    if s == 'PAYING': return True
                    if s == 'OPEN':
                        exp = d.get('expiresAt')
                        if not exp or exp > _now(): return True
                    return False

                has_active = False
                if active_group_snap and is_active(active_group_snap):
                    has_active = True
                
                for res_snap in query_results:
                    if is_active(res_snap):
                        has_active = True
                        break
                
                if has_active:
                    _error('You already participate in an active group order.', status.HTTP_409_CONFLICT)
                
                # 5. Read the group-code reservation document
                if reservation.get(transaction=transaction).exists:
                    return False
                    
                # 6. If existing lock is stale AND there is NO active membership: transaction.delete(lock_ref)
                if lock_snap.exists:
                    transaction.delete(lock_ref)
                # 7. Reserve the new group code
                transaction.set(reservation, {'groupId': group_id, 'createdAt': firestore.SERVER_TIMESTAMP})
                
                # 8. Create the new group
                transaction.set(group_ref, {
                    'groupId': group_id, 'groupCode': code, 'initiatorUid': uid,
                    'initiatorName': user_name,
                    'status': 'OPEN', 'createdAt': firestore.SERVER_TIMESTAMP, 'updatedAt': firestore.SERVER_TIMESTAMP,
                    'expiresAt': _expires_at(now),
                    'members': [{'uid': uid, 'name': user_name}],
                    'memberUids': [uid], 'items': _normalise_items(payload.items, uid),
                    'orderId': None, 'paidAt': None,
                })
                
                # 9. Create/update user_group_locks/{uid}
                transaction.set(lock_ref, {'activeGroupId': group_id, 'updatedAt': firestore.SERVER_TIMESTAMP})
                
                return True
                
            if reserve(tx):
                return group_ref.get().to_dict()
        _error('Unable to allocate a unique group code. Please retry.', status.HTTP_503_SERVICE_UNAVAILABLE)

    @staticmethod
    def join(caller: dict, payload):
        uid, code = caller['uid'], payload.group_code.upper()
        if GroupOrderService._active_group_for(uid):
            _error('You already participate in an active group order.', status.HTTP_409_CONFLICT)
            
        pre_query = db.collection('group_orders').where('memberUids', 'array_contains', uid).stream()
        known_group_ids = [doc.id for doc in pre_query]
        
        user_name = _resolve_user_name(uid, caller, payload.user_name)
        reservation = db.collection('group_order_codes').document(code).get()
        if not reservation.exists:
            _error('Group code was not found.', status.HTTP_404_NOT_FOUND)
            
        target_group_id = reservation.to_dict()['groupId']
        ref = db.collection('group_orders').document(target_group_id)
        lock_ref = db.collection('user_group_locks').document(uid)
        
        tx = db.transaction()
        @firestore.transactional
        def join_tx(transaction):
            lock_snap = lock_ref.get(transaction=transaction)
            lock_data = lock_snap.to_dict() or {} if lock_snap.exists else None
            
            active_group_snap = None
            if lock_data and lock_data.get('activeGroupId'):
                active_group_snap = db.collection('group_orders').document(lock_data['activeGroupId']).get(transaction=transaction)
                
            query_results = []
            for gid in known_group_ids:
                if lock_data and gid == lock_data.get('activeGroupId'):
                    continue
                doc_snap = db.collection('group_orders').document(gid).get(transaction=transaction)
                if doc_snap.exists:
                    query_results.append(doc_snap)
                    
            def is_active(g_snap):
                if not g_snap.exists: return False
                d = g_snap.to_dict() or {}
                if uid not in d.get('memberUids', []): return False
                s = d.get('status')
                if s == 'PAYING': return True
                if s == 'OPEN':
                    exp = d.get('expiresAt')
                    if not exp or exp > _now(): return True
                return False

            has_active = False
            if active_group_snap and is_active(active_group_snap):
                has_active = True
            for res_snap in query_results:
                if is_active(res_snap):
                    has_active = True
                    break
            
            if has_active:
                _error('You already participate in an active group order.', status.HTTP_409_CONFLICT)
                
            snap = ref.get(transaction=transaction)
            
            if lock_snap.exists:
                transaction.delete(lock_ref)
            if not snap.exists: _error('Group order was not found.', 404)
            data = snap.to_dict() or {}
            if data.get('status') != 'OPEN': _error('This group is no longer open.', 409)
            if data.get('expiresAt') and data['expiresAt'] <= _now(): _error('This group has expired.', 409)
            if uid in data.get('memberUids', []): _error('You already joined this group.', 409)
            
            members = data.get('members', []) + [{'uid': uid, 'name': user_name}]
            transaction.update(ref, {'members': members, 'memberUids': data.get('memberUids', []) + [uid],
                                    'items': data.get('items', []) + _normalise_items(payload.items, uid), 'updatedAt': firestore.SERVER_TIMESTAMP})
            transaction.set(lock_ref, {'activeGroupId': target_group_id, 'updatedAt': firestore.SERVER_TIMESTAMP})
            
        join_tx(tx)
        return ref.get().to_dict()

    @staticmethod
    def leave(caller: dict, group_id: str):
        uid, ref = caller['uid'], db.collection('group_orders').document(group_id)
        lock_ref = db.collection('user_group_locks').document(uid)
        tx = db.transaction()
        @firestore.transactional
        def leave_tx(transaction):
            snap = ref.get(transaction=transaction)
            lock_snap = lock_ref.get(transaction=transaction)
            
            if not snap.exists: _error('Group order was not found.', 404)
            data = snap.to_dict() or {}
            if data.get('status') == 'PAYING': _error('A payment is in progress.', 409)
            if data.get('status') != 'OPEN': _error('Group is locked.', 409)
            if uid not in data.get('memberUids', []): _error('You are not in this group.', 409)
            if data.get('initiatorUid') == uid: _error('The initiator cannot leave; use cancel instead.', 409)
            
            transaction.update(ref, {
                'members': [m for m in data.get('members', []) if m.get('uid') != uid],
                'memberUids': [u for u in data.get('memberUids', []) if u != uid],
                'items': [i for i in data.get('items', []) if i.get('addedByUid') != uid],
                'updatedAt': firestore.SERVER_TIMESTAMP
            })
            if lock_snap.exists and lock_snap.to_dict().get('activeGroupId') == group_id:
                transaction.delete(lock_ref)
                
        leave_tx(tx)
        return ref.get().to_dict()

    @staticmethod
    def cancel(caller: dict, group_id: str):
        uid, ref = caller['uid'], db.collection('group_orders').document(group_id)
        lock_ref = db.collection('user_group_locks').document(uid)
        tx = db.transaction()
        @firestore.transactional
        def cancel_tx(transaction):
            snap = ref.get(transaction=transaction)
            lock_snap = lock_ref.get(transaction=transaction)

            if not snap.exists: _error('Group order was not found.', 404)
            data = snap.to_dict() or {}
            if data.get('initiatorUid') != uid: _error('Only the initiator can cancel.', 403)
            if data.get('status') not in ACTIVE: _error('Group is not active.', 409)
            if data.get('status') == 'PAYING': _error('A payment is in progress.', 409)
            
            transaction.update(ref, {'status': 'CANCELLED', 'updatedAt': firestore.SERVER_TIMESTAMP})
            
            if lock_snap.exists and lock_snap.to_dict().get('activeGroupId') == group_id:
                transaction.delete(lock_ref)
                    
        cancel_tx(tx)
        return ref.get().to_dict()

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
        
        # We pre-generate an order_id so we can track success across failure boundaries.
        order_id = f"ord_{uuid.uuid4().hex[:12]}"

        tx = db.transaction()
        @firestore.transactional
        def lock_tx(transaction):
            snap = ref.get(transaction=transaction)
            if not snap.exists: _error('Group order was not found.', 404)
            data = snap.to_dict() or {}
            
            if data.get('status') == 'COMPLETED':
                return data, True, data.get('orderId')
                
            if data.get('initiatorUid') != uid: _error('Only the initiator can checkout.', 403)
            
            if data.get('status') == 'PAYING':
                # RECOVERY LOGIC
                existing_order_id = data.get('orderId')
                if existing_order_id:
                    # Check if the order actually exists in Firestore
                    o_snap = db.collection('Orders').document(existing_order_id).get(transaction=transaction)
                    if o_snap.exists:
                        # Checkout succeeded but group completion failed in a previous attempt.
                        return data, True, existing_order_id
                    else:
                        # Checkout failed/crashed before committing. Safe to reset and lock with new order_id.
                        transaction.update(ref, {'status': 'PAYING', 'orderId': order_id, 'updatedAt': firestore.SERVER_TIMESTAMP})
                        return data, False, order_id
                else:
                    _error('Group is in a pending state. Please try again.', 409)

            if data.get('status') != 'OPEN' or (data.get('expiresAt') and data['expiresAt'] <= _now()):
                _error('Group is not open for payment.', 409)
                
            transaction.update(ref, {'status': 'PAYING', 'orderId': order_id, 'updatedAt': firestore.SERVER_TIMESTAMP})
            return data, False, order_id

        data, already_completed, active_order_id = lock_tx(tx)
        
        if already_completed:
            # Reconstruct response from existing order
            o_snap = db.collection('Orders').document(active_order_id).get()
            if not o_snap.exists: _error('Order not found', 404)
            o_data = o_snap.to_dict() or {}
            
            # Run tx2 to ensure locks are cleared and status is COMPLETED just in case
            tx2 = db.transaction()
            @firestore.transactional
            def complete_idempotent(transaction):
                snap = ref.get(transaction=transaction)
                if snap.exists:
                    group_data = snap.to_dict() or {}
                    member_uids = group_data.get('memberUids', [])
                    for member_uid in member_uids:
                        l_ref = db.collection('user_group_locks').document(member_uid)
                        l_snap = l_ref.get(transaction=transaction)
                        if l_snap.exists and (l_snap.to_dict() or {}).get('activeGroupId') == payload.group_id:
                            transaction.delete(l_ref)
                    if group_data.get('status') != 'COMPLETED':
                        transaction.update(ref, {'status': 'COMPLETED', 'paidAt': firestore.SERVER_TIMESTAMP, 'updatedAt': firestore.SERVER_TIMESTAMP})
            complete_idempotent(tx2)
            
            from features.orders.schemas import CheckoutResponse, CheckoutTokenDetail
            tokens_out = []
            for cat, t_data in o_data.get('categoryTokens', {}).items():
                tokens_out.append(CheckoutTokenDetail(counter=cat, token_number=t_data.get('tokenNumber', 0), qr_valid=t_data.get('tokenId') != ""))
                
            return CheckoutResponse(
                order_id=active_order_id,
                total=o_data.get('total', 0),
                token_number=o_data.get('tokenNumber', 0),
                status=o_data.get('status', 'placed'),
                payment_method=o_data.get('paymentMethod', 'wallet'),
                tokens=tokens_out
            )
            
        checkout_succeeded = False
        try:
            quantities: dict[str, int] = {}
            for item in data.get('items', []): quantities[item['menuItemId']] = quantities.get(item['menuItemId'], 0) + int(item['quantity'])
            
            from features.orders.schemas import CheckoutCartItem, CheckoutRequest
            result = CheckoutService.execute_checkout(
                user_uid=uid, 
                payload=CheckoutRequest(items=[CheckoutCartItem(menu_item_id=k, quantity=v) for k, v in quantities.items()], payment_method=payload.payment_method, user_name=payload.user_name or data.get('initiatorName')), 
                actor_email=caller.get('email'),
                order_id=active_order_id
            )
            checkout_succeeded = True
            
            tx2 = db.transaction()
            @firestore.transactional
            def complete(transaction):
                snap = ref.get(transaction=transaction)
                if snap.exists and (snap.to_dict() or {}).get('status') == 'PAYING':
                    group_data = snap.to_dict() or {}
                    member_uids = group_data.get('memberUids', [])
                    lock_snaps = {}
                    for member_uid in member_uids:
                        l_ref = db.collection('user_group_locks').document(member_uid)
                        lock_snaps[l_ref] = l_ref.get(transaction=transaction)
                        
                    transaction.update(ref, {'status': 'COMPLETED', 'orderId': result.order_id, 'paidAt': firestore.SERVER_TIMESTAMP, 'updatedAt': firestore.SERVER_TIMESTAMP})
                    
                    for l_ref, l_snap in lock_snaps.items():
                        if l_snap.exists and (l_snap.to_dict() or {}).get('activeGroupId') == payload.group_id:
                            transaction.delete(l_ref)
            complete(tx2)
            return result
            
        except Exception:
            if not checkout_succeeded:
                tx3 = db.transaction()
                @firestore.transactional
                def unlock(transaction):
                    snap = ref.get(transaction=transaction)
                    if snap.exists and (snap.to_dict() or {}).get('status') == 'PAYING':
                        transaction.update(ref, {'status': 'OPEN', 'orderId': None, 'updatedAt': firestore.SERVER_TIMESTAMP})
                unlock(tx3)
            raise
