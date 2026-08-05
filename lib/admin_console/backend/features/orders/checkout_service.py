import datetime
import random
import uuid
from typing import Optional
from fastapi import HTTPException, status
from google.cloud import firestore

from config.firebase import db
from .schemas import (
    CheckoutCartItem,
    CheckoutRequest,
    CheckoutResponse,
    CheckoutTokenDetail,
)


@firestore.transactional
def _allocate_scoped_token_tx(transaction: firestore.Transaction, tracker_ref) -> int:
    """Atomic token allocation via Firestore transaction (Adjustment #1)."""
    snapshot = tracker_ref.get(transaction=transaction)
    if snapshot.exists:
        current_val = int(snapshot.get("last_token_number") or 0)
        next_val = current_val + 1
        transaction.update(tracker_ref, {
            "last_token_number": next_val,
            "updated_at": firestore.SERVER_TIMESTAMP,
        })
        return next_val
    else:
        next_val = 1
        transaction.set(tracker_ref, {
            "last_token_number": next_val,
            "created_at": firestore.SERVER_TIMESTAMP,
        })
        return next_val


@firestore.transactional
def _debit_wallet_tx(
    transaction: firestore.Transaction,
    wallet_ref,
    tx_ref,
    user_uid: str,
    amount: float,
    order_id: str,
) -> None:
    """Atomic wallet debit transaction."""
    snapshot = wallet_ref.get(transaction=transaction)
    if not snapshot.exists:
        raise ValueError("Wallet does not exist. Please initialize wallet first.")

    wallet_data = snapshot.to_dict() or {}
    balance = float(wallet_data.get("balance") or 0.0)
    if balance < amount:
        raise ValueError(
            f"Insufficient wallet balance. Available: ₹{balance:.2f}, Required: ₹{amount:.2f}"
        )

    new_balance = balance - amount
    total_spent = float(wallet_data.get("total_spent") or 0.0) + amount

    transaction.update(wallet_ref, {
        "balance": new_balance,
        "total_spent": total_spent,
        "updated_at": firestore.SERVER_TIMESTAMP,
    })

    transaction.set(tx_ref, {
        "user_uid": user_uid,
        "type": "debit",
        "amount": amount,
        "reference_id": order_id,
        "description": f"Order #{order_id[:8]}",
        "status": "completed",
        "created_at": firestore.SERVER_TIMESTAMP,
    })


