# Architecture Decision Record (ADR-001)

## Backend-First Architecture (Locked)

**Status:** Approved & Locked  
**Date:** 2026-08-04  
**Context:** Migration to Firebase Blaze Plan, Cloud Run (FastAPI), Cloud Functions Gen2, and zero-trust backend architecture.

---

# Core Principle

The backend is the **single source of truth**.

All business logic, domain logic, financial logic, workflow orchestration, authorization decisions, and data mutations must execute **only in the FastAPI backend**.

The client must never contain business logic.

---

# Locked System Architecture

```
Flutter Client
        │
        ▼
Firebase Authentication
        │
Firebase ID Token
        │
        ▼
FastAPI Backend (Cloud Run)
        │
        ▼
Firestore / Cloud Storage
        │
        ▼
Cloud Functions (Event-Driven Only)
```

This flow is now frozen.

No future implementation should bypass it.

---

# Responsibilities

## Flutter (Presentation Layer Only)

Flutter is responsible only for:

* Rendering UI
* Collecting user input
* Client-side UX validation
* Calling backend APIs
* Displaying backend responses
* Local caching (optional)
* Offline UI state (optional)
* Firebase Authentication
* Firebase Messaging token registration
* App Check integration

Flutter must **NOT**:

* Calculate prices
* Calculate totals
* Calculate wallet balances
* Generate order IDs
* Generate queue tokens
* Reserve inventory
* Verify payments
* Verify QR codes
* Verify OTPs
* Update wallet balances
* Modify orders
* Update inventory
* Assign roles
* Execute business rules
* Make authorization decisions
* Write directly to business collections in Firestore

Flutter is a presentation layer only.

---

## FastAPI Backend (Single Source of Truth)

FastAPI owns all business logic.

Examples include:

* Authentication verification
* Authorization
* Checkout orchestration
* Wallet management
* Razorpay integration
* Order creation
* Inventory reservation
* Queue allocation
* Token generation
* QR verification
* OTP verification
* Payment verification
* Refund processing
* Transaction ledger
* Analytics events
* Audit logging
* Admin operations
* Validation
* Business rules

Every business decision originates here.

---

## Firestore

Firestore is a persistence layer.

Responsibilities:

* Data storage
* Transactions
* Queries
* Indexes
* Security Rules
* Event triggers

Firestore must never become an application layer.

Business logic should not be implemented through document structure or client write patterns.

---

## Cloud Functions

Cloud Functions are restricted to asynchronous and event-driven work.

Allowed responsibilities:

* Firestore triggers
* Scheduled jobs
* Push notifications
* Custom Claims synchronization
* Background maintenance
* Analytics aggregation
* Cleanup tasks
* Webhook handlers where appropriate

Cloud Functions must **NOT** become a second REST backend.

Checkout, wallet, inventory, queue, pricing, and other core business logic belong in FastAPI.

---

# Data Flow

Every user action must follow this sequence:

```
User Action
      │
Flutter
      │
HTTPS Request
      │
FastAPI
      │
Business Logic
      │
Firestore Transaction
      │
Response
      │
Flutter UI
```

Direct client writes to business collections are prohibited unless explicitly approved as an architectural exception.

---

# Non-Negotiable Backend Operations

The following operations must always execute through FastAPI:

* User profile updates requiring validation
* Wallet top-ups
* Wallet debits
* Wallet credits
* Payment verification
* Checkout
* Order creation
* Order cancellation
* Refunds
* Inventory updates
* Queue/token generation
* QR validation
* OTP validation
* Transaction creation
* Analytics events
* Audit logs
* Administrative operations
* Pricing calculations
* Discount calculations
* Availability checks

---

# Architectural Constraints

Future implementations must satisfy the following:

1. No business logic in Flutter.
2. No financial calculations in Flutter.
3. No direct business writes from Flutter to Firestore.
4. No duplication of business logic between FastAPI and Cloud Functions.
5. FastAPI remains the only authoritative business layer.
6. Firestore remains a persistence layer.
7. Cloud Functions remain event-driven workers.
8. Every state-changing operation must be auditable.
9. Every financial operation must be idempotent where applicable.
10. Every API must validate authentication and authorization server-side.

---

# Review Policy

Any pull request introducing business logic outside FastAPI should be treated as an architectural violation.

The reviewer should request refactoring before approval unless there is an explicit documented exception.

---

# Future Development Rule

From this point onward, all new features, refactors, and enhancements must conform to this architecture.

No new implementation should introduce Spark-era compromises or bypass the backend for convenience.

This Architecture Decision Record supersedes any previous implementation pattern that placed business logic in the client.
