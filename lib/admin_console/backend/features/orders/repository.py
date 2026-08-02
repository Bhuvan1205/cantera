import random
import time
from typing import Optional
from google.cloud import firestore

from config.firebase import db
from .schemas import (
    OrderItem,
    TokenDocument,
    OrderSummary,
    OrderDetail,
    CreateManualOrderRequest,
)

_ORDERS_COL = "Orders"
_QUEUES_COL = "queues"
_MENU_COL = "Menu"

_DEFAULT_PREP_TIMES = {
    "Plain Dosa": 3,
    "Masala Dosa": 4,
    "Onion Dosa": 4,
    "Idly": 6,
    "Vada": 5,
    "Poori": 4,
    "Veg Noodles": 7,
    "Veg Manchurian": 8,
    "Paneer Fried Rice": 9,
    "Schezwan Noodles": 8,
    "Veg Fried Rice": 8,
    "Manchurian Noodles": 9,
    "Manchurian Fried Rice": 9,
    "Schezwan Fried Rice": 8,
    "Schezwan Manchurian": 9,
    "Jeera Rice": 4,
    "Veg Meals": 5,
    "Special Meals": 6,
    "Parota with Kurma": 5,
    "Curd Rice": 3,
    "Curd": 1,
    "Curry": 1,
    "Sweet": 1,
}


def _calc_prep_units(qty: int) -> float:
    if qty == 1:
        return 1.0
    if qty == 2:
        return 1.5
    return 2.0


def _get_default_prep_time(item_name: str) -> int:
    return _DEFAULT_PREP_TIMES.get(item_name, 5)


