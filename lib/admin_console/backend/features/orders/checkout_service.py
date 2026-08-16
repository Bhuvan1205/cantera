import os
import datetime
import random
import threading
import uuid
from typing import Optional
from fastapi import HTTPException, status
from google.cloud import firestore

from config.firebase import db
from features.inventory.schemas import is_quantified_item
from .schemas import (
    CheckoutCartItem,
    CheckoutRequest,
    CheckoutResponse,
    CheckoutTokenDetail,
)
from .repository import _calc_prep_units

# Categories that participate in Smart Preparation queue flow
_SMART_PREP_CATS = {"mess", "continental"}


def _trace_backend_step(step: str, exception: str = "None") -> None:
    print(
        f"{step}\n"
        f"Executed: YES\n"
        f"Timestamp: {datetime.datetime.now(datetime.timezone.utc).isoformat()}\n"
        f"Process: {os.getpid()}\n"
        f"Thread: {threading.current_thread().name}\n"
        f"Exception: {exception}",
        flush=True,
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
      1. Resolve prices, availability, and stock via single-pass batched read (db.get_all)
      2. In-memory validation (no duplicate reads or premature writes)
      3. Transactionally debit wallet balance (isolated transaction if payment_method == 'wallet')
      4. Allocate scoped tokens atomically per counter
      5. Atomic WriteBatch commit across stock updates, token sub-documents, and order document
    """

    @staticmethod
    def execute_checkout(
        user_uid: str,
        payload: CheckoutRequest,
        actor_email: Optional[str] = None,
    ) -> CheckoutResponse:
        _trace_backend_step("STEP 9")
        if not payload.items:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Cart cannot be empty.",
            )

        # ── 1. Single-Pass Batched Read & In-Memory Validation ───────────────
        unique_item_ids = list({item.menu_item_id for item in payload.items})
        menu_refs = [db.collection("Menu").document(mid) for mid in unique_item_ids]
        
        # Single RPC roundtrip to fetch all menu documents
        menu_snaps_list = db.get_all(menu_refs)
        menu_snaps = {snap.id: snap for snap in menu_snaps_list}

        # Calculate requested quantities per menu item
        req_qty_by_id: dict[str, int] = {}
        for item in payload.items:
            req_qty_by_id[item.menu_item_id] = req_qty_by_id.get(item.menu_item_id, 0) + item.quantity

        resolved_items = []
        category_groups: dict[str, list[dict]] = {}
        stock_updates: list[tuple[any, dict]] = []
        total_amount = 0

        # Validate existence, availability, and stock from the single snapshot
        for item in payload.items:
            menu_snap = menu_snaps.get(item.menu_item_id)
            if not menu_snap or not menu_snap.exists:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail=f"Menu item '{item.menu_item_id}' not found.",
                )

            m_data = menu_snap.to_dict() or {}
            is_avail = m_data.get("isAvailable", m_data.get("is_available", True))
            if not is_avail:
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
                # item_name is the canonical key read by queue logic in repository.start_preparation
                "item_name": item_name,
                "price": price,
                "quantity": item.quantity,
                "category": category,
                "current_stock": stock_qty,
                # prep_units is required by queue insertion; 0.0 for non-Smart-Prep categories
                "prep_units": _calc_prep_units(item.quantity) if category in _SMART_PREP_CATS else 0.0,
            }
            resolved_items.append(item_dict)
            category_groups.setdefault(category, []).append(item_dict)

        # Validate stock levels across all requested items (skip availability-only items)
        for item_id, total_req_qty in req_qty_by_id.items():
            menu_snap = menu_snaps[item_id]
            m_data = menu_snap.to_dict() or {}

            # Availability-only items bypass numeric stock tracking & deduction
            if not is_quantified_item(m_data):
                continue

            stock = m_data.get("stock")
            if stock is not None:
                current_stock = int(stock)
                if current_stock < total_req_qty:
                    item_name = str(m_data.get("name", item_id))
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail=f"Insufficient stock for '{item_name}'. Available: {current_stock}, Requested: {total_req_qty}",
                    )
                new_stock = current_stock - total_req_qty
                updates = {"stock": new_stock}
                if new_stock == 0:
                    updates["isAvailable"] = False
                stock_updates.append((menu_snap.reference, updates))

        # ── 2. Isolated Wallet Debit (if payment_method == 'wallet') ─────────
        order_id = f"ord_{uuid.uuid4().hex[:12]}"
        payment_method = payload.payment_method.lower().strip()
        wallet_debited = False

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
                wallet_debited = True
            except Exception as exc:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Payment failed: {str(exc)}",
                )

        # ── 3. Scoped Token Allocation ───────────────────────────────────────
        today_str = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d")
        tokens_out: list[CheckoutTokenDetail] = []
        token_docs_to_batch: list[tuple[any, dict]] = []
        category_tokens_map: dict[str, dict] = {}
        overall_token_num = 0

        order_ref = db.collection("Orders").document(order_id)
        tokens_subcol = order_ref.collection("tokens")

        try:
            for category, cat_items in category_groups.items():
                tracker_ref = db.collection("counter_tracker").document(f"{today_str}_{category}")
                tx = db.transaction()
                allocated_token = _allocate_scoped_token_tx(tx, tracker_ref)
                if overall_token_num == 0:
                    overall_token_num = allocated_token

                is_smart_prep = category in ["mess", "continental"]
                qr_code_data = "" if is_smart_prep else f"{order_id}:{category}:{allocated_token}"

                token_doc_data = {
                    "token_number": allocated_token,
                    "counter": category,
                    "token_status": "placed",
                    "qr_valid": not is_smart_prep,
                    "qr_code_data": qr_code_data,
                    "items": cat_items,
                    "created_at": firestore.SERVER_TIMESTAMP,
                }
                token_docs_to_batch.append((tokens_subcol.document(category), token_doc_data))

                category_tokens_map[category] = {
                    "tokenId": qr_code_data,
                    "tokenNumber": allocated_token,
                    "status": "placed",
                    "items": cat_items,
                }

                tokens_out.append(
                    CheckoutTokenDetail(
                        counter=category,
                        token_number=allocated_token,
                        qr_valid=True,
                    )
                )

            # ── 4. Atomic WriteBatch Commit (Stock + Tokens + Parent Order) ───
            batch = db.batch()

            # Batch inventory stock updates
            for ref, updates in stock_updates:
                batch.update(ref, updates)

            # Batch token documents
            for doc_ref, doc_data in token_docs_to_batch:
                batch.set(doc_ref, doc_data)

            # Batch parent order document
            order_doc_data = {
                "order_id": order_id,
                "userId": user_uid,
                "userName": payload.user_name or "Customer",
                "items": resolved_items,
                "total": total_amount,
                "status": "placed",
                "overall_status": "active",
                "tokenNumber": overall_token_num,
                "categoryTokens": category_tokens_map,
                "paymentMethod": payment_method,
                "payment_status": "paid",
                "timestamp": firestore.SERVER_TIMESTAMP,
            }
            batch.set(order_ref, order_doc_data)

            # Commit all writes in a single RPC roundtrip
            batch.commit()

        except Exception as exc:
            # If batch commit fails and wallet was debited, refund the wallet
            if wallet_debited:
                try:
                    refund_tx_ref = db.collection("wallet_transactions").document(f"tx_refund_{uuid.uuid4().hex[:12]}")
                    wallet_ref = db.collection("wallets").document(user_uid)
                    @firestore.transactional
                    def _rollback_wallet(transaction):
                        w_snap = wallet_ref.get(transaction=transaction)
                        if w_snap.exists:
                            curr_b = float(w_snap.to_dict().get("balance") or 0.0)
                            curr_spent = float(w_snap.to_dict().get("total_spent") or 0.0)
                            transaction.update(wallet_ref, {
                                "balance": curr_b + float(total_amount),
                                "total_spent": max(0.0, curr_spent - float(total_amount)),
                                "updated_at": firestore.SERVER_TIMESTAMP,
                            })
                            transaction.set(refund_tx_ref, {
                                "user_uid": user_uid,
                                "type": "refund",
                                "amount": float(total_amount),
                                "reference_id": order_id,
                                "description": f"Auto-refund failed order #{order_id[:8]}",
                                "status": "completed",
                                "created_at": firestore.SERVER_TIMESTAMP,
                            })
                    _rollback_wallet(db.transaction())
                except Exception:
                    pass

            if isinstance(exc, HTTPException):
                raise exc
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Failed to finalize order: {str(exc)}",
            )

        return CheckoutResponse(
            order_id=order_id,
            total=total_amount,
            token_number=overall_token_num,
            status="placed",
            payment_method=payment_method,
            tokens=tokens_out,
        )
