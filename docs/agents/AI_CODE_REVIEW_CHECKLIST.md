# AI Agent Code Review Checklist

When performing self-review or inspecting another agent's code, apply this automated checklist.

---

## 1. Compliance Audit
- [ ] Is there ANY direct Firestore mutation (`.set`, `.update`, `.add`, `.delete`, `runTransaction`, `writeBatch`) in Dart files?
  - **Verdict:** If YES, FAIL immediately.
- [ ] Is there any client-side math computing wallet balances or order totals?
  - **Verdict:** If YES, FAIL immediately.
- [ ] Is there any missing `Idempotency-Key` on state-changing endpoints?
  - **Verdict:** If YES, add idempotency header and validation.

---

## 2. Code Quality Audit
- [ ] Are Pydantic schemas strict with typed fields and descriptions?
- [ ] Are all FastAPI route handlers asynchronous (`async def`)?
- [ ] Are all Flutter widgets using `AppColors` tokens instead of raw colors?
- [ ] Did `flutter analyze` run with 0 errors and 0 warnings?
- [ ] Did `pytest` run with 100% passing tests?

---

## Cross-References
- [Code Review Checklist](file:///docs/engineering/CODE_REVIEW_CHECKLIST.md)
- [Do Not Break](file:///docs/agents/DO_NOT_BREAK.md)
