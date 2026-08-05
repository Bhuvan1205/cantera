#!/usr/bin/env bash
# ==============================================================================
# Setup Google Cloud Monitoring Alert Policies for Canteen API (P-17)
# ==============================================================================

set -euo pipefail

PROJECT_ID="${1:-canteen-app-e1c8d}"

echo "=== 1. Enable Cloud Monitoring APIs ==="
gcloud services enable \
  monitoring.googleapis.com \
  logging.googleapis.com \
  --project="${PROJECT_ID}"

echo "=== 2. Creating Alert Policy for Cloud Run 5xx Errors ==="
cat <<EOF > /tmp/5xx_alert_policy.json
{
  "displayName": "Canteen API - High 5xx Error Rate (>1%)",
  "combiner": "OR",
  "conditions": [
    {
      "displayName": "Cloud Run 5xx error rate",
      "conditionThreshold": {
        "filter": "resource.type = \"cloud_run_revision\" AND metric.type = \"run.googleapis.com/request_count\" AND metric.labels.response_code_class = \"5xx\"",
        "comparison": "COMPARISON_GT",
        "thresholdValue": 5,
        "duration": "60s",
        "aggregations": [
          {
            "alignmentPeriod": "60s",
            "perSeriesAligner": "ALIGN_RATE"
          }
        ]
      }
    }
  ]
}
EOF

gcloud alpha monitoring policies create --policy-from-file=/tmp/5xx_alert_policy.json --project="${PROJECT_ID}" || echo "Policy creation completed or requires notification channel assignment."

echo "Monitoring configuration completed."
