from typing import Optional
from fastapi import APIRouter, Depends, Query

from auth.dependencies import get_current_admin
from .schemas import (
    OrderSummary,
    OrderDetail,
    TokenDocument,
    CreateManualOrderRequest,
    UpdateOrderStatusRequest,
)
from .service import OrderService

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
