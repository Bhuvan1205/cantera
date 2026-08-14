from typing import Optional
from fastapi import HTTPException, status
from datetime import datetime, timezone

from .repository import OrderRepository
from .schemas import (
    OrderSummary,
    OrderDetail,
    TokenDocument,
    CreateManualOrderRequest,
    UpdateOrderStatusRequest,
    SMART_PREP_CATEGORIES,
)

VALID_STATUSES = {"placed", "preparing", "ready_for_pickup", "delivered", "refund_pending", "cancelled", "discarded"}


class OrderService:
    """
    Business logic layer for the Orders feature.
    """

    @staticmethod
    def start_preparation(order_id: str, user_uid: str, category: str) -> OrderDetail:
        # Validate category
        category = category.lower().strip()
        if category not in SMART_PREP_CATEGORIES:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Category '{category}' is not eligible for Smart Preparation. "
                       f"Valid categories: {', '.join(sorted(SMART_PREP_CATEGORIES))}.",
            )

        order = OrderRepository.get_order_by_id(order_id)
        if order is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Order '{order_id}' not found.",
            )

        if order.user_id != user_uid:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You do not have permission to access this order.",
            )

        # Verify the requested category token exists in the order
        target_token = next((t for t in order.tokens if t.token_id == category), None)
        if target_token is None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"This order does not contain a '{category}' token.",
            )

        # Idempotency: already preparing
        if target_token.token_status == "preparing":
            return order

        # Block terminal states
        terminal_states = {"delivered", "discarded", "cancelled", "ready_for_pickup"}
        if target_token.token_status in terminal_states:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Cannot start preparation: '{category}' token is in "
                       f"'{target_token.token_status}' state.",
            )

        if order.overall_status != "active":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Cannot start preparation: order is not active "
                       f"(overall_status='{order.overall_status}').",
            )

        return OrderRepository.start_preparation(order_id, category)

    @staticmethod
    def mark_prepared(order_id: str, staff_uid: str, category: str) -> OrderDetail:
        # Validate category
        category = category.lower().strip()
        if category not in SMART_PREP_CATEGORIES:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Category '{category}' is not eligible for Smart Preparation. "
                       f"Valid categories: {', '.join(sorted(SMART_PREP_CATEGORIES))}.",
            )

        order = OrderRepository.get_order_by_id(order_id)
        if order is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Order '{order_id}' not found.",
            )

        # Verify the requested category token exists
        target_token = next((t for t in order.tokens if t.token_id == category), None)
        if target_token is None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Order does not have a '{category}' token.",
            )

        # Idempotency: already ready
        if target_token.token_status == "ready_for_pickup":
            return order

        if target_token.token_status != "preparing":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Order does not have a '{category}' token in 'preparing' state "
                       f"(current: '{target_token.token_status}').",
            )

        return OrderRepository.mark_prepared(order_id, category, staff_uid)

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

    @staticmethod
    def cancel_order(order_id: str, caller_uid: str, is_admin: bool = False) -> OrderDetail:
        return OrderRepository.cancel_order(order_id=order_id, caller_uid=caller_uid, is_admin=is_admin)