class OrderRepository:
    """
    Firestore operations for Orders, Tokens, Queues, and Inventory Stock.
    """

    @staticmethod
    def list_orders(
        status_filter: Optional[str] = None,
        limit: int = 50,
    ) -> list[OrderSummary]:
        """
        Fetches orders sorted by timestamp descending, optionally filtered by status.
        """
        query = db.collection(_ORDERS_COL)
        if status_filter:
            query = query.where("status", "==", status_filter)
            docs = query.limit(limit).stream()
        else:
            try:
                docs = query.order_by("timestamp", direction=firestore.Query.DESCENDING).limit(limit).stream()
            except Exception:
                docs = query.limit(limit).stream()

        orders = [
            OrderSummary.from_firestore(doc.id, doc.to_dict() or {})
            for doc in docs
        ]
        orders.sort(key=lambda o: str(o.timestamp or ""), reverse=True)
        return orders

    @staticmethod
    def _find_order_doc_ref(order_id: str):
        """Helper to find DocumentReference by doc.id or order_id field."""
        doc_ref = db.collection(_ORDERS_COL).document(order_id)
        snap = doc_ref.get()
        if snap.exists:
            return doc_ref, snap

        # Fallback to query by 'order_id' field
        query_docs = list(db.collection(_ORDERS_COL).where("order_id", "==", order_id).limit(1).stream())
        if query_docs:
            return query_docs[0].reference, query_docs[0]
        return None, None

    @staticmethod
    def get_order_by_id(order_id: str) -> OrderDetail | None:
        """
        Fetches a single order along with all tokens in its tokens subcollection.
        """
        order_ref, order_snap = OrderRepository._find_order_doc_ref(order_id)
        if not order_ref or not order_snap.exists:
            return None

        order_data = order_snap.to_dict() or {}
        summary = OrderSummary.from_firestore(order_snap.id, order_data)

        # Stream subcollection tokens
        token_docs = order_ref.collection("tokens").stream()
        tokens = [
            TokenDocument.from_firestore(t_doc.id, t_doc.to_dict() or {})
            for t_doc in token_docs
        ]
        tokens.sort(key=lambda t: t.token_number)

        return OrderDetail(
            **summary.model_dump(),
            tokens=tokens,
        )

    @staticmethod
    def get_tokens_for_order(order_id: str) -> list[TokenDocument]:
        """
        Fetches all tokens in the subcollection of the specified order.
        """
        order_ref, order_snap = OrderRepository._find_order_doc_ref(order_id)
        if not order_ref:
            return []

        token_docs = order_ref.collection("tokens").stream()
        tokens = [
            TokenDocument.from_firestore(t_doc.id, t_doc.to_dict() or {})
            for t_doc in token_docs
        ]
        tokens.sort(key=lambda t: t.token_number)
        return tokens

    @staticmethod
    def create_manual_order(payload: CreateManualOrderRequest) -> OrderDetail:
        """
        Creates a manual order for offline/walk-in customers.
        Stored under userId="admin_placed".
        """
        base_token = int(time.time() * 1000) % 100000

        order_items_raw = []
        token_items: dict[str, list[dict]] = {}
        display_items: dict[str, list[dict]] = {}
        total = 0

        for item in payload.items:
            cat = item.category.lower().strip()
            qty = item.quantity
            price = item.price
            name = item.name.strip()

            total += price * qty
            order_items_raw.append({
                "name": name,
                "price": price,
                "quantity": qty,
                "category": cat,
            })

            token_items.setdefault(cat, []).append({
                "item_name": name,
                "quantity": qty,
                "unit_price": price,
                "prep_units": _calc_prep_units(qty) if cat == "mess" else 0.0,
            })

            display_items.setdefault(cat, []).append({
                "name": name,
                "quantity": qty,
                "price": price,
            })

        sorted_categories = sorted(token_items.keys())

        # Generate parent order document reference
        order_ref = db.collection(_ORDERS_COL).document()
        order_id = order_ref.id

        category_tokens_map = {}
        token_data_list = []

        for i, cat in enumerate(sorted_categories):
            cat_token_num = (base_token + i) % 100000
            items_for_cat = token_items[cat]
            is_mess = cat == "mess"

            token_ref = order_ref.collection("tokens").document()
            token_id = token_ref.id
            qr_code_data = f"{order_id}::{token_id}"

            category_tokens_map[cat] = {
                "tokenId": qr_code_data,
                "tokenNumber": cat_token_num,
                "status": "placed",
                "items": display_items[cat],
            }

            otp = None
            queue_name = None
            queue_position = None
            prep_units_in_queue = None

            if is_mess:
                otp = str(random.randint(1000, 9999))
                queue_name = items_for_cat[0]["item_name"]
                prep_units_in_queue = sum(item["prep_units"] for item in items_for_cat)

                # Get queue length
                queue_snap = db.collection(_QUEUES_COL).document(queue_name).get()
                existing_queue = queue_snap.to_dict().get("queue", []) if queue_snap.exists else []
                queue_position = len(existing_queue) + 1

            token_doc_data = {
                "token_id": token_id,
                "counter": cat,
                "items": items_for_cat,
                "token_status": "placed",
                "token_number": cat_token_num,
                "qr_valid": True,
                "qr_code_data": qr_code_data,
                "otp": otp,
                "otp_verified": False if is_mess else None,
                "queue_name": queue_name,
                "queue_position": queue_position,
                "prep_units_in_queue": prep_units_in_queue,
                "prep_start_time": None,
                "prep_end_time": None,
                "prep_duration_mins": None,
            }

            token_data_list.append((token_ref, token_doc_data, is_mess, queue_name, prep_units_in_queue, cat_token_num, token_id))

        # ── 1. Create parent order document ──────────────────────────────────
        order_ref.set({
            "userId": "admin_placed",
            "userName": "Walk-in Customer",
            "items": order_items_raw,
            "total": total,
            "status": "placed",
            "overall_status": "active",
            "tokenNumber": base_token,
            "timestamp": firestore.SERVER_TIMESTAMP,
            "categoryTokens": category_tokens_map,
            "order_id": order_id,
            "paymentMethod": payload.payment_method,
        })

        # ── 2. Create token sub-documents & update queues ─────────────────────
        tokens_created: list[TokenDocument] = []
        for token_ref, write_map, is_mess, queue_name, prep_units_in_queue, cat_token_num, token_id in token_data_list:
            token_ref.set(write_map)
            tokens_created.append(TokenDocument.from_firestore(token_ref.id, write_map))

            if is_mess and queue_name and prep_units_in_queue:
                queue_ref = db.collection(_QUEUES_COL).document(queue_name)
                queue_ref.set({
                    "item_name": queue_name,
                    "avg_prep_time_mins": _get_default_prep_time(queue_name),
                    "queue": firestore.ArrayUnion([{
                        "token_id": token_id,
                        "order_id": order_id,
                        "prep_units": prep_units_in_queue,
                        "token_number": cat_token_num,
                        "status": "waiting",
                    }]),
                    "total_prep_units_ahead": firestore.Increment(prep_units_in_queue),
                }, merge=True)

        # ── 3. Decrement stock for quantifiable items ────────────────────────
        for item in payload.items:
            cat = item.category.lower().strip()
            name = item.name.strip().lower()
            if cat in ("mess", "continental") or name in ("tea", "coffee"):
                continue

            # Query Menu item by matching name
            menu_query = db.collection(_MENU_COL).where("name", "==", item.name.strip()).limit(1).stream()
            for menu_doc in menu_query:
                doc_ref = menu_doc.reference
                qty = item.quantity

                @db.transaction
                def _decrement(transaction):
                    snap = doc_ref.get(transaction=transaction)
                    if snap.exists:
                        menu_data = snap.to_dict() or {}
                        if "stock" in menu_data and menu_data["stock"] is not None:
                            curr_stock = int(menu_data["stock"])
                            new_stock = max(0, curr_stock - qty)
                            transaction.update(doc_ref, {"stock": new_stock})

                _decrement()

        summary = OrderSummary(
            order_id=order_id,
            user_id="admin_placed",
            items=[
                OrderItem(
                    name=item.name,
                    price=item.price,
                    quantity=item.quantity,
                    category=item.category,
                )
                for item in payload.items
            ],
            total=total,
            status="placed",
            overall_status="active",
            token_number=base_token,
            payment_method=payload.payment_method,
            timestamp=str(time.time()),
        )

        return OrderDetail(
            **summary.model_dump(),
            tokens=tokens_created,
        )

    @staticmethod
    def update_order_status(order_id: str, new_status: str) -> OrderDetail | None:
        """
        Admin status override for an order (e.g. mark delivered, preparing, refund_pending, cancelled).
        Synchronizes overall_status, categoryTokens map, and subcollection tokens.
        """
        order_ref, snap = OrderRepository._find_order_doc_ref(order_id)
        if not order_ref or not snap or not snap.exists:
            return None

        data = snap.to_dict() or {}
        update_payload: dict = {"status": new_status}

        if new_status == "delivered":
            update_payload["overall_status"] = "completed"
        elif new_status in ("placed", "preparing"):
            update_payload["overall_status"] = "active"
        else:
            update_payload["overall_status"] = new_status

        # Synchronize categoryTokens map on parent document if present
        existing_cat_tokens = data.get("categoryTokens")
        if isinstance(existing_cat_tokens, dict):
            updated_cat_tokens = {}
            for cat_key, cat_val in existing_cat_tokens.items():
                if isinstance(cat_val, dict):
                    updated_item = dict(cat_val)
                    updated_item["status"] = new_status
                    updated_cat_tokens[cat_key] = updated_item
                else:
                    updated_cat_tokens[cat_key] = cat_val
            update_payload["categoryTokens"] = updated_cat_tokens

        order_ref.update(update_payload)

        # Synchronize tokens in subcollection
        token_docs = order_ref.collection("tokens").stream()
        for t_doc in token_docs:
            token_update = {"token_status": new_status}
            if new_status == "delivered":
                token_update["qr_valid"] = False
            elif new_status in ("placed", "preparing"):
                token_update["qr_valid"] = True
            t_doc.reference.update(token_update)

        return OrderRepository.get_order_by_id(snap.id)
