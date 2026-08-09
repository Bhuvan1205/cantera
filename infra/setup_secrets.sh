#!/usr/bin/env bash
# ==============================================================================
# setup_secrets.sh — Google Cloud Secret Manager Setup (P-13)
# ==============================================================================
set -euo pipefail

PROJECT_ID="${GCP_PROJECT_ID:-$(gcloud config get-value project)}"
SERVICE_ACCOUNT="canteen-api-sa@${PROJECT_ID}.iam.gserviceaccount.com"

echo "Setting up Secret Manager for project: ${PROJECT_ID}"

# 1. Enable Secret Manager API
gcloud services enable secretmanager.googleapis.com --project="${PROJECT_ID}"

# 2. Create RAZORPAY_KEY_SECRET secret (if it does not already exist)
if ! gcloud secrets describe RAZORPAY_KEY_SECRET --project="${PROJECT_ID}" >/dev/null 2>&1; then
  echo "Creating secret RAZORPAY_KEY_SECRET in Secret Manager..."
  # Prompt for secret or read from environment variable RAZORPAY_SECRET_INPUT
  if [ -n "${RAZORPAY_SECRET_INPUT:-}" ]; then
    echo -n "${RAZORPAY_SECRET_INPUT}" | gcloud secrets create RAZORPAY_KEY_SECRET \
      --replication-policy="automatic" \
      --data-file=- \
      --project="${PROJECT_ID}"
  else
    echo "Placeholder secret created. Add live secret version with:"
    echo "  echo -n 'YOUR_SECRET' | gcloud secrets create RAZORPAY_KEY_SECRET --data-file=-"
  fi
else
  echo "Secret RAZORPAY_KEY_SECRET already exists."
fi

# 3. Grant Secret Accessor role to the Cloud Run Service Account
echo "Granting secretAccessor role to ${SERVICE_ACCOUNT}..."
gcloud secrets add-iam-policy-binding RAZORPAY_KEY_SECRET \
  --member="serviceAccount:${SERVICE_ACCOUNT}" \
  --role="roles/secretmanager.secretAccessor" \
  --project="${PROJECT_ID}"

echo "Secret Manager setup complete."
