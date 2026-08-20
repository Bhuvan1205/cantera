import hmac
import hashlib
import uuid
from typing import Optional
from fastapi import HTTPException, status

import json
from config.settings import RAZORPAY_KEY_SECRET, RAZORPAY_KEY_ID, RAZORPAY_WEBHOOK_SECRET
from .repository import WalletRepository
from .schemas import (
    CartItemRequest,
    CreateOrderResponse,
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
    def create_refund_request(
        user_uid: str,
        order_id: str,
        reason: Optional[str] = None,
    ) -> RefundRequestItem:
        return WalletRepository.create_refund_request(
            user_uid=user_uid,
            order_id=order_id,
            reason=reason,
        )

    @staticmethod
    def create_manual_adjustment(
        user_uid: str,
        amount: float,
        description: str,
        admin_uid: str,
    ) -> dict:
        return WalletRepository.create_manual_adjustment(
            user_uid=user_uid,
            amount=amount,
            description=description,
            admin_uid=admin_uid,
        )

    @staticmethod
    def get_wallet_investigation(uid: str) -> UserWalletInvestigation:
        return WalletRepository.get_wallet_investigation(uid)

    @staticmethod
    def handle_razorpay_webhook(body: bytes, signature: str) -> dict:
        """
        Secure webhook handler for Razorpay server-to-server events.
        Mitigates network drop issues by reconciling payments automatically.
        """
        if not RAZORPAY_WEBHOOK_SECRET:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Webhook secret not configured.",
            )
            
        if not signature:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Missing webhook signature.",
            )

        # 1. Verify Razorpay Webhook Signature
        expected_sig = hmac.new(
            RAZORPAY_WEBHOOK_SECRET.encode("utf-8"),
            body,
            hashlib.sha256,
        ).hexdigest()
        
        if not hmac.compare_digest(expected_sig, signature):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid webhook signature.",
            )

        # 2. Parse payload
        try:
            payload = json.loads(body)
        except json.JSONDecodeError:
            raise HTTPException(status_code=400, detail="Invalid JSON")

        event_type = payload.get("event")
        if event_type not in ("payment.captured", "payment.authorized"):
            return {"status": "ignored", "reason": "unhandled_event_type"}

        payment_entity = payload.get("payload", {}).get("payment", {}).get("entity", {})
        order_id = payment_entity.get("order_id")
        payment_id = payment_entity.get("id")

        if not order_id or not payment_id:
            return {"status": "ignored", "reason": "missing_identifiers"}

        # 3. Lookup pending deposit by order_id
        from config.firebase import db
        from google.cloud.firestore_v1.base_query import FieldFilter
        docs = db.collection("pending_deposits").where(filter=FieldFilter("razorpay_order_id", "==", order_id)).limit(1).stream()
        deposit_doc = next(docs, None)
        
        if not deposit_doc:
            return {"status": "ignored", "reason": "deposit_not_found"}
            
        deposit_id = deposit_doc.id
        dep_data = deposit_doc.to_dict() or {}

        # 4. Idempotency fast-path
        if dep_data.get("status") == "approved":
            return {"status": "already_approved", "deposit_id": deposit_id}

        # 5. Save verified metadata safely
        updates = {}
        if payment_id != dep_data.get("razorpay_payment_id"):
            updates["razorpay_payment_id"] = payment_id
        if updates:
            deposit_doc.reference.update(updates)

        # 6. Approve and credit wallet
        try:
            approved = WalletRepository.approve_deposit(
                deposit_id=deposit_id,
                reviewed_by="razorpay-webhook",
            )
        except ValueError as exc:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc))

        if approved:
            return {"status": "approved", "deposit_id": deposit_id}
        else:
            return {"status": "already_approved", "deposit_id": deposit_id}

    @staticmethod
    def verify_and_approve_deposit(
        deposit_id: str,
        user_uid: str,
        razorpay_payment_id: Optional[str] = None,
        razorpay_signature: Optional[str] = None
    ) -> dict:
        """
        Payment verification pipeline:
          1. Read deposit from Firestore — verify it exists and belongs to user_uid.
          2. Idempotency fast-path — if deposit is already 'approved', return success
             without touching any financial state.
          3. Save client-provided signature and payment ID to Firestore if provided.
          4. Signature verification:
             - Mock gateway: verification is explicitly skipped (test-only path).
             - Razorpay: HMAC-SHA256 signature is verified using Python stdlib
               hmac + hashlib. No Razorpay SDK is used.
               Signature verification for Razorpay is MANDATORY and cannot be bypassed.
               If RAZORPAY_KEY_SECRET is not configured, the endpoint returns HTTP 500.
               If the signature is invalid, the endpoint returns HTTP 400 and the
               deposit is left in 'awaiting_review' — no financial state is modified.
          5. Delegate to WalletRepository.approve_deposit() for atomic credit.

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

        # ── 3. Save client-provided Razorpay data to Firestore ─────────────────
        updates = {}
        if razorpay_payment_id and razorpay_payment_id != dep_data.get("razorpay_payment_id"):
            updates["razorpay_payment_id"] = razorpay_payment_id
        if razorpay_signature and razorpay_signature != dep_data.get("razorpay_signature"):
            updates["razorpay_signature"] = razorpay_signature
            
        if updates:
            db.collection("pending_deposits").document(deposit_id).update(updates)
            
        gateway = dep_data.get("gateway", "razorpay")
        payment_id = razorpay_payment_id or dep_data.get("razorpay_payment_id", "")
        order_id = dep_data.get("razorpay_order_id", "")
        signature = razorpay_signature or dep_data.get("razorpay_signature", "")

        # ── 4. Signature verification ─────────────────────────────────────────
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

    @staticmethod
    def _create_razorpay_order_internal(amount_paise: int, receipt: str, notes: dict) -> tuple[str, str]:
        """
        Internal helper to create a Razorpay order via SDK with mock fallback in dev.
        Returns (order_id, gateway_type) where gateway_type is 'razorpay' or 'mock'.
        """
        if RAZORPAY_KEY_SECRET and RAZORPAY_KEY_ID and not RAZORPAY_KEY_ID.startswith("rzp_test_PLACEHOLDER"):
            try:
                import razorpay
                client = razorpay.Client(auth=(RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET))
                order_data = {
                    "amount": amount_paise,
                    "currency": "INR",
                    "receipt": receipt,
                    "notes": notes,
                    "payment_capture": 1,
                }
                order = client.order.create(data=order_data)
                return order["id"], "razorpay"
            except Exception as exc:
                raise HTTPException(
                    status_code=status.HTTP_502_BAD_GATEWAY,
                    detail=f"Razorpay order creation failed: {str(exc)}",
                )
        else:
            # Fallback for dev / mock testing environments
            return f"order_mock_{uuid.uuid4().hex[:12]}", "mock"

    @staticmethod
    def create_deposit_order(user_uid: str, amount: float) -> CreateOrderResponse:
        """
        Creates a server-authorized Razorpay order for wallet top-up.
        Enforces min/max deposit bounds (₹20 - ₹500) and records pending deposit.
        Automatically selects 'mock' or 'razorpay' gateway based on execution mode.
        """
        from config.firebase import db
        from google.cloud import firestore

        if amount < 20.0 or amount > 500.0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Deposit amount must be between ₹20 and ₹500.",
            )

        # Enforce strict 2-decimal precision to prevent divergence with gateway
        amount = round(amount, 2)
        amount_paise = int(round(amount * 100))
        dep_id = f"dep_{uuid.uuid4().hex[:16]}"
        receipt_id = f"rcpt_{dep_id[:10]}"

        rzp_order_id, gateway = WalletService._create_razorpay_order_internal(
            amount_paise=amount_paise,
            receipt=receipt_id,
            notes={"deposit_id": dep_id, "user_uid": user_uid, "type": "wallet_deposit"},
        )

        # Store pending deposit record in Firestore with the detected gateway
        dep_ref = db.collection("pending_deposits").document(dep_id)
        dep_ref.set({
            "deposit_id": dep_id,
            "user_uid": user_uid,
            "amount": amount,
            "status": "awaiting_review",
            "gateway": gateway,
            "razorpay_order_id": rzp_order_id,
            "created_at": firestore.SERVER_TIMESTAMP,
        })

        return CreateOrderResponse(
            razorpay_order_id=rzp_order_id,
            amount_paise=amount_paise,
            amount_rupees=amount,
            currency="INR",
            key_id=RAZORPAY_KEY_ID,
            deposit_id=dep_id,
        )

    @staticmethod
    def create_cart_order(user_uid: str, items: list[CartItemRequest]) -> CreateOrderResponse:
        """
        Creates a server-authorized Razorpay order for cart checkout.
        Prices are calculated strictly server-side by fetching menu documents.
        """
        from config.firebase import db

        if not items:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Cart cannot be empty.",
            )

        total_paise = 0
        total_rupees = 0.0

        for item in items:
            menu_doc = db.collection("Menu").document(item.menu_item_id).get()
            if not menu_doc.exists:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail=f"Menu item '{item.menu_item_id}' not found.",
                )

            data = menu_doc.to_dict() or {}
            if not data.get("is_available", True):
                name = data.get("name", item.menu_item_id)
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Item '{name}' is currently out of stock.",
                )

            price = float(data.get("price", 0.0))
            if price <= 0:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Invalid price for item '{item.menu_item_id}'.",
                )

            item_total = price * item.quantity
            total_rupees += item_total
            total_paise += int(round(item_total * 100))

        if total_paise <= 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Total cart payable amount must be greater than zero.",
            )

        order_tracking_id = f"ord_rzp_{uuid.uuid4().hex[:12]}"
        receipt_id = f"rcpt_{order_tracking_id[:10]}"

        rzp_order_id, _ = WalletService._create_razorpay_order_internal(
            amount_paise=total_paise,
            receipt=receipt_id,
            notes={"user_uid": user_uid, "tracking_id": order_tracking_id, "type": "cart_checkout"},
        )

        return CreateOrderResponse(
            razorpay_order_id=rzp_order_id,
            amount_paise=total_paise,
            amount_rupees=round(total_rupees, 2),
            currency="INR",
            key_id=RAZORPAY_KEY_ID,
        )

