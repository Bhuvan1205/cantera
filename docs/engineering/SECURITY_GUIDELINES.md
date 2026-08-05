# Security Guidelines

Security in Cantora is multi-layered, combining token-based authentication, RBAC custom claims, server-enforced business validation, and database-level security rules.

---

## 1. Authentication & Authorization (RBAC)

### Firebase Auth & ID Tokens
- Every client API request must attach a Bearer ID Token in the `Authorization` header.
- The FastAPI backend validates token signature, expiration, and issuer using `firebase_admin.auth.verify_id_token()`.

### Custom Claims RBAC
- Roles (`customer`, `staff`, `admin`) are embedded as Custom Claims in the Firebase Auth token.
- Protected routes enforce role checks via dependency injection:
  ```python
  def require_role(allowed_roles: list[str]):
      async def role_checker(current_user: dict = Depends(get_current_user)):
          if current_user.get("role") not in allowed_roles:
              raise HTTPException(status_code=403, detail="Forbidden")
          return current_user
      return role_checker
  ```

---

## 2. Firestore Security Rules Lockdown
- All client write operations (`create`, `update`, `delete`) are **DENIED** on all business collections in `firestore.rules`.
- Reads are strictly scoped:
  - `Users`: Document owner or admin.
  - `Orders`: Document owner (`userId == auth.uid`), staff, or admin.
  - `wallets` & `wallet_transactions`: Document owner or admin.
  - `Menu` & `queues`: Authenticated users.
- Catch-all rule: Any unlisted collection is completely denied for both reads and writes.

---

## 3. Financial Integrity & Signature Verification
- **Payment Verification:** Razorpay payment webhooks and client callbacks must verify the `razorpay_signature` using HMAC-SHA256 with the server-held secret key.
- **Deposit Amounts:** Enforced strictly between ₹20 and ₹500 on the backend.
- **ACID Transactions:** All wallet debits, stock decrements, and refund credits execute within atomic Firestore transactions.

---

## 4. Idempotency Protection
- All mutating endpoints require an `Idempotency-Key` header (UUID v4).
- Replay requests with the same key within the cache window return the cached response without re-executing transactions.

---

## Cross-References
- [Firestore Schema](file:///docs/architecture/FIRESTORE_SCHEMA.md)
- [API Standards](file:///docs/engineering/API_STANDARDS.md)
