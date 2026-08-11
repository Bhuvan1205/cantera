import pytest
from datetime import datetime, timezone, timedelta
from unittest.mock import patch
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

def create_mock_order(
    order_id="ord_123",
    user_id="test_student_user",
    status="placed",
    overall_status="active",
    categories=["mess"],
    mess_token_status="placed",
):
    items = [
        OrderItem(name=f"Item {i}", price=50, quantity=1, category=cat)
        for i, cat in enumerate(categories)
    ]
    tokens = [
        TokenDocument(
            token_id=f"token_{cat}",
            counter=cat,
            token_status=mess_token_status if cat == "mess" else "placed",
            token_number=100 + i,
            qr_valid=True,
            qr_code_data=f"{order_id}:{cat}:100",
            items=[{"item_name": "Test Item", "quantity": 1, "prep_units": 1.0}],
            otp="1234",
            queue_name="Test Item",
            prep_units_in_queue=1.0,
        )
        for i, cat in enumerate(categories)
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

# 1. Mess token can transition placed -> preparing
@patch("features.orders.repository.OrderRepository.get_order_by_id")
@patch("features.orders.repository.OrderRepository.start_preparation")
def test_start_preparation_success(mock_start, mock_get):
    order_id = "ord_success"
    mock_get.return_value = create_mock_order(order_id=order_id, status="placed")
    mock_start.return_value = create_mock_order(order_id=order_id, mess_token_status="preparing")

    response = client.post(f"/api/orders/{order_id}/start-preparation")
    assert response.status_code == 200
    mock_start.assert_called_once_with(order_id)

# 2. Non-Mess order cannot use start-preparation
@patch("features.orders.repository.OrderRepository.get_order_by_id")
def test_start_preparation_non_mess_error(mock_get):
    order_id = "ord_bakery"
    mock_get.return_value = create_mock_order(order_id=order_id, categories=["bakery"])

    response = client.post(f"/api/orders/{order_id}/start-preparation")
    assert response.status_code == 400
    assert "Only Mess orders" in response.json()["detail"]

# 3. Student cannot start preparation for another student's order
@patch("features.orders.repository.OrderRepository.get_order_by_id")
def test_start_preparation_ownership_error(mock_get):
    order_id = "ord_other_user"
    mock_get.return_value = create_mock_order(order_id=order_id, user_id="some_other_student")

    response = client.post(f"/api/orders/{order_id}/start-preparation")
    assert response.status_code == 403
    assert "permission" in response.json()["detail"]

# 4. Duplicate start-preparation does not duplicate queue entries (idempotent)
@patch("features.orders.repository.OrderRepository.get_order_by_id")
@patch("features.orders.repository.OrderRepository.start_preparation")
def test_start_preparation_idempotent(mock_start, mock_get):
    order_id = "ord_idempotent"
    mock_get.return_value = create_mock_order(order_id=order_id, mess_token_status="preparing")

    response = client.post(f"/api/orders/{order_id}/start-preparation")
    assert response.status_code == 200
    mock_start.assert_not_called()

# 5. preparing -> ready_for_pickup works
@patch("features.orders.repository.OrderRepository.get_order_by_id")
@patch("features.orders.repository.OrderRepository.mark_prepared")
def test_mark_prepared_success(mock_mark, mock_get):
    order_id = "ord_mark_success"
    mock_get.return_value = create_mock_order(order_id=order_id, mess_token_status="preparing")
    mock_mark.return_value = create_mock_order(order_id=order_id, mess_token_status="ready_for_pickup")

    response = client.post(f"/api/orders/{order_id}/mark-prepared")
    assert response.status_code == 200
    mock_mark.assert_called_once_with(order_id, "test_staff_user")

# 6. mark-prepared fails if not preparing
@patch("features.orders.repository.OrderRepository.get_order_by_id")
def test_mark_prepared_invalid_status(mock_get):
    order_id = "ord_invalid_status"
    mock_get.return_value = create_mock_order(order_id=order_id, mess_token_status="placed")

    response = client.post(f"/api/orders/{order_id}/mark-prepared")
    assert response.status_code == 400
    assert "does not have a Mess token in 'preparing' state" in response.json()["detail"]
