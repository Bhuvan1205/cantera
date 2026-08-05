# System Architecture

## Overview
Cantora is a real-time smart canteen management platform designed to handle high-concurrency order surges, multi-counter token routing, student wallet credits, live dynamic queueing, and canteen staff order verification.

```
┌────────────────────────────────────────────────────────┐
│                     Flutter Client                     │
│   (Mobile / Desktop / Admin & Staff Web Terminals)     │
└────────────┬───────────────────────────────▲───────────┘
             │                               │
             │ HTTP (Bearer ID Token)        │ Firestore Real-Time Streams
             ▼                               │ (Read-Only Snapshots)
┌────────────────────────┐                   │
│     Cloud Run          │                   │
│   (FastAPI Backend)    │                   │
└────────────┬───────────┘                   │
             │                               │
             │ Admin SDK ACID Transactions   │
             ▼                               │
┌────────────────────────────────────────────┴───────────┐
│                    Cloud Firestore                     │
│                  (Persistence Layer)                   │
└────────────┬───────────────────────────────────────────┘
             │
             │ Event Triggers (onCreate, onUpdate)
             ▼
┌────────────────────────┐
│    Cloud Functions     │
│  (FCM & Async Tasks)   │
└────────────────────────┘
```

---

## Component Architecture

### 1. Presentation Layer (Flutter Client)
- **Target Platforms:** Android, iOS, Web (Canteen Counter Staff POS).
- **Core Role:** Presentation, input capture, hardware interface (Mobile Scanner camera, Razorpay SDK), reactive UI updates via read-only Firestore snapshot streams (`snapshots()`).
- **Communication:** Centralized HTTP calls via `ApiClient` injecting Firebase Auth JWT ID tokens.

### 2. Application Layer (FastAPI Backend on Cloud Run)
- **Runtime:** Python 3.11 / FastAPI running on Google Cloud Run with automatic horizontal autoscaling (0 to 10 instances).
- **Architecture Pattern:** Repository → Service → Router.
- **Security:** Firebase Auth token validation dependency, custom claims-based RBAC (`customer`, `staff`, `admin`), cryptographically secure UUID v4 idempotency enforcement.
- **Core Modules:**
  - `orders`: Atomic multi-item checkout, counter token splitting, QR generation, OTP validation.
  - `wallet`: Server-side Razorpay order creation, payment signature verification, deposit approval, wallet balance adjustments.
  - `inventory`: Stock management, real-time availability toggling, low-stock alerts.
  - `users`: User profile onboarding, pickup PIN management with 30-day cooldown.

### 3. Persistence Layer (Cloud Firestore)
- **Mode:** Production multi-region NoSQL document store.
- **Security:** Enforced via `firestore.rules`. Client writes are denied across all business collections; reads are scoped strictly to document owners or staff/admin roles.
- **Transactions:** Server-orchestrated ACID transactions executing via the Firebase Admin SDK.

### 4. Event Worker Layer (Cloud Functions)
- **Runtime:** Node.js 20 / Firebase Functions v2.
- **Role:** Asynchronous event listeners for Firestore state changes (e.g. sending FCM push notifications when order status moves from `placed` → `preparing` → `ready_for_pickup` → `delivered`).

---

## Cross-References
- [ADR-001 Backend-First](file:///docs/architecture/ADR-001-backend-first.md)
- [Layer Responsibilities](file:///docs/architecture/LAYER_RESPONSIBILITIES.md)
- [Data Flow](file:///docs/architecture/DATA_FLOW.md)
- [Cloud Architecture](file:///docs/architecture/CLOUD_ARCHITECTURE.md)
