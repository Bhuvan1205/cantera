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
            wallet_ref = db.collection(_WALLETS_COL).document(user_uid)
            txn_ref = db.collection(_TXNS_COL).document()
            order_ref = db.collection(_ORDERS_COL).document(order_id) if order_id else None

            @db.transaction
            def _run_refund(transaction):
                # 1. Re-read refund inside transaction to prevent double approval
                r_snap = refund_ref.get(transaction=transaction)
                if not r_snap.exists:
                    return False
                r_dict = r_snap.to_dict() or {}
                if r_dict.get("status") in ("credited", "rejected"):
                    return False

                # 2. Re-read wallet inside transaction
                w_snap = wallet_ref.get(transaction=transaction)
                curr_balance = 0.0
                total_added = 0.0
                total_spent = 0.0
                curr_version = 0

                if w_snap.exists:
                    w_dict = w_snap.to_dict() or {}
                    curr_balance = float(w_dict.get("balance", 0.0))
                    total_added = float(w_dict.get("total_added", 0.0))
                    total_spent = float(w_dict.get("total_spent", 0.0))
                    curr_version = int(w_dict.get("version", 0))

                new_version = curr_version + 1
                new_balance = curr_balance + amount
                new_spent = max(0.0, total_spent - amount)

                if w_snap.exists:
                    transaction.update(wallet_ref, {
                        "balance": new_balance,
                        "total_added": total_added,
                        "total_spent": new_spent,
                        "version": new_version,
                        "last_updated": firestore.SERVER_TIMESTAMP,
                    })
                else:
                    transaction.set(wallet_ref, {
                        "balance": new_balance,
                        "total_added": total_added,
                        "total_spent": new_spent,
                        "version": new_version,
                        "created_at": firestore.SERVER_TIMESTAMP,
                        "last_updated": firestore.SERVER_TIMESTAMP,
                    })

                # 3. Create wallet transaction record
                transaction.set(txn_ref, {
                    "user_uid": user_uid,
                    "type": "refund",
                    "amount": amount,
                    "status": "completed",
                    "reference_type": "refund_request",
                    "reference_id": refund_id,
                    "order_id": order_id,
                    "balance_before": curr_balance,
                    "balance_after": new_balance,
                    "sequence_number": new_version,
                    "initiated_by": f"admin:{admin_uid}",
                    "timestamp": firestore.SERVER_TIMESTAMP,
                })


                # 4. Update refund request document
                transaction.update(refund_ref, {
                    "status": "credited",
                    "reviewed_at": firestore.SERVER_TIMESTAMP,
                    "reviewed_by": admin_uid,
                })

                # 5. Update associated order if exists
                if order_ref:
                    o_snap = order_ref.get(transaction=transaction)
                    if o_snap.exists:
                        transaction.update(order_ref, {
                            "status": "refunded",
                            "overall_status": "completed",
                        })
                return True

            _run_refund()

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
            curr_version = 0

            if w_snap.exists:
                w_data = w_snap.to_dict() or {}
                curr_balance = float(w_data.get("balance", 0.0))
                curr_total_added = float(w_data.get("total_added", 0.0))
                curr_version = int(w_data.get("version", 0))
                new_version = curr_version + 1
                transaction.update(wallet_ref, {
                    "balance": curr_balance + amount,
                    "total_added": curr_total_added + amount,
                    "version": new_version,
                    "last_updated": firestore.SERVER_TIMESTAMP,
                })
            else:
                # First deposit — create the wallet document.
                new_version = 1
                transaction.set(wallet_ref, {
                    "balance": amount,
                    "total_added": amount,
                    "total_spent": 0.0,
                    "version": new_version,
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
                "balance_before": curr_balance,
                "balance_after": new_balance,
                "sequence_number": new_version,
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

    @staticmethod
    def create_refund_request(
        user_uid: str,
        order_id: str,
        reason: Optional[str] = None,
    ) -> RefundRequestItem:
        """
        Creates a refund request in refund_requests and sets order status to refund_pending.
        """
        from fastapi import HTTPException, status as http_status

        order_ref = db.collection(_ORDERS_COL).document(order_id)
        order_snap = order_ref.get()
        if not order_snap.exists:
            raise HTTPException(
                status_code=http_status.HTTP_404_NOT_FOUND,
                detail=f"Order '{order_id}' not found.",
            )

        order_data = order_snap.to_dict() or {}
        if order_data.get("userId") != user_uid:
            raise HTTPException(
                status_code=http_status.HTTP_403_FORBIDDEN,
                detail="You can only request a refund for your own orders.",
            )

        curr_status = str(order_data.get("status", "")).lower()
        if curr_status != "placed":
            raise HTTPException(
                status_code=http_status.HTTP_400_BAD_REQUEST,
                detail=f"Refund can only be requested for orders in 'placed' status (current: {curr_status}).",
            )

        # Check for existing pending/approved refund request
        existing_reqs = (
            db.collection(_REFUND_REQUESTS_COL)
            .where("order_id", "==", order_id)
            .stream()
        )
        for req in existing_reqs:
            r_data = req.to_dict() or {}
            if r_data.get("status") in ("refund_requested", "refund_under_review", "approved", "credited"):
                raise HTTPException(
                    status_code=http_status.HTTP_400_BAD_REQUEST,
                    detail=f"A refund request already exists for order '{order_id}' (status: {r_data.get('status')}).",
                )

        amount = float(order_data.get("total", 0.0))
        req_ref = db.collection(_REFUND_REQUESTS_COL).document()

        doc_data = {
            "user_uid": user_uid,
            "order_id": order_id,
            "amount": amount,
            "reason": reason or "Customer requested cancellation",
            "status": "refund_requested",
            "created_at": firestore.SERVER_TIMESTAMP,
            "updated_at": firestore.SERVER_TIMESTAMP,
        }
        req_ref.set(doc_data)
        order_ref.update({"status": "refund_pending"})

        created_snap = req_ref.get()
        return RefundRequestItem.from_firestore(req_ref.id, created_snap.to_dict() or doc_data)

    @staticmethod
    def create_manual_adjustment(
        user_uid: str,
        amount: float,
        description: str,
        admin_uid: str,
    ) -> dict:
        """
        Executes a manual wallet adjustment for admin operations.
        """
        from fastapi import HTTPException, status as http_status

        user_ref = db.collection("Users").document(user_uid)
        if not user_ref.get().exists:
            raise HTTPException(
                status_code=http_status.HTTP_404_NOT_FOUND,
                detail=f"User '{user_uid}' not found.",
            )

        wallet_ref = db.collection(_WALLETS_COL).document(user_uid)
        txn_ref = db.collection(_TXNS_COL).document()

        @db.transaction
        def _run(transaction):
            w_snap = wallet_ref.get(transaction=transaction)
            curr_balance = 0.0
            curr_total_added = 0.0
            curr_total_spent = 0.0
            version = 0

            if w_snap.exists:
                w_data = w_snap.to_dict() or {}
                curr_balance = float(w_data.get("balance", 0.0))
                curr_total_added = float(w_data.get("total_added", 0.0))
                curr_total_spent = float(w_data.get("total_spent", 0.0))
                version = int(w_data.get("version", 0))

            new_balance = curr_balance + amount
            if new_balance < 0:
                raise HTTPException(
                    status_code=http_status.HTTP_400_BAD_REQUEST,
                    detail=f"Insufficient balance for debit. Current balance: INR {curr_balance:.2f}",
                )

            new_version = version + 1
            wallet_payload = {
                "balance": new_balance,
                "version": new_version,
                "last_updated": firestore.SERVER_TIMESTAMP,
            }
            if amount > 0:
                wallet_payload["total_added"] = curr_total_added + amount
            else:
                wallet_payload["total_spent"] = curr_total_spent + abs(amount)

            if not w_snap.exists:
                wallet_payload["created_at"] = firestore.SERVER_TIMESTAMP
                transaction.set(wallet_ref, wallet_payload)
            else:
                transaction.update(wallet_ref, wallet_payload)

            transaction.set(txn_ref, {
                "user_uid": user_uid,
                "type": "adjustment",
                "amount": abs(amount),
                "status": "success",
                "description": description,
                "direction": "credit" if amount > 0 else "debit",
                "initiated_by": admin_uid,
                "timestamp": firestore.SERVER_TIMESTAMP,
                "balance_before": curr_balance,
                "balance_after": new_balance,
                "sequence_number": new_version,
                "reference_type": "adjustment",
                "reference_id": txn_ref.id,
            })

            return {
                "user_uid": user_uid,
                "amount": amount,
                "balance_before": curr_balance,
                "balance_after": new_balance,
                "transaction_id": txn_ref.id,
            }

        return _run()


