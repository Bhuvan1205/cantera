#!/usr/bin/env bash
# ==============================================================================
# deploy_cloud_run.sh — Deploy FastAPI backend to Google Cloud Run (P-02, P-12)
# ==============================================================================
set -euo pipefail

PROJECT_ID="${GCP_PROJECT_ID:-$(gcloud config get-value project)}"
REGION="${GCP_REGION:-asia-south1}"
SERVICE_NAME="${SERVICE_NAME:-canteen-api}"
SERVICE_ACCOUNT="canteen-api-sa@${PROJECT_ID}.iam.gserviceaccount.com"
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib/admin_console/backend" && pwd)"

echo "Deploying ${SERVICE_NAME} to Cloud Run..."
echo "Project: ${PROJECT_ID} | Region: ${REGION} | SA: ${SERVICE_ACCOUNT}"
echo "Source: ${SOURCE_DIR}"

gcloud run deploy "${SERVICE_NAME}" \
  --source="${SOURCE_DIR}" \
  --project="${PROJECT_ID}" \
  --region="${REGION}" \
  --service-account="${SERVICE_ACCOUNT}" \
  --ingress=all \
  --allow-unauthenticated \
  --min-instances=1 \
  --max-instances=20 \
  --cpu=1 \
  --memory=512Mi \
  --timeout=30s \
  --set-env-vars="ALLOWED_ORIGINS=*,ENV=prod" \
  --update-secrets="RAZORPAY_KEY_SECRET=RAZORPAY_KEY_SECRET:latest"

echo "Deployment complete. Inspect service status with: gcloud run services describe ${SERVICE_NAME} --region=${REGION}"
