from typing import Optional
from fastapi import APIRouter, Depends, Query

from auth.dependencies import get_current_admin, get_current_user
from .schemas import (
    PendingDepositItem,
    RefundRequestItem,
    UpdateRefundStatusRequest,
    UserWalletInvestigation,
    VerifyDepositRequest,
)
from .service import WalletService

router = APIRouter()


@router.get(
    "/deposits",
    response_model=list[PendingDepositItem],
    summary="List deposit records",
    description="Returns deposit records. Optionally filter by status (awaiting_review, approved, rejected).",
)
def list_deposits(
    status: Optional[str] = Query(None, description="Filter by status: awaiting_review | approved | rejected"),
    limit: int = Query(50, ge=1, le=200),
    _admin: dict = Depends(get_current_admin),
) -> list[PendingDepositItem]:
    return WalletService.list_deposits(status_filter=status, limit=limit)


@router.post(
    "/deposits/verify",
    summary="Verify payment and credit wallet",
    description=(
        "Called by the Flutter app after a successful payment gateway callback. "
        "Verifies the payment signature (Razorpay: HMAC-SHA256; Mock: skipped), "
        "then atomically credits the wallet. Idempotent — safe to retry."
    ),
)
def verify_deposit(
    payload: VerifyDepositRequest,
    user: dict = Depends(get_current_user),
) -> dict:
    return WalletService.verify_and_approve_deposit(
        deposit_id=payload.deposit_id,
        user_uid=user["uid"],
    )


@router.get(
    "/refunds",
    response_model=list[RefundRequestItem],
    summary="List refund requests",
    description="Returns refund requests. Optionally filter by status (refund_requested, refund_under_review, approved, credited, rejected).",
)
def list_refunds(
    status: Optional[str] = Query(None, description="Filter by status: refund_requested | refund_under_review | approved | credited | rejected"),
    limit: int = Query(50, ge=1, le=200),
    _admin: dict = Depends(get_current_admin),
) -> list[RefundRequestItem]:
    return WalletService.list_refunds(status_filter=status, limit=limit)


@router.get(
    "/refunds/{refund_id}",
    response_model=RefundRequestItem,
    summary="Get single refund request",
)
def get_refund(
    refund_id: str,
    _admin: dict = Depends(get_current_admin),
) -> RefundRequestItem:
    return WalletService.get_refund(refund_id)


@router.patch(
    "/refunds/{refund_id}",
    response_model=RefundRequestItem,
    summary="Update refund request status (review / approve / credit / reject)",
    description=(
        "Admin actions on a refund request. Marking as 'approved' or 'credited' automatically "
        "credits the user's wallet, creates a wallet_transactions entry, and marks the associated order as refunded."
    ),
)
def update_refund_status(
    refund_id: str,
    payload: UpdateRefundStatusRequest,
    admin: dict = Depends(get_current_admin),
) -> RefundRequestItem:
    return WalletService.update_refund_status(
        refund_id=refund_id,
        payload=payload,
        admin_uid=admin["uid"],
    )


@router.get(
    "/{uid}",
    response_model=UserWalletInvestigation,
    summary="Get comprehensive wallet data for user investigation",
    description="Returns wallet balance, full transaction ledger, pending deposits, and refund requests for a specific user.",
)
def get_wallet_investigation(
    uid: str,
    _admin: dict = Depends(get_current_admin),
) -> UserWalletInvestigation:
    return WalletService.get_wallet_investigation(uid)
