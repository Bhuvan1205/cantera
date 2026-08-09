# AI Agent Feature Implementation Protocol

Every AI agent implementing a feature in this repository must execute the following protocol strictly in order.

---

## The 10-Step Implementation Protocol

```
1. Clarify Requirements & Identify Impacted Collections
                     │
                     ▼
2. Create/Update Pydantic Schemas in Backend
                     │
                     ▼
3. Implement Firestore Admin SDK Repository Methods
                     │
                     ▼
4. Implement Business Validation in Service Layer
                     │
                     ▼
5. Expose Endpoint in FastAPI Router with Auth Guards
                     │
                     ▼
6. Author pytest Unit & Integration Tests and Verify
                     │
                     ▼
7. Update/Create Flutter Service Method using ApiClient
                     │
                     ▼
8. Implement Flutter UI Screen/Widget using Design Tokens
                     │
                     ▼
9. Execute flutter analyze and flutter test
                     │
                     ▼
10. Update Relevant Docs and Provide Verification Evidence
```

---

## Critical Rules During Execution
1. **Never skip step 6:** Backend tests must be written and executed before proceeding to Flutter client integration.
2. **Never leave analyzer warnings:** `flutter analyze` must report zero issues.
3. **Preserve existing docstrings:** Maintain all existing comments and documentation unless explicitly obsolete.

---

## Cross-References
- [Feature Development Guide](file:///docs/engineering/FEATURE_DEVELOPMENT_GUIDE.md)
- [Testing Standards](file:///docs/engineering/TESTING_STANDARDS.md)
