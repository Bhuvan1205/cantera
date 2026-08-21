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


@firestore.transactional
def _decrement_stock_tx(
    transaction: firestore.Transaction,
    menu_ref,
    requested_qty: int,
) -> None:
    """
    P0 Fix: Authoritative transactional stock check-and-decrement.

    Reads current stock inside the Firestore transaction, validates sufficiency,
    and writes the new value atomically.  Firestore's OCC serialises concurrent
    callers on the same document: only one commit wins per unit of stock, so
    overselling is structurally impossible.
    """
    snap = menu_ref.get(transaction=transaction)
    if not snap.exists:
        raise ValueError(f"Menu item '{menu_ref.id}' no longer exists.")
    m_data = snap.to_dict() or {}
    if not is_quantified_item(m_data):
        # Availability-only item — no numeric stock gate needed
        return
    current_stock = int(m_data.get("stock") or 0)
    if current_stock < requested_qty:
        item_name = m_data.get("name", menu_ref.id)
        raise ValueError(
            f"Insufficient stock for '{item_name}'. Available: {current_stock}, Requested: {requested_qty}"
        )
    new_stock = current_stock - requested_qty
    updates = {"stock": new_stock}
    if new_stock == 0:
        updates["isAvailable"] = False
    transaction.update(menu_ref, updates)


