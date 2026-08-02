# Canteen System Engineering Execution SOP

> **Purpose:** This document is the **single source of truth** for all architecture polishing work. Follow it exactly.

## 1. Authority

This implementation plan was produced after multiple architecture reviews and deep technical discussions. **Do not reinterpret, reprioritize, or redesign the system. Execute the plan exactly as written.**

If any previous conversation conflicts with this document, **this document takes precedence**.

---

# 2. Mission

Your objective is **to polish and harden the existing system**, not to redesign it.

Success means:

- Preserve existing functionality.
- Eliminate verified security, concurrency and correctness issues.
- Improve scalability only where justified.
- Minimize code changes.
- Avoid regressions.

---

# 3. Non‑Negotiable Rules

## 3.1 Do NOT perform unnecessary refactoring

Do NOT:

- Rename files.
- Rename folders.
- Rename APIs.
- Rename models.
- Rename repositories.
- Rename services.
- Rename variables purely for style.
- Reformat unrelated files.
- Change project structure.
- Introduce new frameworks.
- Introduce CQRS.
- Introduce DDD.
- Introduce Event Bus.
- Introduce Repository abstractions unless already present.
- Replace working code because it is "cleaner."

Only modify code required to solve the assigned issue.

---

## 3.2 One Issue At A Time

Never implement multiple architectural changes simultaneously.

Workflow:

1. Select ONE issue.
2. Understand existing implementation.
3. Implement ONLY that issue.
4. Build.
5. Test.
6. Verify regression free.
7. Produce report.
8. Only then continue.

---

## 3.3 Never Assume

Before changing anything:

- Read existing implementation.
- Verify issue exists.
- If already fixed:
  - report it
  - make no changes.

---

## 3.4 Smallest Possible Change

Prefer:

Small localized fixes

instead of

large architectural rewrites.

---

# 4. Priority Order

## P0 (Must complete before production)

1. Backend-only wallet credits.
2. Backend-only deposit approval.
3. Payment verification pipeline.
4. Firestore transactions for financial state.
5. Firestore transactions for inventory updates.
6. Idempotency for payment callbacks.
7. Convert blocking FastAPI async handlers using synchronous SDKs to `def`.

## P1

- Firebase Custom Claims.
- Denormalize user information into Orders.
- Queue abstraction layer (no migration unless requested).
- Audit logging improvements.
- Personal queue stream + snapshot queue overview.

## P2

- Queue schema migration.
- Pagination.
- Index tuning after production telemetry.

---

# 5. Explicit Do-Not-Touch List

Unless absolutely required for the active issue:

- Flutter UI layouts.
- Navigation.
- Authentication flow.
- Existing Firestore schema.
- Existing APIs.
- Business logic unrelated to active issue.
- Folder structure.
- Build configuration.
- Dependencies.
- CI/CD.
- Naming conventions.

---

# 6. Iterative Execution Protocol

For EVERY task follow this sequence.

## Phase A — Investigation

Produce:

- Root cause.
- Files affected.
- Why change is necessary.
- Expected side effects.

Do not edit yet.

---

## Phase B — Implementation

Modify only required files.

Do not touch unrelated code.

---

## Phase C — Verification

Verify:

- Project builds.
- No syntax errors.
- No import errors.
- No broken dependencies.
- Existing functionality preserved.
- Active issue resolved.

If verification fails:

STOP.

Fix before proceeding.

---

## Phase D — Regression Check

Check:

- Existing feature still works.
- No unrelated tests fail.
- Firestore schema unchanged unless intended.
- API contracts unchanged.

---

## Phase E — Report

Report:

- Files changed.
- Reason.
- Verification performed.
- Risks.
- Remaining work.

Then stop.

Wait before next issue if operating interactively.

---

# 7. Mandatory Constraints

Every modification must answer:

1. What issue does this solve?
2. Why is current implementation insufficient?
3. Why is this the smallest solution?
4. What files changed?
5. Regression risk?
6. Build verified?
7. Runtime verified?

If any answer cannot be provided:

Do not implement.

---

# 8. Component Instructions

## Firestore Rules

Only:

- Remove client wallet credit path.
- Remove client self approval path.

Do NOT redesign unrelated rules.

---

## Wallet

Implement:

- Backend-only credits.
- Transactional updates.
- Idempotent payment processing.

Do not change wallet UX.

---

## Payment

Implement:

Gateway

→ Backend verification

→ Wallet credit

→ Transaction

Do not redesign payment flow beyond this.

---

## FastAPI

Only convert routes using synchronous Firebase/Firestore SDK from `async def` to `def`.

Do not change async endpoints that genuinely await asynchronous work.

---

## Inventory

Wrap shared mutable updates in Firestore transactions.

Do not redesign stock model.

---

## Queue

Do NOT migrate schema now.

Only introduce abstraction if necessary.

Migration is future work.

---

## Staff Console

Only eliminate unnecessary Firestore reads.

Prefer denormalized fields.

---

## User Console

Only optimize queue listeners and history when assigned.

---

# 9. Verification Gate

A task is NOT complete until:

- Build succeeds.
- No runtime errors.
- Issue resolved.
- No regressions found.

---

# 10. Stop Conditions

Immediately stop if:

- More than one subsystem must change unexpectedly.
- Existing architecture must be redesigned.
- Schema migration becomes necessary unexpectedly.
- Requirements conflict.

Produce report instead of guessing.

---

# 11. Definition of Done

A task is complete only when:

✓ Root cause validated

✓ Smallest fix implemented

✓ Build verified

✓ Runtime verified

✓ Regression checked

✓ Report generated

Only then move to the next task.
