# Do Not Break: Protected Invariants

This document enumerates the immutable core invariants of the Cantora codebase that must never be broken, modified, or bypassed by any AI agent.

---

## 1. Locked Invariants

### 1. `firestore.rules` Write Denial
The rules file `firestore.rules` enforces `allow write: if false;` on `Orders`, `tokens`, `Menu`, `queues`, `wallets`, `wallet_transactions`, `pending_deposits`, and `refund_requests`.
- ⚠️ **DO NOT** add client write permissions (`create`, `update`, `delete`) to these collections.

### 2. `ApiClient` Singleton Auth Injection
All HTTP client requests in Flutter pass through `ApiClient.instance`, which automatically fetches and injects the Firebase Auth JWT ID Token.
- ⚠️ **DO NOT** introduce raw `http.post` or `http.get` calls that bypass `ApiClient`.

### 3. Server-Authoritative Pricing & Stock
- ⚠️ **DO NOT** pass client-computed `total_price` or trust client-provided pricing. The server must look up price in `Menu` and compute totals.
- ⚠️ **DO NOT** update stock from the client. Stock must decrement atomically in the checkout transaction.

### 4. Pickup PIN 30-Day Cooldown
Users may only rotate their pickup PIN once every 30 days.
- ⚠️ **DO NOT** bypass or shorten this check on the server.

### 5. Repository → Service → Router Backend Topology
- ⚠️ **DO NOT** place database queries directly in routers or place HTTP logic in repositories.

---

## Cross-References
- [ADR-001 Backend-First](file:///docs/architecture/ADR-001-backend-first.md)
- [Project Constraints](file:///docs/agents/PROJECT_CONSTRAINTS.md)
