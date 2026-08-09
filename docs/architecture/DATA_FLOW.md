# Data Flow

Every state-changing operation in the Cantora platform must strictly follow the **Universal Request Flow**.

---

## Universal Request Flow

```
┌────────┐               ┌─────────┐               ┌─────────┐               ┌───────────┐
│ User   │               │ Flutter │               │ FastAPI │               │ Firestore │
└───┬────┘               └───┬─────┘               └───┬─────┘               └─────┬─────┘
    │                        │                         │                           │
    │ 1. Triggers Action     │                         │                           │
    ├───────────────────────>│                         │                           │
    │                        │ 2. POST /api/...        │                           │
    │                        │    Bearer <ID_Token>    │                           │
    │                        │    Idempotency-Key      │                           │
    │                        ├────────────────────────>│                           │
    │                        │                         │ 3. Verify JWT & Roles     │
    │                        │                         │ 4. Validate Schema        │
    │                        │                         │                           │
    │                        │                         │ 5. runTransaction()       │
    │                        │                         ├──────────────────────────>│
    │                        │                         │    - Read current state   │
    │                        │                         │    - Check invariants     │
    │                        │                         │    - Atomic Writes/Updates│
    │                        │                         │<──────────────────────────┤
    │                        │                         │ 6. Commit Success         │
    │                        │ 7. HTTP 200/201 JSON    │                           │
    │                        │<────────────────────────┤                           │
    │                        │                         │                           │
    │                        │ 8. Real-time Stream Push│                           │
    │                        │<────────────────────────────────────────────────────┤
    │ 9. UI Updates Reactively                         │                           │
    │<───────────────────────┤                         │                           │
```

---

## Key Workflows

### 1. Checkout Flow
1. **User:** Submits cart items in Flutter.
2. **Flutter:** Calls `POST /api/orders/checkout` with `Idempotency-Key`.
3. **FastAPI:**
   - Verifies customer authentication.
   - Computes total price from authoritative `Menu` prices.
   - Begins Firestore Transaction:
     - Verifies each item is available and has sufficient stock.
     - Decrements item stock.
     - If payment is `wallet`, verifies balance $\ge$ order total, deducts balance, and writes to `wallet_transactions`.
     - Creates parent `Orders` document.
     - Allocates counter tokens and creates `Orders/{orderId}/tokens/{tokenId}` sub-documents.
     - If category is `mess`, appends entry into `queues/mess`.
4. **FastAPI:** Commits transaction and returns `{ "order_id": "...", "status": "placed" }`.
5. **Firestore:** Pushes updated documents to Flutter real-time stream listeners.

### 2. QR Scan & Order Pickup Flow
1. **Staff Terminal:** Camera scans student QR code `"<order_id>::<token_id>"`.
2. **Flutter:** Calls `POST /api/orders/scan-qr`.
3. **FastAPI:**
   - Authorizes staff permissions.
   - Runs atomic transaction:
     - Direct counters (Bakery, Beverages, Continental): Marks token as `delivered`, invalidates QR.
     - Mess counter: Marks token as `preparing`, requires 4-digit OTP to advance queue.
4. **FastAPI:** Returns status confirmation to staff terminal.

### 3. Wallet Deposit & Verification Flow
1. **Flutter:** Calls `POST /api/wallet/orders/deposit` with amount $\in [₹20, ₹500]$.
2. **FastAPI:** Creates server-side Razorpay order and writes `pending_deposits` record in `awaiting_review` state. Returns Razorpay order ID.
3. **Flutter:** Opens Razorpay checkout SDK.
4. **Flutter:** On payment SDK callback, calls `POST /api/wallet/deposits/verify` with deposit ID.
5. **FastAPI:** Validates payment signature with Razorpay API, executes atomic transaction to credit user wallet and write `wallet_transactions` record.

---

## Cross-References
- [System Architecture](file:///docs/architecture/SYSTEM_ARCHITECTURE.md)
- [Firestore Schema](file:///docs/architecture/FIRESTORE_SCHEMA.md)
- [Error Handling](file:///docs/engineering/ERROR_HANDLING.md)
