import os
import logging
import firebase_admin
from firebase_admin import credentials, firestore

_CONFIG_DIR = os.path.dirname(os.path.abspath(__file__))
_BACKEND_DIR = os.path.dirname(_CONFIG_DIR)
_ADMIN_CONSOLE_DIR = os.path.dirname(_BACKEND_DIR)
_KEY_PATH = os.path.join(_ADMIN_CONSOLE_DIR, "firebase_secret_key.json")
_PROJECT_ID = "canteen-app-e1c8d"

logger = logging.getLogger(__name__)

def _initialize_firebase() -> None:
    """Initialize the Firebase Admin SDK safely."""
    if firebase_admin._apps:
        logger.info("Firebase Admin SDK already initialized.")
        return

    if os.path.exists(_KEY_PATH):
        logger.info(f"Firebase secret key found at {_KEY_PATH}. Initializing with Certificate.")
        try:
            cred = credentials.Certificate(_KEY_PATH)
            firebase_admin.initialize_app(cred)
            logger.info("Firebase Admin initialized successfully via Certificate.")
            return
        except Exception as e:
            logger.error(f"Failed to initialize Firebase via Certificate: {e}")
            raise

    logger.warning(f"Firebase secret key NOT found at {_KEY_PATH}. Attempting Application Default Credentials (ADC).")
    try:
        cred = credentials.ApplicationDefault()
        firebase_admin.initialize_app(cred, options={'projectId': _PROJECT_ID})
        logger.info(f"Firebase Admin initialized successfully via ADC. Connected Project: {_PROJECT_ID}")
    except Exception as e:
        logger.error(f"Failed to initialize Firebase via ADC: {e}")
        logger.error("Initialization failed. Please ensure 'gcloud auth application-default login' was run correctly.")
        raise

_initialize_firebase()

try:
    db: firestore.Client = firestore.client()
    logger.info("Firestore client created successfully.")
except Exception as e:
    logger.error(f"Failed to create Firestore client: {e}")
    raise RuntimeError(f"Backend cannot start without a valid Firestore client. Error: {e}")