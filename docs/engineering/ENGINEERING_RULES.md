# Engineering Rules

These rules are permanent and mandatory for all human developers and AI coding agents.

---

## 1. Core Architectural Constraints
1. **FastAPI is the Single Source of Truth:** All domain logic, business validations, financial operations, stock checks, and status mutations MUST execute in FastAPI.
2. **Flutter is Presentation-Only:** The Flutter client must NEVER contain domain or financial calculation logic, nor perform direct database writes to business collections.
3. **Firestore is Persistence-Only:** Firestore stores state; it does not evaluate business rules.
4. **Cloud Functions are Event Workers Only:** Cloud Functions react to Firestore triggers (e.g. FCM alerts) and MUST NOT act as an ad-hoc REST backend.

---

## 2. Prohibited Practices (Permanent Zero-Tolerance)
- ❌ Calling `.set()`, `.update()`, `.add()`, `.delete()`, `runTransaction()`, or `writeBatch()` from Flutter against any business collection.
- ❌ Calculating order totals, discounts, or wallet debits on the client device.
- ❌ Bypassing the backend by directly modifying Firestore documents via Firebase Console or client tools.
- ❌ Introducing client-side queue ordering or inventory decrement logic.
- ❌ Duplicate business logic across client and server.

---

## 3. Mandatory Implementation Pattern
Every backend feature MUST adhere to the 3-Tier Layered Architecture:

```
Router (HTTP / Schemas / Auth)
   │
   ▼
Service (Business Logic / Orchestration)
   │
   ▼
Repository (Database / Firebase Admin SDK)
```

1. **Router Layer:** Handles HTTP parsing, query parameters, Pydantic request/response validation, and Auth dependencies.
2. **Service Layer:** Owns business workflows, calculations, error classification, and multi-repository orchestration.
3. **Repository Layer:** Encapsulates Firestore database queries, document reads, and ACID transactions via the Firebase Admin SDK.

---

## 4. Quality & Verification Gates
No feature or code change may be merged unless:
1. `flutter analyze` passes with **0 errors and 0 warnings**.
2. Flutter unit and widget tests pass (`flutter test`).
3. Backend test suite passes (`pytest lib/admin_console/backend/tests -v`).
4. Security rules emulator tests pass if rules were touched (`tests/rules`).

---

## Cross-References
- [ADR-001 Backend-First](file:///docs/architecture/ADR-001-backend-first.md)
- [Layer Responsibilities](file:///docs/architecture/LAYER_RESPONSIBILITIES.md)
- [Code Review Checklist](file:///docs/engineering/CODE_REVIEW_CHECKLIST.md)
