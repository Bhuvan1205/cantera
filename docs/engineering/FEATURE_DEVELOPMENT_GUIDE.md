# Feature Development Guide

Every new capability in Cantora must follow this sequential development lifecycle without skipping steps.

---

## The Lifecycle Workflow

```
1. Requirement Analysis
        │
        ▼
2. API Design & OpenAPI Spec
        │
        ▼
3. Pydantic Schemas (Request/Response)
        │
        ▼
4. Backend Repository Implementation
        │
        ▼
5. Backend Service Layer (Business Logic)
        │
        ▼
6. Backend Router (Endpoint & Auth Guards)
        │
        ▼
7. Backend Automated Tests (pytest)
        │
        ▼
8. Flutter Service / ApiClient Integration
        │
        ▼
9. Flutter UI (Widgets & State Binding)
        │
        ▼
10. Flutter Tests (flutter test)
        │
        ▼
11. Documentation & Verification
        │
        ▼
12. Pull Request Submission
```

---

## Step-by-Step Instructions

### Step 1: API Design & Schemas
- Define route path, HTTP method, required headers (`Authorization`, `Idempotency-Key` for state mutations).
- Write Pydantic request and response schemas in `lib/admin_console/backend/features/<feature>/schemas.py`.

### Step 2: Backend Repository & Service
- Implement persistence in `repository.py` using `firestore.Client` and `transactional` decorators if atomic multi-document writes are required.
- Implement domain logic, validation, and authorization in `service.py`.

### Step 3: Backend Router & Tests
- Expose the route in `router.py` with FastAPI dependency injection (`get_current_user`, `require_role`).
- Write automated test cases in `tests/test_<feature>.py` covering both happy path (200/201) and negative paths (400, 401, 403, 404, 409, 422).
- Verify with `pytest lib/admin_console/backend/tests -v`.

### Step 4: Flutter Integration & Presentation
- Add API call method to client service (e.g. `lib/user_console/services/` or `lib/wallet/services/`) using `ApiClient.instance`.
- Bind UI widgets to read-only Firestore snapshot streams or future builders.
- Add Flutter unit/widget tests in `test/`.

### Step 5: Verification & PR
- Run full verification suite:
  - `flutter analyze` (must be 0 issues)
  - `flutter test`
  - `pytest lib/admin_console/backend/tests -v`
- Submit PR using the [Pull Request Template](file:///docs/engineering/PULL_REQUEST_TEMPLATE.md).

---

## Cross-References
- [API Standards](file:///docs/engineering/API_STANDARDS.md)
- [Coding Standards](file:///docs/engineering/CODING_STANDARDS.md)
- [Testing Standards](file:///docs/engineering/TESTING_STANDARDS.md)
