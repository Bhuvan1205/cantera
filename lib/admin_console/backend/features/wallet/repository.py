from typing import Optional
from google.cloud import firestore

from config.firebase import db
from .schemas import (
    PendingDepositItem,
    RefundRequestItem,
    UserWalletInvestigation,
)

_PENDING_DEPOSITS_COL = "pending_deposits"
_REFUND_REQUESTS_COL = "refund_requests"
_WALLETS_COL = "wallets"
_TXNS_COL = "wallet_transactions"
_ORDERS_COL = "Orders"


class WalletRepository:
    """
    Firestore operations for Wallet: Pending Deposits, Refund Requests,
    Transaction Records, and Wallet Balances.
    """

    @staticmethod
    def list_deposits(
        status_filter: Optional[str] = None,
        limit: int = 50,
    ) -> list[PendingDepositItem]:
        query = db.collection(_PENDING_DEPOSITS_COL)
        if status_filter:
            query = query.where("status", "==", status_filter)
            docs = query.limit(limit).stream()
        else:
            try:
                docs = query.order_by("created_at", direction=firestore.Query.DESCENDING).limit(limit).stream()
            except Exception:
                docs = query.limit(limit).stream()

        deposits = [
            PendingDepositItem.from_firestore(doc.id, doc.to_dict() or {})
            for doc in docs
        ]
        deposits.sort(key=lambda d: str(d.created_at or ""), reverse=True)
        return deposits

    @staticmethod
    def list_refunds(
        status_filter: Optional[str] = None,
        limit: int = 50,
    ) -> list[RefundRequestItem]:
        query = db.collection(_REFUND_REQUESTS_COL)
        if status_filter:
            query = query.where("status", "==", status_filter)
            docs = query.limit(limit).stream()
        else:
            try:
                docs = query.order_by("created_at", direction=firestore.Query.DESCENDING).limit(limit).stream()
            except Exception:
                docs = query.limit(limit).stream()

        refunds = [
            RefundRequestItem.from_firestore(doc.id, doc.to_dict() or {})
            for doc in docs
        ]
        refunds.sort(key=lambda r: str(r.created_at or ""), reverse=True)
        return refunds

    @staticmethod
    def get_refund_by_id(refund_id: str) -> RefundRequestItem | None:
        snap = db.collection(_REFUND_REQUESTS_COL).document(refund_id).get()
        if not snap.exists:
            return None
        return RefundRequestItem.from_firestore(snap.id, snap.to_dict() or {})

    @staticmethod
    def update_refund_status(
        refund_id: str,
        new_status: str,
        admin_uid: str,
        reason: Optional[str] = None,
    ) -> RefundRequestItem | None:
        refund_ref = db.collection(_REFUND_REQUESTS_COL).document(refund_id)
        snap = refund_ref.get()
        if not snap.exists:
            return None

        refund_data = snap.to_dict() or {}
        user_uid = refund_data.get("user_uid", refund_data.get("userId", ""))
        amount = float(refund_data.get("amount", 0.0))
        order_id = refund_data.get("order_id", refund_data.get("orderId", ""))

        if new_status in ("approved", "credited"):
            # Crediting wallet transaction
            wallet_ref = db.collection(_WALLETS_COL).document(user_uid)
            wallet_snap = wallet_ref.get()

            curr_balance = 0.0
            total_added = 0.0
            total_spent = 0.0

            if wallet_snap.exists:
                w_dict = wallet_snap.to_dict() or {}
                curr_balance = float(w_dict.get("balance", 0.0))
                total_added = float(w_dict.get("total_added", 0.0))
                total_spent = float(w_dict.get("total_spent", 0.0))

            new_balance = curr_balance + amount
            new_spent = max(0.0, total_spent - amount)

            wallet_ref.set({
                "balance": new_balance,
                "total_added": total_added,
                "total_spent": new_spent,
            }, merge=True)

            # Create wallet transaction record
            txn_ref = db.collection(_TXNS_COL).document()
            txn_ref.set({
                "user_uid": user_uid,
                "type": "refund",
                "amount": amount,
                "status": "completed",
                "reference_type": "refund_request",
                "reference_id": refund_id,
                "order_id": order_id,
                "balance_after": new_balance,
                "initiated_by": f"admin:{admin_uid}",
                "timestamp": firestore.SERVER_TIMESTAMP,
            })

            # Update refund request document
            refund_ref.update({
                "status": "credited",
                "reviewed_at": firestore.SERVER_TIMESTAMP,
                "reviewed_by": admin_uid,
            })

            # Update associated order if exists
            if order_id:
                order_ref = db.collection(_ORDERS_COL).document(order_id)
                if order_ref.get().exists:
                    order_ref.update({
                        "status": "refunded",
                        "overall_status": "completed",
                    })

        elif new_status == "rejected":
            refund_ref.update({
                "status": "rejected",
                "reviewed_at": firestore.SERVER_TIMESTAMP,
                "reviewed_by": admin_uid,
                "reject_reason": reason,
            })
            # Revert order status back to placed if it was refund_pending
            if order_id:
                order_ref = db.collection(_ORDERS_COL).document(order_id)
                o_snap = order_ref.get()
                if o_snap.exists and (o_snap.to_dict() or {}).get("status") == "refund_pending":
                    order_ref.update({"status": "placed"})

        elif new_status == "refund_under_review":
            refund_ref.update({
                "status": "refund_under_review",
                "reviewed_at": firestore.SERVER_TIMESTAMP,
                "reviewed_by": admin_uid,
            })

        return WalletRepository.get_refund_by_id(refund_id)

    @staticmethod
    def get_wallet_investigation(uid: str) -> UserWalletInvestigation:
        # 1. Wallet
        w_snap = db.collection(_WALLETS_COL).document(uid).get()
        w_data = w_snap.to_dict() or {} if w_snap.exists else {}
        balance = float(w_data.get("balance", 0.0))
        total_added = float(w_data.get("total_added", 0.0))
        total_spent = float(w_data.get("total_spent", 0.0))

        # 2. Transactions
        txn_docs = db.collection(_TXNS_COL).where("user_uid", "==", uid).stream()
        transactions = []
        for d in txn_docs:
            td = d.to_dict() or {}
            td["transaction_id"] = d.id
            if td.get("timestamp"):
                td["timestamp"] = str(td["timestamp"])
            transactions.append(td)

        # 3. Pending deposits
        dep_docs = db.collection(_PENDING_DEPOSITS_COL).where("user_uid", "==", uid).stream()
        deposits = [
            PendingDepositItem.from_firestore(d.id, d.to_dict() or {})
            for d in dep_docs
        ]

        # 4. Refund requests
        ref_docs = db.collection(_REFUND_REQUESTS_COL).where("user_uid", "==", uid).stream()
        refunds = [
            RefundRequestItem.from_firestore(d.id, d.to_dict() or {})
            for d in ref_docs
        ]

        return UserWalletInvestigation(
            user_uid=uid,
            balance=balance,
            total_added=total_added,
            total_spent=total_spent,
            transactions=transactions,
            pending_deposits=deposits,
            refund_requests=refunds,
        )

    @staticmethod
    def approve_deposit(deposit_id: str, reviewed_by: str) -> bool:
        """
        Atomically credits the wallet for an approved deposit.

        Idempotency — two guards are applied before any write:
          1. The deposit document is re-read inside the transaction; if its
             status is already 'approved', the transaction aborts and returns
             False (no double-credit).
          2. wallet_transactions is queried for an existing record whose
             idempotency_key matches the deposit's razorpay_payment_id.
             If one exists, the transaction aborts and returns False.

        Returns:
            True  — wallet was credited (new approval).
            False — deposit was already approved (idempotent no-op).

        Raises:
            ValueError — if deposit document does not exist.
        """
        deposit_ref = db.collection(_PENDING_DEPOSITS_COL).document(deposit_id)

        # Pre-read outside transaction to get payment_id for idempotency query.
        deposit_snap = deposit_ref.get()
        if not deposit_snap.exists:
            raise ValueError(f"Deposit '{deposit_id}' not found.")

        deposit_data = deposit_snap.to_dict() or {}
        user_uid = deposit_data.get("user_uid", "")
        amount = float(deposit_data.get("amount", 0.0))
        payment_id = deposit_data.get("razorpay_payment_id", "")
        gateway = deposit_data.get("gateway", "razorpay")

        # ── Idempotency check: existing wallet transaction for this payment ──
        existing_txns = (
            db.collection(_TXNS_COL)
            .where("idempotency_key", "==", payment_id)
            .where("status", "==", "success")
            .limit(1)
            .stream()
        )
        if any(True for _ in existing_txns):
            # A successful transaction for this payment_id already exists.
            return False

        wallet_ref = db.collection(_WALLETS_COL).document(user_uid)
        txn_ref = db.collection(_TXNS_COL).document()

        @db.transaction
        def _run(transaction):
            # Re-read deposit inside transaction — concurrent approval guard.
            d_snap = deposit_ref.get(transaction=transaction)
            d_data = d_snap.to_dict() or {}
            if d_data.get("status") != "awaiting_review":
                return False  # Already processed.

            # Read or initialise wallet.
            w_snap = wallet_ref.get(transaction=transaction)
            curr_balance = 0.0
            curr_total_added = 0.0

            if w_snap.exists:
                w_data = w_snap.to_dict() or {}
                curr_balance = float(w_data.get("balance", 0.0))
                curr_total_added = float(w_data.get("total_added", 0.0))
                transaction.update(wallet_ref, {
                    "balance": curr_balance + amount,
                    "total_added": curr_total_added + amount,
                    "last_updated": firestore.SERVER_TIMESTAMP,
                })
            else:
                # First deposit — create the wallet document.
                transaction.set(wallet_ref, {
                    "balance": amount,
                    "total_added": amount,
                    "total_spent": 0.0,
                    "created_at": firestore.SERVER_TIMESTAMP,
                    "last_updated": firestore.SERVER_TIMESTAMP,
                })

            new_balance = curr_balance + amount

            # Immutable transaction record.
            transaction.set(txn_ref, {
                "user_uid": user_uid,
                "type": "deposit",
                "amount": amount,
                "status": "success",
                "description": f"Wallet top-up via {'Mock Gateway' if gateway == 'mock' else 'Razorpay'}",
                "payment_ref": payment_id,
                "gateway": gateway,
                "initiated_by": f"backend:{reviewed_by}",
                "timestamp": firestore.SERVER_TIMESTAMP,
                "balance_after": new_balance,
                "idempotency_key": payment_id,
                "reference_type": "pending_deposit",
                "reference_id": deposit_id,
            })

            # Mark deposit approved.
            transaction.update(deposit_ref, {
                "status": "approved",
                "reviewed_at": firestore.SERVER_TIMESTAMP,
                "reviewed_by": reviewed_by,
            })

            return True

        return _run()
