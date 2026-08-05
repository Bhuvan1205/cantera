# Testing Standards

A comprehensive test suite across three testing tiers ensures zero regressions and continuous compliance with ADR-001.

---

## 1. Backend Test Suite (`pytest`)

### Scope
- Unit and integration testing of all FastAPI endpoints, services, and repositories.
- Negative-path testing for HTTP status codes: `400`, `401`, `403`, `404`, `409`, `422`, and `500`.

### Location
`lib/admin_console/backend/tests/`

### Execution Command
```bash
pytest lib/admin_console/backend/tests -v
```

### Requirements
- Every new endpoint must have at least one happy-path test and tests for all expected conflict/error branches.
- Use `TestClient` from FastAPI to simulate requests with mock auth headers.

---

## 2. Firestore Security Rules Suite (`jest`)

### Scope
- Validating Firestore read/write boundaries across all collections using the Firebase Emulator Suite.

### Location
`tests/rules/firestore.rules.test.js`

### Execution Command
```bash
firebase emulators:exec --only firestore "npm test"
```
*(Run inside `tests/rules/` directory)*

### Requirements
- All unauthenticated operations must be verified as denied.
- Client writes across business collections must be asserted as rejected (`assertFails`).
- Scoped reads for owner, staff, and admin must be asserted as permitted (`assertSucceeds`).

---

## 3. Flutter Client Test Suite (`flutter test`)

### Scope
- Client validation logic, DTO deserialization, and widget UI interactions.

### Location
`test/`

### Execution Command
```bash
flutter test
```

### Static Analysis
```bash
flutter analyze
```
*(Must report 0 issues)*

---

## 4. Automated Continuous Integration (CI Pipeline)

The repository runs an automated CI pipeline on all Pull Requests and pushes to `main` and `feature/**` via GitHub Actions (`.github/workflows/ci.yml`).

### Automated Quality Gates
1. **Backend Tests:** Executes full `pytest` suite on Python 3.11.
2. **Flutter Static Analysis:** Executes `flutter analyze` (must have 0 errors, 0 warnings).
3. **Flutter Tests:** Executes `flutter test`.
4. **Security Rules Tests:** Boots the Firebase Emulator and executes the 72+ Jest assertions.

All 4 quality gates must pass before a PR can be merged into `main`.

---

## Cross-References
- [Feature Development Guide](file:///docs/engineering/FEATURE_DEVELOPMENT_GUIDE.md)
- [Code Review Checklist](file:///docs/engineering/CODE_REVIEW_CHECKLIST.md)
- [Deployment Runbook](file:///docs/operations/DEPLOYMENT_RUNBOOK.md)
