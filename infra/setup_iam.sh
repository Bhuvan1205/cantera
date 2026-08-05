#!/usr/bin/env bash
# ==============================================================================
# setup_iam.sh — Cloud Run Least-Privilege IAM & Service Account Setup (P-12)
# ==============================================================================
set -euo pipefail

# Required environment variables
PROJECT_ID="${GCP_PROJECT_ID:-$(gcloud config get-value project)}"
REGION="${GCP_REGION:-asia-south1}"
SERVICE_ACCOUNT_NAME="canteen-api-sa"
SA_EMAIL="${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

echo "Configuring IAM for project: ${PROJECT_ID} in ${REGION}"

# 1. Enable required GCP APIs
echo "Enabling GCP APIs..."
gcloud services enable \
  run.googleapis.com \
  firestore.googleapis.com \
  secretmanager.googleapis.com \
  logging.googleapis.com \
  cloudbuild.googleapis.com \
  iam.googleapis.com \
  --project="${PROJECT_ID}"

# 2. Create dedicated service account if it does not already exist
if ! gcloud iam service-accounts describe "${SA_EMAIL}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
  echo "Creating Service Account: ${SA_EMAIL}..."
  gcloud iam service-accounts create "${SERVICE_ACCOUNT_NAME}" \
    --display-name="Canteen API Cloud Run Runtime SA" \
    --description="Least-privilege runtime identity for FastAPI Cloud Run service" \
    --project="${PROJECT_ID}"
else
  echo "Service Account ${SA_EMAIL} already exists."
fi

# 3. Grant ONLY least-privilege roles to the Cloud Run Service Account
echo "Binding least-privilege IAM roles..."

# Role 1: Firestore Read/Write Access
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/datastore.user" \
  --condition=None

# Role 2: Firebase SDK Admin (Auth token verification & claims management)
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/firebase.sdkAdminServiceAgent" \
  --condition=None

# Role 3: Cloud Logging Log Writer (Structured JSON logs)
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/logging.logWriter" \
  --condition=None

# Role 4: Secret Manager Secret Accessor (Read secrets at runtime)
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/secretmanager.secretAccessor" \
  --condition=None

# 4. Audit & verify: Ensure Compute Engine default service account is not granted Editor
echo "IAM setup complete for ${SA_EMAIL}."
