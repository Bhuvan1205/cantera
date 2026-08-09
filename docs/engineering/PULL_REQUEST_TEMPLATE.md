# Pull Request Template

## Description
Briefly describe the purpose of this PR and what feature/bugfix it accomplishes.

---

## Architectural Compliance (ADR-001 & EEL-001)
- [ ] No client-side direct writes to business collections
- [ ] No client-side financial calculations
- [ ] All business logic executed in FastAPI
- [ ] Layer ownership preserved (Flutter = Presentation, FastAPI = Domain Logic, Firestore = Persistence)

---

## Changes Summary

### Backend (FastAPI)
- **Schemas:**
- **Repositories:**
- **Services:**
- **Endpoints:**

### Frontend (Flutter)
- **Services:**
- **UI Screens/Widgets:**

---

## Verification & Test Results
- [ ] `flutter analyze` passed (0 errors, 0 warnings)
- [ ] `flutter test` passed (X/X tests)
- [ ] `pytest lib/admin_console/backend/tests -v` passed (X/X tests)
- [ ] `firebase emulators:exec "npm test"` passed (if rules modified)

---

## Migration & Rollback Strategy
- **Migration Impact:** (None / Schema addition)
- **Rollback Strategy:** (Revert PR; stateless Cloud Run redeployment)
- **Operational Considerations:**