class CheckoutService:
    @staticmethod
    def execute_checkout(
        user_uid: str,
        payload: CheckoutRequest,
        actor_email: str,
        order_id: Optional[str] = None
    ) -> CheckoutResponse:
        total_amount = 0.0
        resolved_items = []
        category_groups: dict[str, list] = {}
        quantities: dict[str, int] = {}

        for req_item in payload.items:
            quantities[req_item.menu_item_id] = quantities.get(req_item.menu_item_id, 0) + req_item.quantity

        menu_refs = [db.collection("Menu").document(k) for k in quantities.keys()]
        menu_snaps = {doc.id: doc for doc in db.get_all(menu_refs)}

        for item_id, qty in quantities.items():
            snap = menu_snaps.get(item_id)
            if not snap or not snap.exists:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail=f"Menu item '{item_id}' not found.",
                )
            
            m_data = snap.to_dict() or {}
            if not m_data.get("isAvailable", False):
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Item '{m_data.get('name', item_id)}' is currently unavailable.",
                )

            price = float(m_data.get("price", 0.0))
            category = m_data.get("category", "other")
            total_amount += price * qty
            
            prep_units = _calc_prep_units(qty) if category in _SMART_PREP_CATS else 0.0
            
            resolved = {
                "menuItemId": item_id,
                "name": m_data.get("name", "Unknown"),
                "item_name": m_data.get("name", "Unknown"),
                "quantity": qty,
                "price": price,
                "category": category,
                "prep_units": prep_units,
            }
            resolved_items.append(resolved)
            
            if category not in category_groups:
                category_groups[category] = []
            category_groups[category].append(resolved)

        payment_method = payload.payment_method.lower().strip()
        order_id = order_id or f"ord_{uuid.uuid4().hex[:12]}"
        today_str = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d")

        wallet_ref = db.collection("wallets").document(user_uid) if payment_method == "wallet" else None
        tx_id = f"tx_{uuid.uuid4().hex[:16]}"
        wallet_tx_ref = db.collection("wallet_transactions").document(tx_id) if payment_method == "wallet" else None
        
        order_ref = db.collection("Orders").document(order_id)
        tokens_subcol = order_ref.collection("tokens")
        
        tracker_refs = {cat: db.collection("counter_tracker").document(f"{today_str}_{cat}") for cat in category_groups.keys()}

        tx = db.transaction()

        @firestore.transactional
        def _commit_checkout(transaction):
            # 1. READ PHASE (MUST DO ALL READS FIRST)
            menu_reads = {}
            for item_id in quantities.keys():
                menu_reads[item_id] = db.collection("Menu").document(item_id).get(transaction=transaction)

            w_snap = None
            if wallet_ref:
                w_snap = wallet_ref.get(transaction=transaction)
            
            tracker_reads = {}
            for cat, ref in tracker_refs.items():
                tracker_reads[cat] = ref.get(transaction=transaction)

            # 2. VALIDATION & STATE MUTATION (IN-MEMORY)
            stock_updates = {}
            for item_id, qty in quantities.items():
                m_data = menu_reads[item_id].to_dict() or {}
                if is_quantified_item(m_data):
                    current_stock = int(m_data.get("stock", 0))
                    if current_stock < qty:
                        raise ValueError(f"STOCK_ERROR: Insufficient stock for '{m_data.get('name', item_id)}'. Available: {current_stock}, Requested: {qty}")
                    stock_updates[item_id] = current_stock - qty

            wallet_updates = {}
            if wallet_ref:
                if not w_snap or not w_snap.exists:
                    raise ValueError("WALLET_ERROR: Wallet not found for user.")
                w_data = w_snap.to_dict() or {}
                curr_balance = float(w_data.get("balance", 0.0))
                if curr_balance < total_amount:
                    raise ValueError(f"WALLET_ERROR: Insufficient funds. Balance: INR {curr_balance:.2f}, Required: INR {total_amount:.2f}")
                
                wallet_updates["balance"] = curr_balance - total_amount
                wallet_updates["total_spent"] = float(w_data.get("total_spent", 0.0)) + total_amount
                wallet_updates["version"] = int(w_data.get("version", 0)) + 1
                wallet_updates["balance_before"] = curr_balance

            allocated_tokens = {}
            tracker_updates = {}
            for cat, t_snap in tracker_reads.items():
                if t_snap.exists:
                    t_data = t_snap.to_dict() or {}
                    new_token = int(t_data.get("last_token", 0)) + 1
                else:
                    new_token = 1
                allocated_tokens[cat] = new_token
                tracker_updates[cat] = new_token

            # 3. WRITE PHASE
            # For testing crash atomicity: if ENV=="test_crash_middle", we inject failure HERE.
            if os.environ.get("ENV") == "test_crash_middle":
                raise RuntimeError("Injected process crash during transaction.")

            for item_id, new_stock in stock_updates.items():
                transaction.update(db.collection("Menu").document(item_id), {"stock": new_stock})

            if wallet_ref:
                transaction.update(wallet_ref, {
                    "balance": wallet_updates["balance"],
                    "total_spent": wallet_updates["total_spent"],
                    "version": wallet_updates["version"],
                    "last_updated": firestore.SERVER_TIMESTAMP,
                })
                transaction.set(wallet_tx_ref, {
                    "user_uid": user_uid,
                    "type": "debit",
                    "amount": float(total_amount),
                    "status": "success",
                    "description": f"Order checkout {order_id[:8]}",
                    "timestamp": firestore.SERVER_TIMESTAMP,
                    "balance_before": wallet_updates["balance_before"],
                    "balance_after": wallet_updates["balance"],
                    "sequence_number": wallet_updates["version"],
                    "reference_type": "checkout",
                    "reference_id": order_id,
                })

            for cat, new_token in tracker_updates.items():
                ref = tracker_refs[cat]
                if tracker_reads[cat].exists:
                    transaction.update(ref, {"last_token": new_token, "updated_at": firestore.SERVER_TIMESTAMP})
                else:
                    transaction.set(ref, {"last_token": new_token, "date": today_str, "counter": cat, "created_at": firestore.SERVER_TIMESTAMP, "updated_at": firestore.SERVER_TIMESTAMP})

            overall_token_num = 0
            category_tokens_map = {}
            tokens_out = []
            
            for category, cat_items in category_groups.items():
                allocated_token = allocated_tokens[category]
                if overall_token_num == 0:
                    overall_token_num = allocated_token

                is_smart_prep = category in ["mess", "continental"]
                qr_code_data = "" if is_smart_prep else f"{order_id}:{category}:{allocated_token}"

                transaction.set(tokens_subcol.document(category), {
                    "token_number": allocated_token,
                    "counter": category,
                    "token_status": "placed",
                    "qr_valid": not is_smart_prep,
                    "qr_code_data": qr_code_data,
                    "items": cat_items,
                    "created_at": firestore.SERVER_TIMESTAMP,
                })

                category_tokens_map[category] = {
                    "tokenId": qr_code_data,
                    "tokenNumber": allocated_token,
                    "status": "placed",
                    "items": cat_items,
                }
                tokens_out.append(CheckoutTokenDetail(counter=category, token_number=allocated_token, qr_valid=True))

            transaction.set(order_ref, {
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
            })

            return overall_token_num, tokens_out

        try:
            overall_token_num, tokens_out = _commit_checkout(tx)
        except ValueError as exc:
            msg = str(exc)
            if msg.startswith("STOCK_ERROR:"):
                raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=msg.replace("STOCK_ERROR: ", ""))
            elif msg.startswith("WALLET_ERROR:"):
                raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=msg.replace("WALLET_ERROR: ", ""))
            raise
        except HTTPException:
            raise
        except Exception as exc:
            raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=f"Failed to finalize order: {str(exc)}")

        return CheckoutResponse(
            order_id=order_id,
            total=total_amount,
            token_number=overall_token_num,
            status="placed",
            payment_method=payment_method,
            tokens=tokens_out,
        )
