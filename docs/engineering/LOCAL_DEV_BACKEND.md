# Local Development Guide: Backend Firestore Configuration

This document describes how to run the Canteen API backend locally in each of the three supported execution modes.

> [!IMPORTANT]
> The backend implements **fail-fast startup**. If Firestore cannot be initialized, the server will **not start**. It will print a descriptive error and exit. This is intentional — it prevents the "Zombie State" where the server accepts requests but crashes on every database operation.

---

## Execution Modes

| Mode | When Used | Credentials Required |
| :--- | :--- | :--- |
| **A — Emulator** | Local integration testing | None |
| **B — ADC (gcloud)** | Local dev against live Firebase | `gcloud auth application-default login` |
| **C — Service Account Key** | CI / offline ADC | `GOOGLE_APPLICATION_CREDENTIALS` env var |
| **D — Cloud Run** | Production / Staging | Automatic (metadata server) |

---

## Mode A — Local Emulator (Recommended for Development)

Use this mode when you want to develop and test locally **without touching production data**. No GCP credentials are required.

### Prerequisites

```bash
# 1. Install Node.js (required by Firebase CLI)
#    https://nodejs.org/

# 2. Install Firebase CLI
npm install -g firebase-tools

# 3. Login to Firebase CLI (one-time)
firebase login
```

### Start the Firestore Emulator

From the **repository root** (`canteen_app/`):

```bash
firebase emulators:start --only firestore
```

This starts the emulator at `127.0.0.1:9090` (as configured in `firebase.json`).

