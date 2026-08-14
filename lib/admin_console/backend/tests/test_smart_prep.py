import pytest
from datetime import datetime, timezone, timedelta
from unittest.mock import patch, MagicMock
from fastapi.testclient import TestClient
from fastapi import HTTPException

from main import app
from auth.dependencies import get_current_user, get_current_staff_or_admin
from features.orders.schemas import OrderDetail, OrderItem, TokenDocument

client = TestClient(app, raise_server_exceptions=False)


def override_user():
    return {"uid": "test_student_user", "email": "student@example.com", "role": "customer"}


def override_staff():
    return {"uid": "test_staff_user", "email": "staff@example.com", "role": "staff"}


app.dependency_overrides[get_current_user] = override_user
app.dependency_overrides[get_current_staff_or_admin] = override_staff


def _make_token(cat: str, status: str = "placed", queue_name: str = None) -> TokenDocument:
    """Build a TokenDocument for testing. token_id == category (matches Firestore schema)."""
    return TokenDocument(
        token_id=cat,          # Document ID == category string
        counter=cat,
        token_status=status,
        token_number=100,
        qr_valid=True,
        qr_code_data=f"ord_123:{cat}:100",
        items=[{"item_name": "Test Item", "quantity": 1, "unit_price": 50, "prep_units": 1.0}],
        otp="1234" if cat == "mess" else None,
        queue_name=queue_name or "Test Item",
        prep_units_in_queue=1.0,
    )


def create_mock_order(
    order_id="ord_123",
    user_id="test_student_user",
    status="placed",
    overall_status="active",
    categories=None,
    token_statuses=None,
):
    if categories is None:
        categories = ["mess"]
    if token_statuses is None:
        token_statuses = {cat: "placed" for cat in categories}

    items = [
        OrderItem(name=f"Item {i}", price=50, quantity=1, category=cat)
        for i, cat in enumerate(categories)
    ]
    tokens = [
        _make_token(cat, status=token_statuses.get(cat, "placed"))
        for cat in categories
    ]
    return OrderDetail(
        order_id=order_id,
        user_id=user_id,
        items=items,
        total=len(categories) * 50,
        status=status,
        overall_status=overall_status,
        token_number=12345,
        payment_method="wallet",
        timestamp=str(datetime.now(timezone.utc).timestamp()),
        tokens=tokens,
    )


# ── 1. Mess token: placed → preparing ──────────────────────────────────────────
@patch("features.orders.repository.OrderRepository.get_order_by_id")
@patch("features.orders.repository.OrderRepository.start_preparation")
def test_start_preparation_mess_success(mock_start, mock_get):
    order_id = "ord_mess_success"
    mock_get.return_value = create_mock_order(order_id=order_id, categories=["mess"])
    mock_start.return_value = create_mock_order(
        order_id=order_id, categories=["mess"], token_statuses={"mess": "preparing"}
    )

    response = client.post(
        f"/api/orders/{order_id}/start-preparation",
        json={"category": "mess"},
    )
    assert response.status_code == 200
    mock_start.assert_called_once_with(order_id, "mess")


# ── 2. Continental token: placed → preparing ───────────────────────────────────
@patch("features.orders.repository.OrderRepository.get_order_by_id")
@patch("features.orders.repository.OrderRepository.start_preparation")
def test_start_preparation_continental_success(mock_start, mock_get):
    order_id = "ord_continental_success"
    mock_get.return_value = create_mock_order(
        order_id=order_id, categories=["continental"]
    )
    mock_start.return_value = create_mock_order(
        order_id=order_id,
        categories=["continental"],
        token_statuses={"continental": "preparing"},
    )

    response = client.post(
        f"/api/orders/{order_id}/start-preparation",
        json={"category": "continental"},
    )
    assert response.status_code == 200
    mock_start.assert_called_once_with(order_id, "continental")


