from typing import Optional
from fastapi import HTTPException, status

from .repository import OrderRepository
from .schemas import (
    OrderSummary,
    OrderDetail,
    TokenDocument,
    CreateManualOrderRequest,
    UpdateOrderStatusRequest,
)

VALID_STATUSES = {"placed", "preparing", "delivered", "refund_pending", "cancelled"}


class OrderService:
    """
    Business logic layer for the Orders feature.
    """

    @staticmethod
    def list_orders(
        status_filter: Optional[str] = None,
        limit: int = 50,
    ) -> list[OrderSummary]:
        return OrderRepository.list_orders(status_filter=status_filter, limit=limit)

    @staticmethod
    def get_order(order_id: str) -> OrderDetail:
        order = OrderRepository.get_order_by_id(order_id)
        if order is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Order '{order_id}' not found.",
            )
        return order

    @staticmethod
    def get_order_tokens(order_id: str) -> list[TokenDocument]:
        # Check that the order exists first
        order = OrderRepository.get_order_by_id(order_id)
        if order is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Order '{order_id}' not found.",
            )
        return OrderRepository.get_tokens_for_order(order_id)

    @staticmethod
    def create_manual_order(payload: CreateManualOrderRequest) -> OrderDetail:
        if not payload.items:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Order must contain at least one item.",
            )
        return OrderRepository.create_manual_order(payload)

    @staticmethod
    def update_order_status(
        order_id: str,
        payload: UpdateOrderStatusRequest,
    ) -> OrderDetail:
        target_status = payload.status.lower().strip()
        if target_status not in VALID_STATUSES:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Invalid status '{payload.status}'. Valid statuses: {', '.join(sorted(VALID_STATUSES))}",
            )

        updated = OrderRepository.update_order_status(order_id, target_status)
        if updated is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Order '{order_id}' not found.",
            )
        return updated