The Emulator UI is available at: [http://127.0.0.1:4000](http://127.0.0.1:4000)

### Start the Backend in Emulator Mode

Open a **new terminal** in `lib/admin_console/backend/`:

```powershell
# Windows PowerShell
$env:FIRESTORE_EMULATOR_HOST = "127.0.0.1:9090"
$env:GCLOUD_PROJECT = "canteen-app-e1c8d"
python -m uvicorn main:app --host 127.0.0.1 --port 8000 --reload
```

```bash
# macOS / Linux / Git Bash
FIRESTORE_EMULATOR_HOST=127.0.0.1:9090 GCLOUD_PROJECT=canteen-app-e1c8d \
  python -m uvicorn main:app --host 127.0.0.1 --port 8000 --reload
```

### Expected Startup Output

```
╔══════════════════════════════════════════════════════╗
║          CANTEEN API — STARTUP DIAGNOSTICS           ║
╠══════════════════════════════════════════════════════╣
║  Environment     : dev                               ║
║  Firestore Mode  : emulator                          ║
║  Firebase Project: canteen-app-e1c8d                 ║
║  Credential Src  : None (Firestore Emulator)         ║
║  Emulator Host   : 127.0.0.1:9090                    ║
╚══════════════════════════════════════════════════════╝
INFO:     Application startup complete.
```

> [!NOTE]
> The emulator starts with an **empty database**. Data written during a session is reset when the emulator restarts unless you use the `--import` / `--export-on-exit` flags.

---

## Mode B — Live Firebase via Application Default Credentials (ADC)

Use this mode when you need to test against **live production or staging Firestore data**.

### Prerequisites

1. Install Google Cloud SDK: [https://cloud.google.com/sdk/docs/install](https://cloud.google.com/sdk/docs/install)

2. Authenticate and create ADC:

```bash
gcloud auth application-default login
```

A browser window will open. Log in with your Google account that has access to the `canteen-app-e1c8d` Firebase project.

This creates an ADC credential file at:
- **Windows:** `%APPDATA%\gcloud\application_default_credentials.json`
- **macOS/Linux:** `~/.config/gcloud/application_default_credentials.json`

### Start the Backend in ADC Mode

```powershell
# Windows PowerShell — No FIRESTORE_EMULATOR_HOST needed
python -m uvicorn main:app --host 127.0.0.1 --port 8000 --reload
```

### Expected Startup Output

```
╔══════════════════════════════════════════════════════╗
║          CANTEEN API — STARTUP DIAGNOSTICS           ║
╠══════════════════════════════════════════════════════╣
║  Environment     : dev                               ║
║  Firestore Mode  : adc_implicit                      ║
║  Firebase Project: canteen-app-e1c8d                 ║
║  Credential Src  : Application Default Credentials   ║
╚══════════════════════════════════════════════════════╝
INFO:     Application startup complete.
```

> [!CAUTION]
> In this mode, all API calls read from and write to **live production Firestore**. Exercise caution when testing checkout, wallet, and inventory operations.

---

## Mode C — Service Account Key File

Use this when gcloud ADC is unavailable (e.g., CI/CD pipelines, offline environments).

### Steps

1. Download a service account key from **Firebase Console → Project Settings → Service Accounts → Generate new private key**.

2. Save the key file to a local path (never commit it to the repository).

3. Set the environment variable:

```powershell
# Windows PowerShell
$env:GOOGLE_APPLICATION_CREDENTIALS = "C:\Users\vinja\keys\canteen-app-e1c8d-sa-key.json"
python -m uvicorn main:app --host 127.0.0.1 --port 8000 --reload
```

```bash
# macOS / Linux
export GOOGLE_APPLICATION_CREDENTIALS=/home/user/keys/canteen-app-e1c8d-sa-key.json
python -m uvicorn main:app --host 127.0.0.1 --port 8000 --reload
```

> [!CAUTION]
> **Never commit service account key files to the repository.** The `.gitignore` must exclude `*.json` key files. Store secrets in Google Cloud Secret Manager in production.

---

## Mode D — Cloud Run (Automatic)

No configuration is required. Cloud Run automatically injects a service account via the GCE metadata server (`http://169.254.169.254`). The backend detects this mode automatically via the `K_SERVICE` environment variable.

---

## Fail-Fast Behavior

If no valid credentials are configured, the backend aborts immediately:

```
╔══════════════════════════════════════════════════════╗
║       FATAL: FIRESTORE INITIALIZATION FAILED         ║
╠══════════════════════════════════════════════════════╣
║  Mode      : adc_implicit                            ║
║  Error     : Your default credentials were not found ║
╠══════════════════════════════════════════════════════╣
║  The backend cannot start without a valid Firestore  ║
║  connection. See startup instructions below.         ║
╚══════════════════════════════════════════════════════╝

RuntimeError: Firestore client initialization failed: ...

  [Option A] Local Emulator (Recommended for Development):
    1. Install Firebase CLI: npm install -g firebase-tools
    2. Start the emulator:   firebase emulators:start --only firestore
    3. Set env variable:     set FIRESTORE_EMULATOR_HOST=127.0.0.1:9090
    4. Restart the backend:  python -m uvicorn main:app --reload

  [Option B] Live Firestore via Application Default Credentials (ADC):
    1. Install Google Cloud SDK: https://cloud.google.com/sdk/docs/install
    2. Authenticate:             gcloud auth application-default login
    3. Restart the backend:      python -m uvicorn main:app --reload

  [Option C] Service Account Key File (CI / Offline ADC):
    1. Download key from Firebase Console -> Project Settings -> Service Accounts
    2. Set env variable: set GOOGLE_APPLICATION_CREDENTIALS=C:\path\to\key.json
    3. Restart the backend: python -m uvicorn main:app --reload
```

---

## Quick Reference

```powershell
# Emulator mode (Windows PowerShell — recommended for daily development)
$env:FIRESTORE_EMULATOR_HOST = "127.0.0.1:9090"
$env:GCLOUD_PROJECT = "canteen-app-e1c8d"
python -m uvicorn main:app --host 127.0.0.1 --port 8000 --reload

# Verify backend is healthy
curl http://127.0.0.1:8000/health
# Expected: {"status":"ok","service":"canteen-admin-api","version":"1.0.0"}
```