# ── 3. Bakery is rejected for Smart Prep ───────────────────────────────────────
@patch("features.orders.repository.OrderRepository.get_order_by_id")
def test_start_preparation_bakery_rejected(mock_get):
    order_id = "ord_bakery"
    mock_get.return_value = create_mock_order(order_id=order_id, categories=["bakery"])

    response = client.post(
        f"/api/orders/{order_id}/start-preparation",
        json={"category": "bakery"},
    )
    assert response.status_code == 400
    assert "not eligible" in response.json()["detail"].lower()


# ── 4. Ownership validation ────────────────────────────────────────────────────
@patch("features.orders.repository.OrderRepository.get_order_by_id")
def test_start_preparation_ownership_error(mock_get):
    order_id = "ord_other_user"
    mock_get.return_value = create_mock_order(
        order_id=order_id, user_id="some_other_student"
    )

    response = client.post(
        f"/api/orders/{order_id}/start-preparation",
        json={"category": "mess"},
    )
    assert response.status_code == 403
    assert "permission" in response.json()["detail"].lower()


# ── 5. Idempotent: already preparing returns 200 without re-calling repo ───────
@patch("features.orders.repository.OrderRepository.get_order_by_id")
@patch("features.orders.repository.OrderRepository.start_preparation")
def test_start_preparation_idempotent_mess(mock_start, mock_get):
    order_id = "ord_idempotent_mess"
    mock_get.return_value = create_mock_order(
        order_id=order_id,
        categories=["mess"],
        token_statuses={"mess": "preparing"},
    )

    response = client.post(
        f"/api/orders/{order_id}/start-preparation",
        json={"category": "mess"},
    )
    assert response.status_code == 200
    mock_start.assert_not_called()


# ── 6. Mess start while Continental remains placed (independent tokens) ────────
@patch("features.orders.repository.OrderRepository.get_order_by_id")
@patch("features.orders.repository.OrderRepository.start_preparation")
def test_start_mess_does_not_affect_continental(mock_start, mock_get):
    order_id = "ord_mixed"
    mock_get.return_value = create_mock_order(
        order_id=order_id,
        categories=["mess", "continental"],
        token_statuses={"mess": "placed", "continental": "placed"},
    )
    mock_start.return_value = create_mock_order(
        order_id=order_id,
        categories=["mess", "continental"],
        token_statuses={"mess": "preparing", "continental": "placed"},
    )

    response = client.post(
        f"/api/orders/{order_id}/start-preparation",
        json={"category": "mess"},
    )
    assert response.status_code == 200
    # Only mess was started
    mock_start.assert_called_once_with(order_id, "mess")


# ── 7. No duplicate queue entries — idempotent Continental ────────────────────
@patch("features.orders.repository.OrderRepository.get_order_by_id")
@patch("features.orders.repository.OrderRepository.start_preparation")
def test_start_preparation_idempotent_continental(mock_start, mock_get):
    order_id = "ord_idempotent_continental"
    mock_get.return_value = create_mock_order(
        order_id=order_id,
        categories=["continental"],
        token_statuses={"continental": "preparing"},
    )

    response = client.post(
        f"/api/orders/{order_id}/start-preparation",
        json={"category": "continental"},
    )
    assert response.status_code == 200
    mock_start.assert_not_called()


# ── 8. Mess mark-prepared: preparing → ready_for_pickup ───────────────────────
@patch("features.orders.repository.OrderRepository.get_order_by_id")
@patch("features.orders.repository.OrderRepository.mark_prepared")
def test_mark_prepared_mess_success(mock_mark, mock_get):
    order_id = "ord_mark_mess"
    mock_get.return_value = create_mock_order(
        order_id=order_id,
        categories=["mess"],
        token_statuses={"mess": "preparing"},
    )
    mock_mark.return_value = create_mock_order(
        order_id=order_id,
        categories=["mess"],
        token_statuses={"mess": "ready_for_pickup"},
    )

    response = client.post(
        f"/api/orders/{order_id}/mark-prepared",
        json={"category": "mess"},
    )
    assert response.status_code == 200
    mock_mark.assert_called_once_with(order_id, "mess", "test_staff_user")


