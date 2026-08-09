# Error Handling & Resilience

This document defines standard error taxonomy, HTTP error response structures, and client resilience strategies.

---

## 1. Backend Error Taxonomy & HTTP Status Codes

| Error Condition | HTTP Code | Error Code | Description |
| :--- | :--- | :--- | :--- |
| Invalid payload / schema | `422` | `SCHEMA_VALIDATION_FAILED` | Pydantic model validation failure. |
| Missing / expired JWT | `401` | `UNAUTHORIZED` | Token rejected by Firebase Admin Auth. |
| Role insufficient | `403` | `FORBIDDEN` | User does not have staff or admin role. |
| Document not found | `404` | `RESOURCE_NOT_FOUND` | Order, item, or user document does not exist. |
| Insufficient stock | `409` | `INSUFFICIENT_STOCK` | Requested quantity exceeds inventory. |
| Insufficient wallet balance | `409` | `INSUFFICIENT_BALANCE` | User wallet balance is lower than total. |
| Cooldown active | `429` | `COOLDOWN_ACTIVE` | Pickup PIN changed within last 30 days. |
| Database transaction error | `500` | `TRANSACTION_FAILED` | Firestore transaction aborted or server error. |

---

## 2. Standardized JSON Error Payload
```json
{
  "detail": "Requested item 'item_01' is out of stock.",
  "error_code": "INSUFFICIENT_STOCK",
  "meta": {
    "item_id": "item_01",
    "requested_qty": 2,
    "available_qty": 0
  }
}
```

---

## 3. Flutter Client Handling
- `ApiClient` inspects HTTP status codes.
- `401 Unauthorized` triggers token refresh or redirects user to login.
- `409 Conflict` and `422 Unprocessable` extract the `detail` message and present user-friendly alerts or snackbars.
- `500 Internal Error` prompts a retry with exponential backoff.
- Network disconnection is gracefully caught to show an offline banner while preserving cached Firestore streams.

---

## Cross-References
- [API Standards](file:///docs/engineering/API_STANDARDS.md)
- [Security Guidelines](file:///docs/engineering/SECURITY_GUIDELINES.md)
