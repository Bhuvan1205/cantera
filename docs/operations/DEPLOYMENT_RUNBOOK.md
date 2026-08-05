# Deployment Runbook

Step-by-step instructions for deploying backend, Firestore security rules, Cloud Functions, and Flutter clients to staging and production.

---

## 1. Project Lifecycle & CI/CD Pipeline

The project is currently in **Feature Development Mode (EEL-001)**.
- **Continuous Integration (`ci.yml`):** Automatically executes on all PRs and pushes to `main` and `feature/**` branches. Validates backend `pytest`, `flutter analyze`, `flutter test`, and Firestore security rules. Does **not** deploy or interact with Google Cloud.
- **Continuous Deployment (`cd.yml`):** Automated deployment on push is **disabled** during development mode. CD is triggered exclusively via:
  1. Manual execution via GitHub Actions (`workflow_dispatch`) with environment selection (`staging` or `production`).
  2. Release tag creation (`v*`).

---

## 2. Automated Deployment via GitHub Actions (CD Workflow)

### Triggering Manual Staging/Production Deployment
1. Navigate to repository **Actions** tab on GitHub.
2. Select **Continuous Deployment (CD) - Cloud Run**.
3. Click **Run workflow**, choose branch and target environment (`staging` or `production`).

### Triggering via Release Tag
```bash
git tag -a v2.1.0 -m "Release v2.1.0: feature release"
git push origin v2.1.0
```

---

## 3. Manual CLI Deployment (Direct Cloud SDK)

### Backend Deployment (Cloud Run)
```bash
# Set GCP Project
gcloud config set project canteen-app-e1c8d

# Submit container build to Cloud Build
gcloud builds submit --tag gcr.io/canteen-app-e1c8d/cantora-backend lib/admin_console/backend

# Deploy to Cloud Run
gcloud run deploy cantora-backend \
  --image gcr.io/canteen-app-e1c8d/cantora-backend \
  --platform managed \
  --region asia-south1 \
  --allow-unauthenticated \
  --min-instances 0 \
  --max-instances 10 \
  --set-env-vars FIREBASE_PROJECT_ID=canteen-app-e1c8d
```

### Health Check Verification
```bash
curl -f https://cantora-backend-<hash>-el.a.run.app/health
# Expected: {"status": "ok"}
```

---

## 4. Firestore Security Rules Deployment

```bash
# Validate rules against local emulator first
firebase emulators:exec --only firestore "npm test"

# Deploy rules to production
firebase deploy --only firestore:rules
```

---

## 5. Cloud Functions Deployment

```bash
firebase deploy --only functions
```

---

## 6. Flutter Web / Mobile Builds

### Web (Counter Terminals)
```bash
flutter build web --release
firebase deploy --only hosting
```

### Android APK / App Bundle
```bash
flutter build appbundle --release
```

---

## Cross-References
- [Environments](file:///docs/operations/ENVIRONMENTS.md)
- [Incident Response](file:///docs/operations/INCIDENT_RESPONSE.md)
- [Testing Standards](file:///docs/engineering/TESTING_STANDARDS.md)
