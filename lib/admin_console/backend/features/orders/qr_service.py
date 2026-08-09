import logging
from typing import Optional
from fastapi import HTTPException, status
from google.cloud import firestore

from config.firebase import db
from .schemas import (
    ScanQrResponse,
    VerifyOtpResponse,
)

logger = logging.getLogger("canteen-api.qr")


class QrService:
    """
    Business logic for QR code scanning and OTP verification (P-07).
    Staff/Admin authorized endpoint to process student tokens.
    """

    @staticmethod
    def process_qr_scan(staff_uid: str, qr_payload: str) -> ScanQrResponse:
        trimmed = qr_payload.strip()
        order_id = ""
        counter_or_token = ""

        if "::" in trimmed:
            parts = trimmed.split("::")
            order_id, counter_or_token = parts[0], parts[1]
        elif ":" in trimmed:
            parts = trimmed.split(":")
            order_id = parts[0]
            counter_or_token = parts[1] if len(parts) > 1 else "general"
        else:
            order_id = trimmed
            counter_or_token = "general"

        order_ref = db.collection("Orders").document(order_id)
        token_ref = order_ref.collection("tokens").document(counter_or_token)

        # Batched read: fetch order doc and candidate token doc in a single RPC
        order_snap, token_snap = db.get_all([order_ref, token_ref])

        if not order_snap.exists:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Order '{order_id}' not found.",
            )

        # Resolve the correct token doc (direct, query, or fallback)
        target_token_ref = token_ref
        target_token_data = {}
        if token_snap.exists:
            target_token_data = token_snap.to_dict() or {}
        else:
            query = order_ref.collection("tokens").where("counter", "==", counter_or_token.lower()).limit(1).stream()
            matching_docs = list(query)
            if matching_docs:
                target_token_ref = matching_docs[0].reference
                target_token_data = matching_docs[0].to_dict() or {}
            else:
                all_tokens = list(order_ref.collection("tokens").stream())
                if len(all_tokens) == 1:
                    target_token_ref = all_tokens[0].reference
                    target_token_data = all_tokens[0].to_dict() or {}
                else:
                    raise HTTPException(
                        status_code=status.HTTP_404_NOT_FOUND,
                        detail=f"Token '{counter_or_token}' not found for order '{order_id}'.",
                    )

        counter = str(target_token_data.get("counter", "general")).lower()
        token_status = str(target_token_data.get("token_status", "placed")).lower()
        qr_valid = bool(target_token_data.get("qr_valid", True))

        if token_status == "delivered":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="This token has already been delivered.",
            )

        if not qr_valid and token_status != "placed":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="This QR code has already been consumed.",
            )

        if counter == "mess":
            # Mess: single batched write — update token + update order status
            batch = db.batch()
            batch.update(target_token_ref, {
                "token_status": "preparing",
                "qr_valid": False,
                "scanned_by": staff_uid,
                "scanned_at": firestore.SERVER_TIMESTAMP,
            })
            batch.update(order_ref, {"status": "preparing"})
            batch.commit()
            return ScanQrResponse(
                order_id=order_id,
                counter=counter,
                status="preparing",
                requires_otp=True,
                message="Mess order scanned. Preparing meal; enter OTP to complete delivery.",
            )
        else:
            # Direct counter: mark token delivered, then check if all tokens delivered
            # Read all sibling tokens (needed to determine order-level completion)
            all_tokens = list(order_ref.collection("tokens").stream())
            all_delivered = all(
                (t.id == target_token_ref.id or t.to_dict().get("token_status") == "delivered")
                for t in all_tokens
            )

            # Single batched write commit
            batch = db.batch()
            batch.update(target_token_ref, {
                "token_status": "delivered",
                "qr_valid": False,
                "scanned_by": staff_uid,
                "delivered_at": firestore.SERVER_TIMESTAMP,
            })
            if all_delivered:
                batch.update(order_ref, {
                    "status": "delivered",
                    "overall_status": "completed",
                })
            batch.commit()

            return ScanQrResponse(
                order_id=order_id,
                counter=counter,
                status="delivered",
                requires_otp=False,
                message=f"Counter '{counter}' order successfully delivered.",
            )

    @staticmethod
    def verify_otp(staff_uid: str, order_id: str, counter: str, otp: str) -> VerifyOtpResponse:
        order_ref = db.collection("Orders").document(order_id)
        token_ref = order_ref.collection("tokens").document(counter)
        token_snap = token_ref.get()

        if not token_snap.exists:
            # Fallback search by counter field
            query = order_ref.collection("tokens").where("counter", "==", counter.lower()).limit(1).stream()
            matching = list(query)
            if matching:
                token_ref = matching[0].reference
                token_snap = matching[0]
            else:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail=f"Token for counter '{counter}' not found.",
                )

        token_data = token_snap.to_dict() or {}
        expected_otp = str(token_data.get("otp", "")).strip()

        if not expected_otp or expected_otp != otp.strip():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid OTP. Please check with the student.",
            )

        # Read all sibling tokens to determine order completion
        all_tokens = list(order_ref.collection("tokens").stream())
        all_delivered = all(
            (t.id == token_ref.id or t.to_dict().get("token_status") == "delivered")
            for t in all_tokens
        )

        # Single batched commit: token update + optional order completion
        batch = db.batch()
        batch.update(token_ref, {
            "token_status": "delivered",
            "otp_verified": True,
            "verified_by": staff_uid,
            "delivered_at": firestore.SERVER_TIMESTAMP,
        })
        if all_delivered:
            batch.update(order_ref, {
                "status": "delivered",
                "overall_status": "completed",
            })
        batch.commit()

        return VerifyOtpResponse(
            order_id=order_id,
            counter=counter,
            status="delivered",
            message="OTP verified successfully. Order marked as delivered.",
        )
