from typing import Optional
from fastapi import APIRouter, Depends, Query

from auth.dependencies import get_current_admin, get_current_user
from config.logging import log_audit
from .schemas import (
    CartItemRequest,
    CreateCartOrderRequest,
    CreateDepositOrderRequest,
    CreateOrderResponse,
    PendingDepositItem,
    RefundRequestItem,
    UpdateRefundStatusRequest,
    UserWalletInvestigation,
    VerifyDepositRequest,
    CreateRefundRequestPayload,
    CreateAdjustmentRequest,
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
    res = WalletService.verify_and_approve_deposit(
        deposit_id=payload.deposit_id,
        user_uid=user["uid"],
    )
    log_audit(
        action="WALLET_DEPOSIT_VERIFIED",
        actor_uid=user["uid"],
        target=f"pending_deposits/{payload.deposit_id}",
        details={"status": res.get("status"), "credited_amount": res.get("credited_amount")},
    )
    return res


@router.post(
    "/orders/deposit",
    response_model=CreateOrderResponse,
    summary="Create server-side Razorpay order for wallet top-up",
    description="Validates deposit amount constraints and creates a server-authorized Razorpay order.",
)
def create_deposit_order(
    payload: CreateDepositOrderRequest,
    user: dict = Depends(get_current_user),
) -> CreateOrderResponse:
    res = WalletService.create_deposit_order(
        user_uid=user["uid"],
        amount=payload.amount,
    )
    log_audit(
        action="WALLET_DEPOSIT_ORDER_CREATED",
        actor_uid=user["uid"],
        target=f"pending_deposits/{res.deposit_id}",
        details={"amount": payload.amount, "razorpay_order_id": res.razorpay_order_id},
    )
    return res


@router.post(
    "/orders/checkout",
    response_model=CreateOrderResponse,
    summary="Create server-side Razorpay order for cart checkout",
    description="Resolves item prices securely from Firestore Menu and generates a server-authorized Razorpay order.",
)
def create_cart_order(
    payload: CreateCartOrderRequest,
    user: dict = Depends(get_current_user),
) -> CreateOrderResponse:
    res = WalletService.create_cart_order(
        user_uid=user["uid"],
        items=payload.items,
    )
    log_audit(
        action="CART_PAYMENT_ORDER_CREATED",
        actor_uid=user["uid"],
        target=f"razorpay_orders/{res.razorpay_order_id}",
        details={"amount_rupees": res.amount_rupees, "item_count": len(payload.items)},
    )
    return res


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
    res = WalletService.update_refund_status(
        refund_id=refund_id,
        payload=payload,
        admin_uid=admin["uid"],
    )
    log_audit(
        action=f"WALLET_REFUND_{payload.status.upper()}",
        actor_uid=admin.get("uid", "unknown"),
        target=f"refund_requests/{refund_id}",
        details={"status": payload.status, "reason": payload.reason},
    )
    return res


@router.post(
    "/refunds/request",
    response_model=RefundRequestItem,
    status_code=201,
    summary="User-initiated refund request",
    description="Submits a refund request for an order in 'placed' status. Amount is resolved securely from the server-side order document.",
)
def create_refund_request(
    payload: CreateRefundRequestPayload,
    user: dict = Depends(get_current_user),
) -> RefundRequestItem:
    res = WalletService.create_refund_request(
        user_uid=user["uid"],
        order_id=payload.order_id,
        reason=payload.reason,
    )
    log_audit(
        action="WALLET_REFUND_REQUESTED",
        actor_uid=user["uid"],
        target=f"refund_requests/{res.request_id}",
        details={"order_id": payload.order_id, "amount": res.amount},
    )
    return res


@router.post(
    "/adjustments",
    summary="Admin manual wallet adjustment",
    description="Executes an atomic credit or debit adjustment on a user's wallet with ledger audit record.",
)
def create_manual_adjustment(
    payload: CreateAdjustmentRequest,
    admin: dict = Depends(get_current_admin),
) -> dict:
    res = WalletService.create_manual_adjustment(
        user_uid=payload.user_uid,
        amount=payload.amount,
        description=payload.description,
        admin_uid=admin["uid"],
    )
    log_audit(
        action="WALLET_ADJUSTMENT_EXECUTED",
        actor_uid=admin["uid"],
        target=f"wallets/{payload.user_uid}",
        details={"amount": payload.amount, "description": payload.description},
    )
    return res


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

