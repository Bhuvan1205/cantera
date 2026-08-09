# Engineering Status: Feature Development Mode (EEL-001 Locked)

## Architectural Baseline: ADR-001 (Backend-First Architecture)
- **FastAPI (Cloud Run)**: Single source of truth for all business, domain, and financial logic.
- **Flutter Client**: Presentation layer only (UI, Auth state, read-only Firestore stream rendering, API client).
- **Cloud Firestore**: Persistence layer with locked client-write rules.
- **Cloud Functions**: Event-driven background workers.

---

## Migration History (Complete & Verified)

### Phase 1 — Backend Completeness ✅
- [x] All business endpoints implemented in FastAPI (`/api/orders`, `/api/wallet`, `/api/inventory`, `/api/users`)
- [x] 40/40 backend `pytest` tests passing

### Phase 2 — Flutter Migration ✅
- [x] All screens migrated to consume FastAPI via `ApiClient` with Firebase Auth ID tokens
- [x] Direct Firestore mutation audit completed (0 active client writes)

### Phase 3 — Firestore Security Rules Lockdown ✅
- [x] Client writes denied on all business collections in `firestore.rules`
- [x] 72/72 Firestore Emulator security rules tests passing

### Phase 4 — Legacy Client-Side Code Removal ✅
- [x] Deleted all deprecated Spark-era mutation methods, private helpers, and obsolete write repositories
- [x] `flutter analyze`: 0 errors, 0 warnings

### Phase 5 — Verification & Regression Suite ✅
- [x] `flutter test`: 6/6 passing
- [x] `pytest`: 40/40 passing
- [x] Rules Emulator: 72/72 passing

---

## Operating Mode: Feature Development Mode (EEL-001)
All upcoming tasks must follow the mandatory request flow:
`User -> Flutter -> FastAPI -> Firestore Transaction -> Response -> Flutter`
