# Environments & Configuration

This document outlines the environment configurations and runtime separation for Cantora.

---

## Environment Matrix

| Environment | Purpose | GCP Project | Backend Base URL |
| :--- | :--- | :--- | :--- |
| **Local / Dev** | Local developer testing & emulators | Local Emulators / `canteen-app-e1c8d` | `http://127.0.0.1:8000` |
| **Staging** | Pre-production QA, smoke tests | `canteen-app-staging` | `https://staging-api.cantora.internal` |
| **Production** | Live production | `canteen-app-e1c8d` | `https://cantora-backend-<hash>.asia-south1.run.app` |

---

## Flutter Configuration
Environment switching is managed via `lib/config/app_config.dart`:

```dart
class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );
  static const bool isProduction = bool.fromEnvironment('dart.vm.product');
}
```

### Launching with Custom Environment
```bash
flutter run --dart-define=API_BASE_URL=https://cantora-backend-<hash>.asia-south1.run.app
```

---

## Secret Management
- Backend secrets (`RAZORPAY_KEY_SECRET`, `FIREBASE_ADMIN_CREDENTIALS`) are stored in Google Cloud Secret Manager.
- Secrets are mounted as environment variables during Cloud Run service execution.

---

## Cross-References
- [Deployment Runbook](file:///docs/operations/DEPLOYMENT_RUNBOOK.md)
- [Security Guidelines](file:///docs/engineering/SECURITY_GUIDELINES.md)