class CheckoutService:
    """
    Orchestrates the atomic checkout pipeline (P-05, P-06):
      1. Resolve prices and availability from Firestore Menu
      2. Reserve inventory atomically before wallet debit (Improvement 2)
      3. Transactionally debit wallet balance (if payment_method == 'wallet')
      4. Allocate scoped tokens atomically per counter and date (Adjustment #1)
      5. Commit Order document and token subcollection documents
    """

    @staticmethod
    def execute_checkout(
        user_uid: str,
        payload: CheckoutRequest,
        actor_email: Optional[str] = None,
    ) -> CheckoutResponse:
        if not payload.items:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Cart cannot be empty.",
            )

        # ── 1. Resolve Cart & Compute Total (Read-only) ──────────────────────
        resolved_items = []
        category_groups: dict[str, list[dict]] = {}
        total_amount = 0

        for item in payload.items:
            menu_ref = db.collection("Menu").document(item.menu_item_id)
            menu_snap = menu_ref.get()
            if not menu_snap.exists:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail=f"Menu item '{item.menu_item_id}' not found.",
                )

            m_data = menu_snap.to_dict() or {}
            if not m_data.get("isAvailable", True) and not m_data.get("is_available", True):
                name = m_data.get("name", item.menu_item_id)
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Item '{name}' is currently unavailable.",
                )

            price = int(m_data.get("price", 0))
            category = str(m_data.get("category", "general")).lower().strip()
            item_name = str(m_data.get("name", item.menu_item_id))
            stock_qty = m_data.get("stock")

            line_total = price * item.quantity
            total_amount += line_total

            item_dict = {
                "menu_item_id": item.menu_item_id,
                "name": item_name,
                "price": price,
                "quantity": item.quantity,
                "category": category,
                "current_stock": stock_qty,
            }
            resolved_items.append(item_dict)
            category_groups.setdefault(category, []).append(item_dict)

        # ── 2. Reserve Stock (Atomic per item with rollback on failure) ──────
        reserved_items: list[tuple[str, int]] = []
        try:
            for item_dict in resolved_items:
                item_id = item_dict["menu_item_id"]
                req_qty = item_dict["quantity"]
                menu_ref = db.collection("Menu").document(item_id)

                # Fetch fresh snapshot
                fresh_snap = menu_ref.get()
                fresh_data = fresh_snap.to_dict() or {}
                stock = fresh_data.get("stock")

                if stock is not None:
                    current_stock = int(stock)
                    if current_stock < req_qty:
                        raise HTTPException(
                            status_code=status.HTTP_400_BAD_REQUEST,
                            detail=f"Insufficient stock for '{item_dict['name']}'. Available: {current_stock}, Requested: {req_qty}",
                        )
                    new_stock = current_stock - req_qty
                    updates = {"stock": new_stock}
                    if new_stock == 0:
                        updates["isAvailable"] = False
                    menu_ref.update(updates)
                    reserved_items.append((item_id, req_qty))

        except Exception as exc:
            # Rollback any previously decremented items in this transaction batch
            for res_id, res_qty in reserved_items:
                try:
                    db.collection("Menu").document(res_id).update({
                        "stock": firestore.Increment(res_qty),
                        "isAvailable": True,
                    })
                except Exception:
                    pass
            if isinstance(exc, HTTPException):
                raise exc
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Failed to reserve inventory: {str(exc)}",
            )

        # ── 3. Debit Wallet (if payment_method == 'wallet') ───────────────────
        order_id = f"ord_{uuid.uuid4().hex[:12]}"
        payment_method = payload.payment_method.lower().strip()

        if payment_method == "wallet":
            wallet_ref = db.collection("wallets").document(user_uid)
            tx_id = f"tx_{uuid.uuid4().hex[:16]}"
            tx_ref = db.collection("wallet_transactions").document(tx_id)

            try:
                tx = db.transaction()
                _debit_wallet_tx(
                    tx,
                    wallet_ref,
                    tx_ref,
                    user_uid=user_uid,
                    amount=float(total_amount),
                    order_id=order_id,
                )
            except Exception as exc:
                # Roll back stock reservations if wallet debit fails
                for res_id, res_qty in reserved_items:
                    try:
                        db.collection("Menu").document(res_id).update({
                            "stock": firestore.Increment(res_qty),
                            "isAvailable": True,
                        })
                    except Exception:
                        pass
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Payment failed: {str(exc)}",
                )

        # ── 4. Scoped Token Allocation & Order Persistence ───────────────────
        today_str = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d")
        tokens_out: list[CheckoutTokenDetail] = []
        overall_token_num = 0

        order_ref = db.collection("Orders").document(order_id)
        tokens_subcol = order_ref.collection("tokens")

        for category, cat_items in category_groups.items():
            tracker_ref = db.collection("counter_tracker").document(f"{today_str}_{category}")
            tx = db.transaction()
            allocated_token = _allocate_scoped_token_tx(tx, tracker_ref)
            if overall_token_num == 0:
                overall_token_num = allocated_token

            is_mess = (category == "mess")
            otp = f"{random.randint(1000, 9999)}" if is_mess else None

            token_doc_data = {
                "token_number": allocated_token,
                "counter": category,
                "token_status": "placed",
                "qr_valid": True,
                "qr_code_data": f"{order_id}:{category}:{allocated_token}",
                "otp": otp,
                "otp_verified": False if is_mess else None,
                "items": cat_items,
                "created_at": firestore.SERVER_TIMESTAMP,
            }
            tokens_subcol.document(category).set(token_doc_data)

            tokens_out.append(
                CheckoutTokenDetail(
                    counter=category,
                    token_number=allocated_token,
                    qr_valid=True,
                    otp=otp,
                )
            )

        # ── 5. Save Parent Order Document ─────────────────────────────────────
        order_doc_data = {
            "order_id": order_id,
            "userId": user_uid,
            "userName": payload.user_name or "Customer",
            "items": resolved_items,
            "total": total_amount,
            "status": "placed",
            "overall_status": "active",
            "tokenNumber": overall_token_num,
            "paymentMethod": payment_method,
            "payment_status": "paid",
            "timestamp": firestore.SERVER_TIMESTAMP,
        }
        order_ref.set(order_doc_data)

        return CheckoutResponse(
            order_id=order_id,
            total=total_amount,
            token_number=overall_token_num,
            status="placed",
            payment_method=payment_method,
            tokens=tokens_out,
        )
