"""
Firebase Admin SDK Initialization — Fail-Fast with Multi-Mode Support.

This module is responsible for initializing the Firebase Admin SDK and the Firestore
client exactly once. It operates in one of three execution modes:

  A. EMULATOR MODE  — When FIRESTORE_EMULATOR_HOST is set.
                      No GCP credentials required.
                      Used for: local integration testing.

  B. LOCAL ADC MODE — When GOOGLE_APPLICATION_CREDENTIALS is set, or when gcloud
                      Application Default Credentials are available.
                      Used for: local development against live Firebase.

  C. CLOUD RUN MODE — When running inside Cloud Run / GCE.
                      The runtime service account metadata server is used.
                      No configuration required.

Fail-Fast Contract:
  If no valid Firestore backend can be established, this module raises a
  RuntimeError with a descriptive message, aborting the application startup.
  The application MUST NOT enter a "Zombie State" where startup succeeds but
  Firestore operations fail at runtime.
"""

import os
import sys
import logging
from dotenv import load_dotenv

# Load .env from the admin_console root (one level above backend/)
_BASE_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
load_dotenv(os.path.join(_BASE_DIR, ".env"))

import firebase_admin
from firebase_admin import credentials, firestore

logger = logging.getLogger("canteen-api.firebase")


# ──────────────────────────────────────────────────────────────────────────────
# Internal: Execution Mode Detection & Credential Priority
# ──────────────────────────────────────────────────────────────────────────────

def _detect_mode() -> tuple[str, str | None]:
    """
    Determines credential mode by strict priority:
      1. FIRESTORE_EMULATOR_HOST (local emulator mode)
      2. GOOGLE_APPLICATION_CREDENTIALS (explicit local service account file)
      3. Cloud Run metadata server
      4. Application Default Credentials (gcloud auth application-default login)

    Returns:
        (mode_name, key_file_path_if_any)
    """
    if os.environ.get("FIRESTORE_EMULATOR_HOST"):
        return ("emulator", None)

    explicit_key = os.environ.get("GOOGLE_APPLICATION_CREDENTIALS")
    if explicit_key:
        if not os.path.exists(explicit_key):
            raise RuntimeError(
                f"GOOGLE_APPLICATION_CREDENTIALS is set to '{explicit_key}', but the file does not exist."
            )
        return ("service_account", explicit_key)

    if os.environ.get("K_SERVICE") or os.environ.get("CLOUD_RUN_SERVICE"):
        return ("cloud_run", None)

    return ("adc", None)


def _print_startup_banner(mode: str, project_id: str, credential_source: str) -> None:
    """Emits a structured startup diagnostic block to stdout."""
    env = os.environ.get("ENV", "dev")

    banner = f"""
╔══════════════════════════════════════════════════════╗
║          CANTEEN API — STARTUP DIAGNOSTICS           ║
╠══════════════════════════════════════════════════════╣
║  Environment     : {env:<34}║
║  Firestore Mode  : {mode:<34}║
║  Firebase Project: {project_id:<34}║
║  Credential Src  : {credential_source:<34}║"""

    banner += """
╚══════════════════════════════════════════════════════╝"""

    logger.info(banner)


# ──────────────────────────────────────────────────────────────────────────────
# Internal: Firebase Admin SDK Initialization
# ──────────────────────────────────────────────────────────────────────────────

