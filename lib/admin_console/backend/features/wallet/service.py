import hmac
import hashlib
from typing import Optional
from fastapi import HTTPException, status

from config.settings import RAZORPAY_KEY_SECRET
from .repository import WalletRepository
from .schemas import (
    PendingDepositItem,
    RefundRequestItem,
    UpdateRefundStatusRequest,
    UserWalletInvestigation,
)

VALID_REFUND_TARGET_STATUSES = {
    "refund_under_review",
    "approved",
    "credited",
    "rejected",
}


class WalletService:
    """
    Business logic layer for Wallet features.
    """

    @staticmethod
    def list_deposits(
        status_filter: Optional[str] = None,
        limit: int = 50,
    ) -> list[PendingDepositItem]:
        return WalletRepository.list_deposits(status_filter=status_filter, limit=limit)

    @staticmethod
    def list_refunds(
        status_filter: Optional[str] = None,
        limit: int = 50,
    ) -> list[RefundRequestItem]:
        return WalletRepository.list_refunds(status_filter=status_filter, limit=limit)

    @staticmethod
    def get_refund(refund_id: str) -> RefundRequestItem:
        refund = WalletRepository.get_refund_by_id(refund_id)
        if refund is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Refund request '{refund_id}' not found.",
            )
        return refund

    @staticmethod
    def update_refund_status(
        refund_id: str,
        payload: UpdateRefundStatusRequest,
        admin_uid: str,
    ) -> RefundRequestItem:
        target_status = payload.status.lower().strip()
        if target_status not in VALID_REFUND_TARGET_STATUSES:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=(
                    f"Invalid target status '{payload.status}'. "
                    f"Allowed: {', '.join(sorted(VALID_REFUND_TARGET_STATUSES))}"
                ),
            )

        existing = WalletRepository.get_refund_by_id(refund_id)
        if existing is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Refund request '{refund_id}' not found.",
            )

        if existing.status in ("credited", "rejected"):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Refund request '{refund_id}' is already finalized ({existing.status}).",
            )

        updated = WalletRepository.update_refund_status(
            refund_id=refund_id,
            new_status=target_status,
            admin_uid=admin_uid,
            reason=payload.reason,
        )
        return updated

    @staticmethod
    def get_wallet_investigation(uid: str) -> UserWalletInvestigation:
        return WalletRepository.get_wallet_investigation(uid)

    @staticmethod
    def verify_and_approve_deposit(deposit_id: str, user_uid: str) -> dict:
        """
        Payment verification pipeline:
          1. Read deposit from Firestore — verify it exists and belongs to user_uid.
          2. Idempotency fast-path — if deposit is already 'approved', return success
             without touching any financial state.
          3. Signature verification:
             - Mock gateway: verification is explicitly skipped (test-only path).
             - Razorpay: HMAC-SHA256 signature is verified using Python stdlib
               hmac + hashlib. No Razorpay SDK is used.
               Signature verification for Razorpay is MANDATORY and cannot be bypassed.
               If RAZORPAY_KEY_SECRET is not configured, the endpoint returns HTTP 500.
               If the signature is invalid, the endpoint returns HTTP 400 and the
               deposit is left in 'awaiting_review' — no financial state is modified.
          4. Delegate to WalletRepository.approve_deposit() for atomic credit.

        On any failure:
          - The deposit remains in 'awaiting_review'.
          - No wallet credit occurs.
          - No wallet_transactions record is created.
        """
        from config.firebase import db

        # ── 1. Read deposit and verify ownership ─────────────────────────────
        dep_snap = db.collection("pending_deposits").document(deposit_id).get()
        if not dep_snap.exists:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Deposit '{deposit_id}' not found.",
            )

        dep_data = dep_snap.to_dict() or {}
        if dep_data.get("user_uid") != user_uid:
            # Do not reveal existence to wrong user — treat as not found.
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Deposit '{deposit_id}' not found.",
            )

        # ── 2. Idempotency fast-path ─────────────────────────────────────────
        if dep_data.get("status") == "approved":
            return {"status": "already_approved", "deposit_id": deposit_id}

        if dep_data.get("status") != "awaiting_review":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Deposit is not in awaiting_review state (current: {dep_data.get('status')}).",
            )

        gateway = dep_data.get("gateway", "razorpay")
        payment_id = dep_data.get("razorpay_payment_id", "")
        order_id = dep_data.get("razorpay_order_id", "")
        signature = dep_data.get("razorpay_signature", "")

        # ── 3. Signature verification ─────────────────────────────────────────
        if gateway == "mock":
            # Mock gateway: explicitly skip signature verification.
            # This path is ONLY for testing — no real money involved.
            pass
        elif gateway == "razorpay":
            # Razorpay: HMAC-SHA256 signature verification is MANDATORY.
            # There is no code path that bypasses this for real Razorpay payments.
            if not RAZORPAY_KEY_SECRET:
                raise HTTPException(
                    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                    detail="Payment gateway is not configured on the server. Contact support.",
                )
            if not signature:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Payment verification failed: signature is missing.",
                )
            # Razorpay signature = HMAC-SHA256(order_id + "|" + payment_id, key_secret)
            expected = hmac.new(
                RAZORPAY_KEY_SECRET.encode("utf-8"),
                f"{order_id}|{payment_id}".encode("utf-8"),
                hashlib.sha256,
            ).hexdigest()
            if not hmac.compare_digest(expected, signature):
                # Verification failed — deposit stays in awaiting_review, no credit.
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Payment verification failed: signature mismatch.",
                )
        else:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Unsupported payment gateway: '{gateway}'.",
            )

        # ── 4. Approve and credit wallet ──────────────────────────────────────
        try:
            approved = WalletRepository.approve_deposit(
                deposit_id=deposit_id,
                reviewed_by="backend-verify",
            )
        except ValueError as exc:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc))

        if approved:
            return {"status": "approved", "deposit_id": deposit_id}
        else:
            return {"status": "already_approved", "deposit_id": deposit_id}