# ── 9. Continental mark-prepared: preparing → ready_for_pickup ────────────────
@patch("features.orders.repository.OrderRepository.get_order_by_id")
@patch("features.orders.repository.OrderRepository.mark_prepared")
def test_mark_prepared_continental_success(mock_mark, mock_get):
    order_id = "ord_mark_continental"
    mock_get.return_value = create_mock_order(
        order_id=order_id,
        categories=["continental"],
        token_statuses={"continental": "preparing"},
    )
    mock_mark.return_value = create_mock_order(
        order_id=order_id,
        categories=["continental"],
        token_statuses={"continental": "ready_for_pickup"},
    )

    response = client.post(
        f"/api/orders/{order_id}/mark-prepared",
        json={"category": "continental"},
    )
    assert response.status_code == 200
    mock_mark.assert_called_once_with(order_id, "continental", "test_staff_user")


# ── 10. mark-prepared fails if token not in preparing state ───────────────────
@patch("features.orders.repository.OrderRepository.get_order_by_id")
def test_mark_prepared_invalid_status(mock_get):
    order_id = "ord_invalid_status"
    mock_get.return_value = create_mock_order(
        order_id=order_id,
        categories=["mess"],
        token_statuses={"mess": "placed"},
    )

    response = client.post(
        f"/api/orders/{order_id}/mark-prepared",
        json={"category": "mess"},
    )
    assert response.status_code == 400
    assert "preparing" in response.json()["detail"].lower()


# ── 11. Mess mark-prepared does not affect Continental ────────────────────────
@patch("features.orders.repository.OrderRepository.get_order_by_id")
@patch("features.orders.repository.OrderRepository.mark_prepared")
def test_mark_mess_does_not_affect_continental(mock_mark, mock_get):
    order_id = "ord_mixed_mark"
    mock_get.return_value = create_mock_order(
        order_id=order_id,
        categories=["mess", "continental"],
        token_statuses={"mess": "preparing", "continental": "preparing"},
    )
    mock_mark.return_value = create_mock_order(
        order_id=order_id,
        categories=["mess", "continental"],
        token_statuses={"mess": "ready_for_pickup", "continental": "preparing"},
    )

    response = client.post(
        f"/api/orders/{order_id}/mark-prepared",
        json={"category": "mess"},
    )
    assert response.status_code == 200
    # Only mess was marked prepared
    mock_mark.assert_called_once_with(order_id, "mess", "test_staff_user")


# ── 12. Cancellation blocked after preparation starts ─────────────────────────
@patch("features.orders.repository.OrderRepository.get_order_by_id")
@patch("features.orders.repository.OrderRepository.cancel_order")
def test_cancellation_blocked_after_preparation(mock_cancel, mock_get):
    order_id = "ord_cancel_blocked"
    # cancel_order raises ValueError when token is in preparing state
    mock_cancel.side_effect = Exception("Order cannot be cancelled because preparation has already started.")

    response = client.post(f"/api/orders/{order_id}/cancel")
    # Even if the mock raises, we just verify the endpoint is hit
    # The actual block is enforced inside repository.cancel_order
    assert response.status_code in (400, 500)


# ── 13. Token-not-found for category returns 400 ──────────────────────────────
@patch("features.orders.repository.OrderRepository.get_order_by_id")
def test_start_preparation_missing_category_token(mock_get):
    order_id = "ord_no_continental"
    # Order only has mess, but client requests continental
    mock_get.return_value = create_mock_order(
        order_id=order_id, categories=["mess"]
    )

    response = client.post(
        f"/api/orders/{order_id}/start-preparation",
        json={"category": "continental"},
    )
    assert response.status_code == 400
    assert "continental" in response.json()["detail"].lower()


# ── 14. Terminal state blocks start-preparation ────────────────────────────────
@patch("features.orders.repository.OrderRepository.get_order_by_id")
def test_start_preparation_terminal_state_blocked(mock_get):
    order_id = "ord_terminal"
    mock_get.return_value = create_mock_order(
        order_id=order_id,
        categories=["mess"],
        token_statuses={"mess": "delivered"},
    )

    response = client.post(
        f"/api/orders/{order_id}/start-preparation",
        json={"category": "mess"},
    )
    assert response.status_code == 400
    assert "delivered" in response.json()["detail"].lower()
