# API Standards & Conventions

All backend endpoints in Cantora must adhere to uniform RESTful API conventions and JSON response structures.

---

## 1. URL Path Conventions
- Base URL Prefix: `/api`
- Resources must use plural nouns in lowercase kebab-case (e.g. `/api/orders`, `/api/wallet/deposits`, `/api/inventory`).
- Actions on specific resources:
  - `POST /api/orders/checkout` (create and orchestrate order checkout)
  - `PATCH /api/orders/{order_id}/status` (update order status)
  - `POST /api/orders/scan-qr` (process counter QR scan)
  - `POST /api/wallet/orders/deposit` (initiate wallet top-up order)
  - `POST /api/wallet/deposits/verify` (verify deposit payment)
  - `POST /api/wallet/refunds/request` (request refund)

---

## 2. Standard HTTP Methods & Status Codes

| HTTP Method | Usage | Expected Status Code |
| :--- | :--- | :--- |
| `GET` | Read resource or collection | `200 OK` |
| `POST` | Create resource, execute atomic workflow | `200 OK` or `201 Created` |
| `PATCH` | Partial update of existing resource | `200 OK` |
| `DELETE` | Soft delete or archive | `200 OK` or `204 No Content` |

### Common Error Status Codes
- `400 Bad Request`: Malformed parameters or invalid payload.
- `401 Unauthorized`: Missing or invalid Firebase ID Token.
- `403 Forbidden`: Authenticated user lacks required role (`staff` or `admin`).
- `404 Not Found`: Target document (e.g., `order_id`, `item_id`) does not exist.
- `409 Conflict`: Business rule conflict (e.g., insufficient stock, insufficient wallet balance, cooldown active).
- `422 Unprocessable Entity`: Pydantic schema validation failure.
- `500 Internal Server Error`: Unhandled runtime or database exception.

---

## 3. Standard Headers
- **`Authorization`**: Required on all protected endpoints (`Bearer <Firebase_ID_Token>`).
- **`Idempotency-Key`**: Required on all financial or state-modifying `POST` requests (UUID v4).
- **`Content-Type`**: `application/json`

---

## 4. Error Response Format
All error responses return a standardized JSON structure:

```json
{
  "detail": "Descriptive human-readable error explanation",
  "error_code": "INSUFFICIENT_FUNDS",
  "meta": {
    "available_balance": 15.0,
    "required_amount": 50.0
  }
}
```

---

## Cross-References
- [Error Handling](file:///docs/engineering/ERROR_HANDLING.md)
- [Security Guidelines](file:///docs/engineering/SECURITY_GUIDELINES.md)
