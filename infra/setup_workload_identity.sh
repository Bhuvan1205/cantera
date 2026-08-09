#!/usr/bin/env bash
# ==============================================================================
# Setup Workload Identity Federation for GitHub Actions (P-15)
# No permanent JSON keys are downloaded or stored.
# ==============================================================================

set -euo pipefail

PROJECT_ID="${1:-canteen-app-e1c8d}"
GITHUB_REPO="${2:-Bhuvan1205/cantera}"
POOL_NAME="github-pool"
PROVIDER_NAME="github-provider"
SA_NAME="github-deployer"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

echo "=== 1. Enable Required APIs ==="
gcloud services enable \
  iam.googleapis.com \
  iamcredentials.googleapis.com \
  cloudresourcemanager.googleapis.com \
  artifactregistry.googleapis.com \
  run.googleapis.com \
  --project="${PROJECT_ID}"

echo "=== 2. Create Service Account for GitHub Actions ==="
gcloud iam service-accounts create "${SA_NAME}" \
  --display-name="GitHub Actions Deployer" \
  --project="${PROJECT_ID}" || echo "Service account already exists"

echo "=== 3. Assign Cloud Run Admin & Artifact Registry Writer ==="
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/run.admin"

gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/artifactregistry.writer"

gcloud iam service-accounts add-iam-policy-binding "canteen-api-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/iam.serviceAccountUser" \
  --project="${PROJECT_ID}"

echo "=== 4. Create Workload Identity Pool ==="
gcloud iam workload-identity-pools create "${POOL_NAME}" \
  --project="${PROJECT_ID}" \
  --location="global" \
  --display-name="GitHub Actions Pool" || echo "Pool already exists"

echo "=== 5. Create Workload Identity Provider ==="
gcloud iam workload-identity-pools providers create-oidc "${PROVIDER_NAME}" \
  --project="${PROJECT_ID}" \
  --location="global" \
  --workload-identity-pool="${POOL_NAME}" \
  --display-name="GitHub Provider" \
  --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository" \
  --issuer-uri="https://token.actions.githubusercontent.com" || echo "Provider already exists"

echo "=== 6. Allow GitHub Repo to Impersonate Deployer SA ==="
POOL_RESOURCE_ID=$(gcloud iam workload-identity-pools describe "${POOL_NAME}" --location="global" --project="${PROJECT_ID}" --format="value(name)")

gcloud iam service-accounts add-iam-policy-binding "${SA_EMAIL}" \
  --project="${PROJECT_ID}" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/${POOL_RESOURCE_ID}/attribute.repository/${GITHUB_REPO}"

echo "=============================================================================="
echo "Workload Identity Federation successfully configured!"
echo "Add these GitHub Secrets to your repository ($GITHUB_REPO):"
echo "  GCP_PROJECT_ID:     ${PROJECT_ID}"
echo "  GCP_WIF_PROVIDER:   ${POOL_RESOURCE_ID}/providers/${PROVIDER_NAME}"
echo "  GCP_WIF_SA:         ${SA_EMAIL}"
echo "=============================================================================="
