# Layer Responsibilities

Under **ADR-001 (Backend-First Architecture)** and **EEL-001**, layer boundaries are strictly defined and non-negotiable.

---

## 1. Flutter (Presentation Layer)

### Allowed Responsibilities
- **UI & Layout:** Rendering screens, dialogs, sheets, responsive styling using design tokens.
- **User Input Validation:** Basic format validation (e.g. non-empty text, email format, numeric ranges) for instant UI feedback.
- **Authentication Lifecycle:** Handling Firebase Authentication sign-in, token refresh, and passing Bearer ID tokens to `ApiClient`.
- **Reactive UI Streaming:** Listening to read-only Firestore snapshots (`snapshots()`) for live UI updates.
- **Hardware & Device Integrations:** Interfacing with camera (`mobile_scanner`), local notifications, and payment SDKs (`razorpay_flutter`).

### Prohibited Responsibilities
- ❌ **NO direct Firestore writes:** Calling `.set()`, `.update()`, `.add()`, `.delete()`, `runTransaction()`, or `batch()` on business collections.
- ❌ **NO financial math:** Deducting balances, calculating order totals, computing discounts or wallet credits on the client.
- ❌ **NO business logic:** Determining queue order, token generation algorithms, permission checks, stock reservation logic.

---

## 2. FastAPI (Authoritative Application Layer)

### Allowed & Required Responsibilities
- **Single Source of Truth:** All mutations and domain rules MUST execute here.
- **Authentication & RBAC:** Verifying Firebase Auth JWTs and enforcing role permissions (`customer`, `staff`, `admin`).
- **Input Validation:** Enforcing strict schema contracts via Pydantic models.
- **Idempotency:** Enforcing unique `Idempotency-Key` headers on state-changing requests.
- **Atomic Orchestration:** Executing atomic transactions over Firestore documents via Firebase Admin SDK.
- **Domain Capabilities:**
  - Order checkout and item availability reservation.
  - Multi-counter token splitting (Bakery, Beverages, Continental, Mess).
  - Wallet top-up order generation, webhook/payment signature verification, and manual adjustments.
  - Secure QR code parsing and pickup OTP verification.
  - Queue calculation and real-time wait estimation.
  - User profile creation and pickup PIN rotation cooldowns.

---

## 3. Cloud Firestore (Persistence Layer)

### Responsibilities
- Storing canonical system data in structured document collections and subcollections.
- Serving real-time stream snapshots to connected clients.
- Enforcing access lockdown via `firestore.rules` (client writes denied on business collections).

---

## 4. Cloud Functions (Event Worker Layer)

### Responsibilities
- Triggering background workers on Firestore document mutations (e.g. `onDocumentUpdated`).
- Sending Firebase Cloud Messaging (FCM) push notifications on order state changes.
- Scheduled cron maintenance and metrics aggregation.
- ❌ Must NEVER be used as a synchronous API replacement for FastAPI.

---

## Cross-References
- [ADR-001 Backend-First](file:///docs/architecture/ADR-001-backend-first.md)
- [Data Flow](file:///docs/architecture/DATA_FLOW.md)
- [Engineering Rules](file:///docs/engineering/ENGINEERING_RULES.md)
