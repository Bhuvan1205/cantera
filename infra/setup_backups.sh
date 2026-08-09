#!/usr/bin/env bash
# ==============================================================================
# Setup Firestore PITR and Automated Scheduled Backups to GCS (P-18)
# ==============================================================================

set -euo pipefail

PROJECT_ID="${1:-canteen-app-e1c8d}"
LOCATION="asia-south1"
BUCKET_NAME="${PROJECT_ID}-firestore-backups"

echo "=== 1. Enable Firestore Point-in-Time Recovery (PITR) ==="
gcloud firestore databases update \
  --project="${PROJECT_ID}" \
  --point-in-time-recovery=ENABLE

echo "=== 2. Create Storage Bucket for Nightly Exports ==="
gcloud storage buckets create "gs://${BUCKET_NAME}" \
  --project="${PROJECT_ID}" \
  --location="${LOCATION}" \
  --uniform-bucket-level-access || echo "Bucket already exists"

echo "=== 3. Assign Export Permissions to Firestore Service Agent ==="
FIRESTORE_SA="service-${PROJECT_ID}@gcp-sa-firestore.iam.gserviceaccount.com"
gcloud storage buckets add-iam-policy-binding "gs://${BUCKET_NAME}" \
  --member="serviceAccount:${FIRESTORE_SA}" \
  --role="roles/storage.objectAdmin" || true

echo "=== 4. Setup Daily Scheduled Firestore Export via Cloud Scheduler ==="
gcloud scheduler jobs create http firestore-daily-backup \
  --project="${PROJECT_ID}" \
  --location="${LOCATION}" \
  --schedule="0 2 * * *" \
  --time-zone="Asia/Kolkata" \
  --uri="https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default):exportDocuments" \
  --http-method=POST \
  --message-body="{\"outputUriPrefix\":\"gs://${BUCKET_NAME}/exports/\"}" \
  --oauth-service-account-email="canteen-api-sa@${PROJECT_ID}.iam.gserviceaccount.com" || echo "Scheduler job already exists"

echo "Firestore backup architecture configured successfully."
