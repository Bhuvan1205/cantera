#!/usr/bin/env bash
# ==============================================================================
# Setup GCP Billing Budget Alerts (P-19)
# ==============================================================================

set -euo pipefail

BILLING_ACCOUNT_ID="${1:-}"
PROJECT_ID="${2:-canteen-app-e1c8d}"
MONTHLY_BUDGET_INR="${3:-5000}"

if [ -z "${BILLING_ACCOUNT_ID}" ]; then
  echo "Usage: ./setup_budget_alerts.sh <BILLING_ACCOUNT_ID> [PROJECT_ID] [MONTHLY_BUDGET_INR]"
  echo "Example: ./setup_budget_alerts.sh 012345-6789AB-CDEF01 canteen-app-e1c8d 5000"
  exit 1
fi

echo "=== 1. Creating Monthly Budget Alert for INR ${MONTHLY_BUDGET_INR} ==="
gcloud billing budgets create \
  --billing-account="${BILLING_ACCOUNT_ID}" \
  --display-name="Canteen App Monthly Budget Alert" \
  --budget-amount="${MONTHLY_BUDGET_INR}INR" \
  --filter-projects="projects/${PROJECT_ID}" \
  --threshold-rule=percent=0.5,basis=current-spend \
  --threshold-rule=percent=0.8,basis=current-spend \
  --threshold-rule=percent=1.0,basis=current-spend \
  --threshold-rule=percent=1.2,basis=forecasted-spend

echo "Budget alerts successfully configured."
