from typing import Optional
from fastapi import APIRouter, Depends, Query

from auth.dependencies import get_current_admin, get_current_user, get_current_staff_or_admin
from config.logging import log_audit
from .schemas import (
    OrderSummary,
    OrderDetail,
    TokenDocument,
    CreateManualOrderRequest,
    UpdateOrderStatusRequest,
    CheckoutRequest,
    CheckoutResponse,
    ScanQrRequest,
    ScanQrResponse,
    VerifyOtpRequest,
    VerifyOtpResponse,
)
from .service import OrderService
from .checkout_service import CheckoutService
from .qr_service import QrService

router = APIRouter()






@router.get(
    "/",
    response_model=list[OrderSummary],
    summary="List all orders",
    description="Returns orders sorted by timestamp descending. Optionally filter by status (placed, preparing, delivered, refund_pending).",
)
def list_orders(
    status: Optional[str] = Query(None, description="Optional status filter"),
    limit: int = Query(50, ge=1, le=200, description="Max orders to return"),
    _admin: dict = Depends(get_current_admin),
) -> list[OrderSummary]:
    return OrderService.list_orders(status_filter=status, limit=limit)


@router.get(
    "/{order_id}",
    response_model=OrderDetail,
    summary="Get order detail with tokens",
    description="Returns the full order document including all per-counter token sub-documents.",
)
def get_order(
    order_id: str,
    _admin: dict = Depends(get_current_admin),
) -> OrderDetail:
    return OrderService.get_order(order_id)


@router.get(
    "/{order_id}/tokens",
    response_model=list[TokenDocument],
    summary="Get tokens for an order",
    description="Returns all token sub-documents for the specified order.",
)
def get_order_tokens(
    order_id: str,
    _admin: dict = Depends(get_current_admin),
) -> list[TokenDocument]:
    return OrderService.get_order_tokens(order_id)


@router.post(
    "/",
    response_model=OrderDetail,
    status_code=201,
    summary="Create manual order (offline/walk-in customer)",
    description=(
        "Manually creates an order on behalf of an offline customer paying via cash, card, or UPI. "
        "Generates counter tokens, registers mess items into queues, and decrements stock."
    ),
)
def create_manual_order(
    payload: CreateManualOrderRequest,
    _admin: dict = Depends(get_current_admin),
) -> OrderDetail:
    return OrderService.create_manual_order(payload)


@router.patch(
    "/{order_id}",
    response_model=OrderDetail,
    summary="Update order status (admin override)",
    description="Allows the admin to override order status (e.g. mark delivered, set refund_pending).",
)
def update_order_status(
    order_id: str,
    payload: UpdateOrderStatusRequest,
    _admin: dict = Depends(get_current_admin),
) -> OrderDetail:
    return OrderService.update_order_status(order_id, payload)


@router.post(
    "/checkout",
    response_model=CheckoutResponse,
    status_code=201,
    summary="Server-side atomic checkout orchestration",
    description="Validates cart, reserves inventory, debits wallet (if applicable), allocates scoped tokens, and creates the order.",
)
def checkout(
    payload: CheckoutRequest,
    user: dict = Depends(get_current_user),
) -> CheckoutResponse:
    res = CheckoutService.execute_checkout(
        user_uid=user["uid"],
        payload=payload,
        actor_email=user.get("email"),
    )
    log_audit(
        action="ORDER_CHECKOUT_COMPLETED",
        actor_uid=user["uid"],
        target=f"Orders/{res.order_id}",
        details={"total": res.total, "payment_method": res.payment_method, "token": res.token_number},
    )
    return res


@router.post(
    "/scan-qr",
    response_model=ScanQrResponse,
    summary="Process staff QR scan",
    description="Staff/admin scans customer token QR code. Updates token status to preparing or delivered.",
)
def scan_qr(
    payload: ScanQrRequest,
    user: dict = Depends(get_current_staff_or_admin),
) -> ScanQrResponse:
    res = QrService.process_qr_scan(
        staff_uid=user["uid"],
        qr_payload=payload.qr_payload,
    )
    log_audit(
        action="QR_CODE_SCANNED",
        actor_uid=user["uid"],
        target=f"Orders/{res.order_id}/tokens/{res.counter}",
        details={"status": res.status, "requires_otp": res.requires_otp},
    )
    return res


@router.post(
    "/verify-otp",
    response_model=VerifyOtpResponse,
    summary="Verify student mess OTP",
    description="Validates the student mess counter PIN/OTP and marks meal as delivered.",
)
def verify_otp(
    payload: VerifyOtpRequest,
    user: dict = Depends(get_current_staff_or_admin),
) -> VerifyOtpResponse:
    res = QrService.verify_otp(
        staff_uid=user["uid"],
        order_id=payload.order_id,
        counter=payload.counter,
        otp=payload.otp,
    )
    log_audit(
        action="MESS_OTP_VERIFIED",
        actor_uid=user["uid"],
        target=f"Orders/{res.order_id}/tokens/{res.counter}",
        details={"status": res.status},
    )
    return res


@router.post(
    "/{order_id}/cancel",
    response_model=OrderDetail,
    summary="Cancel order",
    description="Cancels an order in 'placed' status, restores inventory, and auto-refunds wallet if applicable.",
)
def cancel_order(
    order_id: str,
    user: dict = Depends(get_current_user),
) -> OrderDetail:
    is_admin = user.get("isAdmin", False) or user.get("role") == "admin" or user.get("admin") is True
    res = OrderService.cancel_order(order_id=order_id, caller_uid=user["uid"], is_admin=is_admin)
    log_audit(
        action="ORDER_CANCELLED",
        actor_uid=user["uid"],
        target=f"Orders/{order_id}",
        details={"status": "cancelled", "total": res.total},
    )
    return res



