# Monitoring & Health Checks

This document defines monitoring metrics, health check probes, and alerting policies.

---

## 1. Health Checks
FastAPI exposes a zero-overhead health check endpoint:
- **Endpoint:** `GET /health`
- **Response:** `200 OK` `{"status": "ok"}`
- **Cloud Run Startup & Liveness Probe:** Checks `/health` every 10 seconds.

---

## 2. Key Metrics & Service Level Indicators (SLIs)

| Metric | Target | Detection Mechanism |
| :--- | :--- | :--- |
| **Availability** | $\ge 99.9\%$ uptime | Cloud Run HTTP 2xx/3xx ratio |
| **Latency ($p_{95}$)** | $< 350\text{ ms}$ | Cloud Trace & Cloud Monitoring |
| **Checkout Latency ($p_{95}$)** | $< 800\text{ ms}$ | Cloud Trace custom span metrics |
| **Error Rate ($5xx$)** | $< 0.1\%$ | Cloud Logging metric filter |
| **Database Contention** | $< 0.5\%$ transaction retries | Firestore Admin SDK logs |

---

## 3. Cloud Monitoring Alert Policies
- **High Error Rate Alert:** Triggered if HTTP 5xx responses exceed 1% over a 5-minute rolling window.
- **High Latency Alert:** Triggered if $p_{95}$ latency exceeds 1.5 seconds for 3 consecutive intervals.
- **Notification Channels:** PagerDuty, Slack `#alerts-canteen`, and On-Call Email.

---

## Cross-References
- [Observability](file:///docs/operations/OBSERVABILITY.md)
- [Incident Response](file:///docs/operations/INCIDENT_RESPONSE.md)
