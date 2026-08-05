# Cloud Architecture

This document describes the Google Cloud Platform (GCP) and Firebase infrastructure backing Cantora.

---

## Infrastructure Topology

```
                  ┌─────────────────────────────────────┐
                  │           Firebase Auth             │
                  │   (Identity & Custom Claims RBAC)   │
                  └──────────────────┬──────────────────┘
                                     │
                                     │ JWT Verification
                                     ▼
┌──────────────┐             ┌────────────────────────┐             ┌──────────────────┐
│ Cloud CDN &  ├────────────>│  Google Cloud Run      ├────────────>│ Cloud Firestore  │
│ Cloud Armor  │  HTTPS      │  (FastAPI Backend)     │ Admin SDK   │ (Multi-Region)   │
└──────────────┘             └───────────┬────────────┘             └────────┬─────────┘
                                         │                                   │
                                         │ Telemetry                         │ Event Triggers
                                         ▼                                   ▼
                             ┌────────────────────────┐             ┌──────────────────┐
                             │ Cloud Logging & Trace  │             │ Cloud Functions  │
                             └────────────────────────┘             └────────┬─────────┘
                                                                             │
                                                                             │ Push Notifications
                                                                             ▼
                                                                    ┌──────────────────┐
                                                                    │ Firebase Cloud   │
                                                                    │ Messaging (FCM)  │
                                                                    └──────────────────┘
```

---

## GCP Services & Configuration

### 1. Google Cloud Run (FastAPI Backend)
- **Container Base:** `python:3.11-slim`
- **Autoscaling:**
  - Min Instances: 0 (scale to zero during idle hours)
  - Max Instances: 10 (capacity for 1,000+ concurrent requests)
  - Concurrency: 80 requests per container instance
  - Memory: 512 MiB / 1 vCPU
- **Environment Variables:**
  - `FIREBASE_PROJECT_ID`: `canteen-app-e1c8d`
  - `RAZORPAY_KEY_ID`: Configured via Secret Manager
  - `RAZORPAY_KEY_SECRET`: Configured via Secret Manager

### 2. Cloud Firestore
- **Location:** `asia-south1` (Mumbai) for minimum latency.
- **Backups:** Automated daily export to Google Cloud Storage (`gs://canteen-app-firestore-backups/`).
- **Index Management:** Defined in `firestore.indexes.json`.

### 3. Cloud Functions (2nd Gen)
- **Runtime:** Node.js 20 on Cloud Functions (v2 / Eventarc).
- **Triggers:**
  - `onOrderUpdated`: Dispatches FCM push notifications when order status advances.
  - `syncCustomClaims`: Syncs staff/admin roles from `Users` document to Firebase Auth token claims.

### 4. Cloud Operations (Monitoring & Observability)
- **Cloud Logging:** Structured JSON log output capturing request IDs, user UIDs, latency, and status codes.
- **Cloud Monitoring:** Latency percentiles ($p_{50}$, $p_{95}$, $p_{99}$), error rates, container memory/CPU utilization.
- **Alerting Policies:** Alert on $5xx > 1\%$ over 5-minute window via email and PagerDuty webhook.

---

## Cross-References
- [Deployment Runbook](file:///docs/operations/DEPLOYMENT_RUNBOOK.md)
- [Environments](file:///docs/operations/ENVIRONMENTS.md)
- [Monitoring](file:///docs/operations/MONITORING.md)
