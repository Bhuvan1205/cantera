import os
from dotenv import load_dotenv

# Load .env from the admin_console root (one level above backend/).
# settings.py is at: .../backend/config/settings.py
# dirname once  → .../backend/config
# dirname twice → .../backend
# dirname three → .../admin_console   ← where .env and firebase_secret_key.json live
_BASE_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
load_dotenv(os.path.join(_BASE_DIR, ".env"))

# ── Server ────────────────────────────────────────────────────────────────────
PORT: int = int(os.getenv("PORT", 8000))

# ── CORS ─────────────────────────────────────────────────────────────────────
# Comma-separated list of explicitly allowed origins.
#
# IMPORTANT: Do NOT add "*" (wildcard) here.
# FastAPI's CORSMiddleware sets allow_credentials=True, which means every
# Flutter Web → FastAPI request carries an Authorization: Bearer header.
# The browser CORS spec explicitly forbids "Access-Control-Allow-Origin: *"
# when "Access-Control-Allow-Credentials: true" is also present — the browser
# will reject the response regardless of the server returning 200.
#
# Flutter Web runs on localhost with a port assigned by `flutter run`.
# Default port for `flutter run -d chrome` is 8080, but it may vary.
# Add your local Flutter Web origin here or set ALLOWED_ORIGINS in .env.
_raw_origins = os.getenv(
    "ALLOWED_ORIGINS",
    "http://localhost:8080,http://localhost:5173",
)
ALLOWED_ORIGINS: list[str] = [o.strip() for o in _raw_origins.split(",")]

# ── Environment ───────────────────────────────────────────────────────────────
ENV: str = os.getenv("ENV", "dev")

# Business-day close used by order features. Defaults preserve the existing
# daily operational-maintenance boundary (18:59 UTC) without changing it.
BUSINESS_DAY_CLOSE_UTC_HOUR: int = int(os.getenv("BUSINESS_DAY_CLOSE_UTC_HOUR", "18"))
BUSINESS_DAY_CLOSE_UTC_MINUTE: int = int(os.getenv("BUSINESS_DAY_CLOSE_UTC_MINUTE", "59"))

# ── Razorpay ──────────────────────────────────────────────────────────────────
# RAZORPAY_KEY_SECRET is mounted from Google Cloud Secret Manager in production.
# RAZORPAY_KEY_ID is public and provided via environment variable.
RAZORPAY_KEY_ID: str = os.getenv("RAZORPAY_KEY_ID", "rzp_test_PLACEHOLDER")
RAZORPAY_KEY_SECRET: str = os.getenv("RAZORPAY_KEY_SECRET", "")

