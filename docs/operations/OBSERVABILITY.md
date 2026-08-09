# Observability & Structured Logging

This document outlines the logging standards, distributed tracing, and request correlation implementation.

---

## 1. Structured Logging Format (Backend)
All FastAPI logs are emitted in structured JSON format to standard output:

```json
{
  "timestamp": "2026-08-05T06:30:00.000Z",
  "severity": "INFO",
  "message": "Checkout transaction completed successfully",
  "request_id": "c4e3b789-231a-4c28-98e6-5cfa1034ba72",
  "user_uid": "user_xyz123",
  "order_id": "ord_98765",
  "execution_time_ms": 142.5,
  "http_status": 200
}
```

---

## 2. Request Correlation & Tracing
- Every incoming HTTP request is assigned a unique `X-Request-ID` header.
- The `X-Request-ID` is propagated across all log entries, database transaction traces, and returned in the HTTP response headers.

---

## 3. Querying Cloud Logging

### Filter 5xx Server Errors
```
resource.type="cloud_run_revision"
httpRequest.status>=500
```

### Filter Orders for a Specific User
```
jsonPayload.user_uid="user_xyz123"
jsonPayload.order_id=*
```

---

## Cross-References
- [Monitoring](file:///docs/operations/MONITORING.md)
- [Error Handling](file:///docs/engineering/ERROR_HANDLING.md)
