# Backup & Disaster Recovery

This document details automated data backup policies, export schedules, and point-in-time recovery runbooks.

---

## 1. Automated Backup Policy
- **Frequency:** Daily automated export at 02:00 IST.
- **Storage Target:** Google Cloud Storage bucket `gs://canteen-app-firestore-backups/YYYY-MM-DD/`.
- **Retention Period:** 30 days rolling lifecycle.
- **Collections Included:** `Users`, `Menu`, `Orders`, `queues`, `wallets`, `wallet_transactions`, `pending_deposits`, `refund_requests`.

---

## 2. Manual Export Command
```bash
gcloud firestore export gs://canteen-app-firestore-backups/manual-$(date +%Y%m%d-%H%M%S) \
  --project=canteen-app-e1c8d
```

---

## 3. Restoration Procedure (Disaster Recovery)

### Step 1: Notify Operations & Set Read-Only Mode
Temporarily divert traffic or set Cloud Run instances to maintenance mode.

### Step 2: Import Backup Snapshot
```bash
gcloud firestore import gs://canteen-app-firestore-backups/<SNAPSHOT_FOLDER>/ \
  --project=canteen-app-e1c8d
```

### Step 3: Validate Restoration
1. Verify document counts across `Users`, `Orders`, and `wallets`.
2. Execute backend test suite against restored database.
3. Re-enable traffic to Cloud Run.

---

## Cross-References
- [Deployment Runbook](file:///docs/operations/DEPLOYMENT_RUNBOOK.md)
- [Incident Response](file:///docs/operations/INCIDENT_RESPONSE.md)
