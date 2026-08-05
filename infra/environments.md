# Environment Strategy & Multi-Tier Architecture (P-16)

## 1. Overview
The Cantora architecture uses three distinct environments to guarantee separation between testing, staging, and production workloads.

| Environment | GCP Project ID | Cloud Run Service | Flutter Target | Purpose |
|-------------|----------------|-------------------|----------------|---------|
| **Development** | Local / Emulator | `http://localhost:8000` (or `10.0.2.2:8000`) | Debug builds | Local development and unit tests |
| **Staging** | `canteen-app-staging` | `canteen-api-staging` | Internal QA APK/TestFlight | Pre-release QA and smoke testing |
| **Production** | `canteen-app-e1c8d` | `canteen-api` | Release builds (Play Store / App Store) | Live production traffic |

---

## 2. Flutter Build-Time Configuration (`--dart-define`)

All environment-specific URLs and public identifiers are injected at compile time:

### Development (Local Emulator)
```bash
flutter run \
  --dart-define=ENV=dev \
  --dart-define=BACKEND_URL=http://10.0.2.2:8000 \
  --dart-define=RAZORPAY_KEY_ID=rzp_test_dev123
```

### Staging
```bash
flutter run \
  --dart-define=ENV=staging \
  --dart-define=BACKEND_URL=https://canteen-api-staging-xxxx.a.run.app \
  --dart-define=RAZORPAY_KEY_ID=rzp_test_staging123
```

### Production Release
```bash
flutter build apk --release \
  --dart-define=ENV=prod \
  --dart-define=BACKEND_URL=https://canteen-api-61569697681.asia-south1.run.app \
  --dart-define=RAZORPAY_KEY_ID=rzp_live_prod123
```

---

## 3. Secret Management
- **Razorpay Key ID**: Public, injected via `--dart-define`.
- **Razorpay Key Secret**: Sensitive, stored in GCP Secret Manager (`RAZORPAY_KEY_SECRET`), mounted at runtime in Cloud Run.
- **Service Account Credentials**: Authenticated automatically via Google Cloud Application Default Credentials (ADC) and Workload Identity Federation in CI/CD.
