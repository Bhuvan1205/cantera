# Incident Response & On-Call Playbook

This runbook guides engineers through triaging, mitigating, and resolving live production incidents.

---

## 1. Severity Definitions

| Severity | Definition | SLA Response Time |
| :--- | :--- | :--- |
| **SEV-1** | System down; checkout failing for all users; data corruption. | $< 15\text{ mins}$ |
| **SEV-2** | Partial degradation (e.g. one counter token routing down; payment gateway latency). | $< 1\text{ hour}$ |
| **SEV-3** | Minor non-blocking UI bug; non-critical telemetry issue. | $< 24\text{ hours}$ |

---

## 2. Immediate Triage Checklist (SEV-1 / SEV-2)

### Step 1: Check Cloud Run Status
```bash
gcloud run services describe cantora-backend --region=asia-south1
```

### Step 2: Inspect Cloud Logging for Fatal Errors
```bash
gcloud logging read 'resource.type="cloud_run_revision" AND severity>=ERROR' --limit=20
```

### Step 3: Rollback Deployment (If Incident Caused by Recent Release)
```bash
# Roll back to previous known healthy revision
gcloud run services update-traffic cantora-backend \
  --to-revisions=<PREVIOUS_REVISION_NAME>=100 \
  --region=asia-south1
```

---

## 3. Post-Incident Review (PIR)
Within 48 hours of resolving any SEV-1 or SEV-2 incident, a formal PIR document must be published covering:
1. Root cause summary.
2. Timeline of events.
3. Impacted users and transaction volume.
4. Corrective and preventive action items.

---

## Cross-References
- [Monitoring](file:///docs/operations/MONITORING.md)
- [Backup Recovery](file:///docs/operations/BACKUP_RECOVERY.md)
