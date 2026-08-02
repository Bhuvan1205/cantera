import os
import firebase_admin
from firebase_admin import credentials, firestore

# ── Resolve the path to the service account key ───────────────────────────────
# firebase.py lives at: backend/config/firebase.py
# Key lives at:         admin_console/firebase_secret_key.json
# So we go up two levels: config/ → backend/ → admin_console/
_CONFIG_DIR = os.path.dirname(os.path.abspath(__file__))
_BACKEND_DIR = os.path.dirname(_CONFIG_DIR)
_ADMIN_CONSOLE_DIR = os.path.dirname(_BACKEND_DIR)
_KEY_PATH = os.path.join(_ADMIN_CONSOLE_DIR, "firebase_secret_key.json")


def _initialize_firebase() -> None:
    """Initialize the Firebase Admin SDK exactly once (singleton guard)."""
    if firebase_admin._apps:
        return  # already initialised — skip
    cred = credentials.Certificate(_KEY_PATH)
    firebase_admin.initialize_app(cred)


# Run on first import so every module that does `from config.firebase import db`
# is guaranteed to get a live Firestore client.
_initialize_firebase()

db: firestore.Client = firestore.client()