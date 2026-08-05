import firebase_admin
from firebase_admin import firestore


def _initialize_firebase() -> None:
    """
    Initialize the Firebase Admin SDK exactly once (singleton guard).

    Credential resolution order (Application Default Credentials):
      1. Cloud Run / GCP managed environment:
         The runtime service account is used automatically.
         No key file, no environment variable needed.
      2. Local development:
         Set GOOGLE_APPLICATION_CREDENTIALS to the path of a service account key:
           export GOOGLE_APPLICATION_CREDENTIALS="/path/to/dev-key.json"
         Or authenticate via the gcloud CLI:
           gcloud auth application-default login
      3. CI/CD (GitHub Actions):
         Workload Identity Federation injects short-lived credentials automatically.

    IMPORTANT: Never commit service account key files to the repository.
    The firebase_secret_key.json file has been revoked and must not be used.
    """
    if firebase_admin._apps:
        return  # Already initialised — skip (singleton guard)

    try:
        firebase_admin.initialize_app()
    except Exception as e:
        pass


# Run on first import so every module that does `from config.firebase import db`
# gets a client or mockable reference.
_initialize_firebase()

try:
    db: firestore.Client = firestore.client()
except Exception:
    # Graceful fallback for offline testing environments without ADC network access
    db = None