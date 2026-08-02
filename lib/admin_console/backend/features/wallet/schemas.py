from typing import Optional
from pydantic import BaseModel, Field


class PendingDepositItem(BaseModel):
    """Represents a deposit document from pending_deposits collection."""
    deposit_id: str
    user_uid: str
    amount: float
    status: str                         # awaiting_review | approved | rejected
    razorpay_payment_id: Optional[str] = None
    razorpay_order_id: Optional[str] = None
    gateway: Optional[str] = None
    created_at: Optional[str] = None
    reviewed_at: Optional[str] = None
    reviewed_by: Optional[str] = None
    reject_reason: Optional[str] = None

    @classmethod
    def from_firestore(cls, doc_id: str, data: dict) -> "PendingDepositItem":
        def _ts(v):
            return str(v) if v is not None else None

        return cls(
            deposit_id=doc_id,
            user_uid=data.get("user_uid", data.get("userId", "")),
            amount=float(data.get("amount", 0.0)),
            status=data.get("status", "awaiting_review"),
            razorpay_payment_id=data.get("razorpay_payment_id"),
            razorpay_order_id=data.get("razorpay_order_id"),
            gateway=data.get("gateway"),
            created_at=_ts(data.get("created_at") or data.get("timestamp")),
            reviewed_at=_ts(data.get("reviewed_at")),
            reviewed_by=data.get("reviewed_by"),
            reject_reason=data.get("reject_reason"),
        )


class RefundRequestItem(BaseModel):
    """Represents a refund request document from refund_requests collection."""
    request_id: str
    user_uid: str
    order_id: str
    amount: float
    status: str                         # refund_requested | refund_under_review | approved | credited | rejected
    reason: Optional[str] = None
    created_at: Optional[str] = None
    reviewed_at: Optional[str] = None
    reviewed_by: Optional[str] = None
    reject_reason: Optional[str] = None

    @classmethod
    def from_firestore(cls, doc_id: str, data: dict) -> "RefundRequestItem":
        def _ts(v):
            return str(v) if v is not None else None

        return cls(
            request_id=doc_id,
            user_uid=data.get("user_uid", data.get("userId", "")),
            order_id=data.get("order_id", data.get("orderId", "")),
            amount=float(data.get("amount", 0.0)),
            status=data.get("status", "refund_requested"),
            reason=data.get("reason"),
            created_at=_ts(data.get("created_at") or data.get("timestamp")),
            reviewed_at=_ts(data.get("reviewed_at")),
            reviewed_by=data.get("reviewed_by"),
            reject_reason=data.get("reject_reason"),
        )


class UpdateRefundStatusRequest(BaseModel):
    """
    Payload for PATCH /api/wallet/refunds/{refund_id}.
    Target status transitions:
      - 'refund_under_review' (review started)
      - 'approved' / 'credited' (refund approved & balance credited)
      - 'rejected' (refund denied)
    """
    status: str = Field(
        ...,
        description="Target status: refund_under_review | approved | credited | rejected",
    )
    reason: Optional[str] = Field(
        None,
        description="Optional reason (especially relevant when rejecting)",
    )


class UserWalletInvestigation(BaseModel):
    """
    Detailed wallet investigation model for suspicious activity checks.
    """
    user_uid: str
    balance: float
    total_added: float
    total_spent: float
    transactions: list[dict] = []
    pending_deposits: list[PendingDepositItem] = []
    refund_requests: list[RefundRequestItem] = []


class VerifyDepositRequest(BaseModel):
    """
    Payload for POST /api/wallet/deposits/verify.

    The client sends only the deposit_id after a successful payment SDK callback.
    The backend reads the full deposit from Firestore (gateway, payment_id,
    signature, amount) and the user identity comes from the Firebase ID token —
    no financial data is trusted from the client body.
    """
    deposit_id: str = Field(..., description="Firestore document ID from pending_deposits collection")
