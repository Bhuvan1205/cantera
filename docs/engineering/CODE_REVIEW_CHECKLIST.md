# Code Review Checklist

Reviewers (both human engineers and AI reviewers) must evaluate every Pull Request against this strict checklist.

---

## 1. Architectural Compliance (ADR-001 & EEL-001)
- [ ] **Zero Client Business Writes:** Are there NO calls to `.set()`, `.update()`, `.add()`, `.delete()`, `runTransaction()`, or `writeBatch()` from Flutter on business collections?
- [ ] **No Client Financial Logic:** Are all financial math, order totals, and balance computations handled exclusively on the backend?
- [ ] **No Backend Bypass:** Does every state-changing action route through FastAPI on Cloud Run?
- [ ] **Layer Responsibility:** Does Flutter only handle UI, input validation, and stream rendering?
- [ ] **No Business Logic in Functions:** Are Cloud Functions strictly used for event triggers / FCM notifications?

---

## 2. Backend Design & Quality
- [ ] **3-Tier Pattern:** Does the implementation follow `Router → Service → Repository`?
- [ ] **Pydantic Validation:** Are request bodies and response schemas strictly typed?
- [ ] **Auth & RBAC:** Are `get_current_user` and role dependencies applied to protected routes?
- [ ] **Idempotency:** Are mutating operations protected by `Idempotency-Key`?
- [ ] **Atomicity:** Are multi-document mutations wrapped in Firestore transactions?

---

## 3. Client Design & Quality
- [ ] **ApiClient Usage:** Are all HTTP calls routed through `ApiClient.instance`?
- [ ] **Reactive UI:** Are live feeds reading from Firestore streams rather than polling?
- [ ] **Design Tokens:** Does UI code use `AppColors` and `AppTheme` without hardcoded styling?

---

## 4. Verification & Testing
- [ ] `flutter analyze` passes with 0 errors and 0 warnings.
- [ ] All `flutter test` tests pass.
- [ ] All `pytest` backend tests pass (including negative error cases).
- [ ] Firestore Emulator security rules pass if `firestore.rules` was modified.

---

## Decision Gate
If any architectural checklist item fails, the Pull Request **MUST BE REJECTED** and returned for refactoring.