def _initialize_firebase() -> None:
    """
    Initializes the Firebase Admin SDK (singleton guard).

    Credential resolution follows strict priority:
      1. FIRESTORE_EMULATOR_HOST -> Emulator Mode (AnonymousCredentials)
      2. GOOGLE_APPLICATION_CREDENTIALS -> Service Account Certificate
      3. Cloud Run / GCE metadata server
      4. Application Default Credentials (gcloud auth application-default login)

    Raises:
        RuntimeError: If no valid credentials can be found.
    """
    if firebase_admin._apps:
        return  # Already initialized — singleton guard.

    mode, key_path = _detect_mode()
    project_id = os.environ.get("GCLOUD_PROJECT") or os.environ.get("GOOGLE_CLOUD_PROJECT") or "canteen-app-e1c8d"

    try:
        if mode == "emulator":
            # Priority 1: Local Firestore emulator (no GCP authentication required)
            from google.auth.credentials import AnonymousCredentials
            firebase_admin.initialize_app(AnonymousCredentials(), options={"projectId": project_id})
            credential_source = f"Firestore Emulator ({os.environ.get('FIRESTORE_EMULATOR_HOST')})"

        elif mode == "service_account":
            # Priority 2: Explicit service account key file path
            cred = credentials.Certificate(key_path)
            firebase_admin.initialize_app(cred)
            credential_source = f"Service Account Key: {os.path.basename(key_path)}"

        elif mode == "cloud_run":
            # Cloud Run service account metadata server
            firebase_admin.initialize_app(options={"projectId": project_id})
            credential_source = "Cloud Run Service Account (Metadata Server)"
        else:
            # Priority 4: Application Default Credentials (gcloud / ADC)
            import google.auth
            from google.auth.exceptions import DefaultCredentialsError

            try:
                google.auth.default()
            except DefaultCredentialsError as adc_err:
                raise RuntimeError(
                    "No valid Google credentials found. Application Default Credentials are not configured.\n\n"
                    "Configure credentials using one of the following priority methods:\n"
                    "  1. Explicit Service Account: Set GOOGLE_APPLICATION_CREDENTIALS=C:\\path\\to\\service_account.json\n"
                    "  2. Application Default Credentials: Run 'gcloud auth application-default login'\n"
                ) from adc_err

            firebase_admin.initialize_app(options={"projectId": project_id})
            credential_source = "Application Default Credentials (gcloud / ADC)"

        _print_startup_banner(mode=mode, project_id=project_id, credential_source=credential_source)

    except Exception as exc:
        _emit_initialization_failure(mode, exc)
        raise RuntimeError(
            f"Firebase Admin SDK initialization failed in mode '{mode}': {exc}"
        ) from exc


# ──────────────────────────────────────────────────────────────────────────────
# Internal: Firestore Client Initialization
# ──────────────────────────────────────────────────────────────────────────────

def _initialize_firestore() -> "firestore.Client":
    """
    Initializes and returns the Firestore client.

    Raises:
        RuntimeError: If the Firestore client cannot be created. This aborts startup.
    """
    try:
        client = firestore.client()
        logger.info("[Firebase] Firestore client initialized successfully.")
        return client
    except Exception as exc:
        _emit_initialization_failure(_detect_mode()[0], exc)
        raise RuntimeError(
            f"Firestore client initialization failed: {exc}\n\n"
            "Resolve this by choosing one of the following:\n"
            "\n"
            "  [Option A] Live Firestore via Application Default Credentials (ADC):\n"
            "    1. Install Google Cloud SDK: https://cloud.google.com/sdk/docs/install\n"
            "    2. Authenticate:             gcloud auth application-default login\n"
            "    3. Restart the backend:      python -m uvicorn main:app --reload\n"
            "\n"
            "  [Option B] Service Account Key File (CI / Offline ADC):\n"
            "    1. Download service account key from Firebase Console -> Project Settings -> Service Accounts\n"
            "    2. Set env variable: set GOOGLE_APPLICATION_CREDENTIALS=C:\\path\\to\\key.json\n"
            "    3. Restart the backend: python -m uvicorn main:app --reload\n"
        ) from exc


def _emit_initialization_failure(mode, exc: Exception) -> None:
    """Emits a diagnostic error block to stderr."""
    # mode may be a tuple (mode_name, key_path) from _detect_mode(), extract the string
    mode_str = mode[0] if isinstance(mode, tuple) else str(mode)
    separator = "═" * 54
    msg = (
        f"\n╔{separator}╗\n"
        f"║       FATAL: FIRESTORE INITIALIZATION FAILED         ║\n"
        f"╠{separator}╣\n"
        f"║  Mode      : {mode_str:<40}║\n"
        f"║  Error     : {str(exc)[:40]:<40}║\n"
        f"╠{separator}╣\n"
        f"║  The backend cannot start without a valid Firestore  ║\n"
        f"║  connection. See startup instructions below.         ║\n"
        f"╚{separator}╝\n"
    )
    print(msg, file=sys.stderr, flush=True)


# ──────────────────────────────────────────────────────────────────────────────
# Module-Level Initialization (Fail-Fast)
# ──────────────────────────────────────────────────────────────────────────────
#
# This block runs exactly once when config.firebase is first imported (which is
# triggered by `import config.firebase` in main.py, before any FastAPI
# middleware, router, or lifespan handler is registered).
#
# If either _initialize_firebase() or _initialize_firestore() raises a
# RuntimeError, the Python process aborts with a non-zero exit code and a clear
# diagnostic message. Uvicorn will not start listening for requests.
#
_initialize_firebase()
db: firestore.Client = _initialize_firestore()