# Deployment Runbook

Step-by-step instructions for deploying backend, Firestore security rules, Cloud Functions, and Flutter clients to production.

---

## 1. Prerequisites
- Google Cloud SDK (`gcloud`) authenticated to project `canteen-app-e1c8d`.
- Firebase CLI (`firebase`) logged in.
- Docker engine active for container builds.

---

## 2. Backend Deployment (Cloud Run)

### Build & Deploy Command
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

## 3. Firestore Security Rules Deployment

```bash
# Validate rules against local emulator first
firebase emulators:exec --only firestore "npm test"

# Deploy rules to production
firebase deploy --only firestore:rules
```

---

## 4. Cloud Functions Deployment

```bash
firebase deploy --only functions
```

---

## 5. Flutter Web / Mobile Builds

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
