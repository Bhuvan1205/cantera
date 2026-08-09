# ADR-001: Backend-First Architecture

## Status
**ACCEPTED & LOCKED (EEL-001)**

## Date
2026-08-04 (Finalized & Locked: 2026-08-05)

## Context
The Cantora Canteen application previously operated on a client-heavy model (Spark-era Firebase patterns) where business logic, financial mutations, order orchestration, stock decrement, queue management, and wallet balance debits occurred directly on client devices (Flutter) using Firestore Transactions.

This created critical operational and security vulnerabilities:
1. **Security Exposure:** Client devices directly performed balance adjustments and stock mutations.
2. **Race Conditions:** High-concurrency events (e.g., peak lunch rush) led to distributed client contention.
3. **Auditability Gaps:** No single server authoritative log existed for financial and inventory state transitions.
4. **Maintenance Overhead:** Business logic was duplicated across Flutter screens and Cloud Functions.

## Decision
We establish a permanent **Backend-First Architecture** governed by the following core rules:

1. **FastAPI Backend (Cloud Run)** is the **Single Source of Truth** for all business, domain, and financial logic.
2. **Flutter Client** is strictly a **Presentation Layer** for UI rendering, local state management, read-only Firestore stream binding, and backend API consumption.
3. **Cloud Firestore** is strictly a **Persistence Layer** with all client write operations **DENIED** across business collections (`Orders`, `tokens`, `Menu`, `queues`, `wallets`, `wallet_transactions`, `pending_deposits`, `refund_requests`).
4. **Cloud Functions** operate solely as **Event-Driven Asynchronous Workers** (push notifications, telemetry, maintenance).

```
Flutter Client
      │
      ▼ (Firebase ID Token)
FastAPI Backend (Cloud Run)
      │
      ▼ (Firebase Admin SDK Transactions)
Cloud Firestore (Persistence)
      │
      ▼ (Event Triggers)
Cloud Functions (Notifications/Async)
```

## Consequences

### Positive
- **Guaranteed Consistency:** All mutations execute in ACID Firestore transactions within the server runtime.
- **Strict Security:** Client devices cannot forge prices, bypass stock limits, or manipulate balances.
- **Deterministic Testing:** 100% of business logic can be tested in isolation using backend unit and integration test suites (`pytest`).
- **Clean Separation of Concerns:** Flutter UI code is simplified into declarative widgets bound to reactive streams.

### Negative / Trade-offs
- Client must make authenticated network calls to Cloud Run for state changes rather than local offline writes.
- Requires robust network error handling and offline state indicators in Flutter.

## References
- [System Architecture](file:///docs/architecture/SYSTEM_ARCHITECTURE.md)
- [Layer Responsibilities](file:///docs/architecture/LAYER_RESPONSIBILITIES.md)
- [Engineering Rules](file:///docs/engineering/ENGINEERING_RULES.md)
