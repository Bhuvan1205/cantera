# Architecture Decision History

A chronological record of significant architectural decisions and milestones in the Cantora codebase.

---

| ID | Date | Status | Title & Summary |
| :--- | :--- | :--- | :--- |
| **ADR-001** | 2026-08-04 | **LOCKED** | **Backend-First Architecture**: Established FastAPI (Cloud Run) as the authoritative single source of truth, Flutter as presentation-only, Firestore as persistence-only, and Cloud Functions as event workers. |
| **EEL-001** | 2026-08-05 | **LOCKED** | **Engineering Execution Lock**: Formally froze the ADR-001 architecture and transitioned the project into Feature Development Mode. Prohibits any architectural redesign or client-side business logic. |
| **SEC-001** | 2026-08-04 | **ACTIVE** | **Firestore Security Rules Lockdown**: Locked down client writes on all 8 business collections (`Orders`, `tokens`, `Menu`, `queues`, `wallets`, `wallet_transactions`, `pending_deposits`, `refund_requests`). Verified via 72/72 passing emulator tests. |
| **FIN-001** | 2026-08-04 | **ACTIVE** | **Server-Side Payment & Wallet Verification**: Migrated Razorpay payment verification and wallet debit/credit transactions to execute exclusively inside backend transactions with HMAC-SHA256 signature verification. |
| **ORD-001** | 2026-08-04 | **ACTIVE** | **Multi-Counter Token Routing**: Implemented atomic server-side splitting of student orders into independent per-counter token sub-documents with automated queue placement. |

---

## Process for Future Decisions
Any proposed deviation or addition to the system architecture requires:
1. Formal Request for Comments (RFC).
2. Authoring a new ADR (`ADR-xxx.md`).
3. Explicit sign-off from project engineering leads.
4. Comprehensive migration and regression testing plan.
