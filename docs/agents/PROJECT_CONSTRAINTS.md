# Agent Project Constraints

Every AI agent working on this codebase must strictly observe these constraints without exception.

---

## 1. Non-Negotiable Constraints
1. **Never write business or financial mutations in Flutter:** Calling `.set()`, `.update()`, `.add()`, `.delete()`, `runTransaction()`, or `writeBatch()` from Flutter code is strictly prohibited.
2. **Never calculate pricing or balance debits on the client:** The backend must compute all financial math from canonical `Menu` and `wallets` documents.
3. **Never bypass FastAPI:** Every state mutation must route through a FastAPI endpoint on Cloud Run.
4. **Never modify `firestore.rules` to permit direct client writes:** Client writes on business collections must remain locked.
5. **Always follow the 3-tier pattern:** Backend features must be organized as `Router → Service → Repository`.

---

## 2. Invariant Checklist Before Producing Code
- [ ] Is this change compliant with ADR-001?
- [ ] Does this change keep Flutter as a presentation layer only?
- [ ] Does this change implement all domain validation on the backend?
- [ ] Does this change include relevant tests (`pytest` / `flutter test`)?

---

## Cross-References
- [Do Not Break](file:///docs/agents/DO_NOT_BREAK.md)
- [Engineering Rules](file:///docs/engineering/ENGINEERING_RULES.md)
