from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime


# ── Sub-schemas ───────────────────────────────────────────────────────────────

class OrderItem(BaseModel):
    """A single item line inside an order."""
    name: str
    price: int
    quantity: int
    category: str


class TokenDocument(BaseModel):
    """
    Represents one token sub-document from Orders/{id}/tokens.
    Each counter (mess, bakery, beverages, continental) gets its own token.
    """
    token_id: str
    counter: str
    token_status: str                       # placed | preparing | ready_for_pickup | delivered | discarded
    token_number: int
    qr_valid: bool
    qr_code_data: str
    queue_name: Optional[str] = None
    queue_position: Optional[int] = None
    prep_units_in_queue: Optional[float] = None
    prep_start_time: Optional[str] = None
    prep_end_time: Optional[str] = None
    prep_duration_mins: Optional[float] = None
    prepared_at: Optional[str] = None
    collection_deadline: Optional[str] = None

    @classmethod
    def from_firestore(cls, doc_id: str, data: dict) -> "TokenDocument":
        def _ts(val) -> Optional[str]:
            return str(val) if val is not None else None

        return cls(
            token_id=doc_id,
            counter=data.get("counter", ""),
            token_status=data.get("token_status", "placed"),
            token_number=int(data.get("token_number", 0)),
            qr_valid=data.get("qr_valid", False),
            qr_code_data=data.get("qr_code_data", ""),
            queue_name=data.get("queue_name"),
            queue_position=data.get("queue_position"),
            prep_units_in_queue=data.get("prep_units_in_queue"),
            prep_start_time=_ts(data.get("prep_start_time")),
            prep_end_time=_ts(data.get("prep_end_time")),
            prep_duration_mins=data.get("prep_duration_mins"),
            prepared_at=_ts(data.get("prepared_at")),
            collection_deadline=_ts(data.get("collection_deadline")),
        )


class OrderSummary(BaseModel):
    """
    Lightweight order view for the list endpoint.
    Does NOT include the tokens subcollection — use OrderDetail for that.
    """
    order_id: str
    user_id: str
    user_name: Optional[str] = None
    items: list[OrderItem] = []
    total: int
    status: str                          # placed | preparing | ready_for_pickup | delivered | refund_pending | discarded | cancelled
    overall_status: str                  # active | completed | cancelled
    token_number: int
    payment_method: Optional[str] = None
    timestamp: Optional[str] = None
    prepare_requested_at: Optional[datetime] = None
    prepare_confirmation_deadline: Optional[datetime] = None
    preparation_confirmed_at: Optional[datetime] = None
    preparation_request_cancelled: Optional[bool] = None
    prepared_at: Optional[datetime] = None
    collection_deadline: Optional[datetime] = None

    @classmethod
    def from_firestore(cls, doc_id: str, data: dict) -> "OrderSummary":
        raw_items = data.get("items", [])
        items = [
            OrderItem(
                name=item.get("name", ""),
                price=int(item.get("price", 0)),
                quantity=int(item.get("quantity", 1)),
                category=item.get("category", "general"),
            )
            for item in raw_items
            if isinstance(item, dict)
        ]
        return cls(
            order_id=doc_id,
            user_id=data.get("userId", ""),
            user_name=data.get("userName") or data.get("user_name") or "Customer",
            items=items,
            total=int(data.get("total", 0)),
            status=data.get("status", "placed"),
            overall_status=data.get("overall_status", "active"),
            token_number=int(data.get("tokenNumber", 0)),
            payment_method=data.get("paymentMethod"),
            timestamp=str(data.get("timestamp")) if data.get("timestamp") else None,
            prepare_requested_at=data.get("prepare_requested_at"),
            prepare_confirmation_deadline=data.get("prepare_confirmation_deadline"),
            preparation_confirmed_at=data.get("preparation_confirmed_at"),
            preparation_request_cancelled=data.get("preparation_request_cancelled"),
            prepared_at=data.get("prepared_at"),
            collection_deadline=data.get("collection_deadline"),
        )


class OrderDetail(OrderSummary):
    """
    Full order view including all token sub-documents.
    Returned by GET /api/orders/{order_id}.
    """
    tokens: list[TokenDocument] = []


# ── Request payloads ──────────────────────────────────────────────────────────

class ManualOrderItem(BaseModel):
    """One item in a manually-placed admin order."""
    name: str = Field(..., min_length=1)
    price: int = Field(..., gt=0)
    quantity: int = Field(..., ge=1)
    category: str = Field(
        ...,
        description="mess | bakery | beverages | continental",
    )


class CreateManualOrderRequest(BaseModel):
    """
    Payload for POST /api/orders — admin places an order for an offline/walk-in customer.
    No Firebase user UID is required; the order is stored under userId='admin_placed'.
    payment_method covers cash, card, upi, or any offline mode.
    """
    items: list[ManualOrderItem] = Field(..., min_length=1)
    payment_method: str = Field(
        "cash",
        description="cash | card | upi",
    )


class UpdateOrderStatusRequest(BaseModel):
    """
    Payload for PATCH /api/orders/{order_id} — admin override of order status.
    Valid target statuses: delivered, refund_pending, cancelled.
    """
    status: str = Field(
        ...,
        description="Target status: delivered | refund_pending",
    )


# Valid Smart Preparation categories
SMART_PREP_CATEGORIES = {"mess", "continental"}


class StartPreparationRequest(BaseModel):
    """
    Payload for POST /api/orders/{order_id}/start-preparation.
    Specifies which Smart Preparation token/category to transition: placed → preparing.
    """
    category: str = Field(
        "mess",
        description="Smart Prep category: mess | continental",
    )


class MarkPreparedRequest(BaseModel):
    """
    Payload for POST /api/orders/{order_id}/mark-prepared.
    Specifies which Smart Preparation token/category to transition: preparing → ready_for_pickup.
    """
    category: str = Field(
        "mess",
        description="Smart Prep category: mess | continental",
    )


class CheckoutCartItem(BaseModel):
    """Item submitted for checkout orchestration."""
    menu_item_id: str = Field(..., description="Firestore Menu document ID")
    quantity: int = Field(..., ge=1, le=50, description="Quantity")


class CheckoutRequest(BaseModel):
    """
    Payload for POST /api/orders/checkout.
    Client submits ONLY menu item IDs and quantities. Prices and stock checks are
    performed strictly server-side.
    """
    items: list[CheckoutCartItem] = Field(..., min_length=1, max_length=50)
    payment_method: str = Field("wallet", description="wallet | direct | cash")
    user_name: Optional[str] = None


class CheckoutTokenDetail(BaseModel):
    """Token details created for a specific counter."""
    counter: str
    token_number: int
    qr_valid: bool


class CheckoutResponse(BaseModel):
    """Response returned upon successful atomic checkout."""
    order_id: str
    total: int
    token_number: int
    status: str
    payment_method: str
    tokens: list[CheckoutTokenDetail]


class ScanQrRequest(BaseModel):
    """Payload for POST /api/orders/scan-qr"""
    qr_payload: str = Field(..., min_length=1, description="Scanned QR code content")


class ScanQrResponse(BaseModel):
    """Response for QR scan"""
    order_id: str
    counter: str
    status: str
    requires_otp: bool
    message: str


class VerifyOtpRequest(BaseModel):
    """Payload for POST /api/orders/verify-otp"""
    order_id: str
    counter: str
    otp: str = Field(..., min_length=4, max_length=6)


class VerifyOtpResponse(BaseModel):
    """Response for OTP verification"""
    order_id: str
    counter: str
    status: str
    message: str


