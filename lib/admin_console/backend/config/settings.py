import os
from dotenv import load_dotenv

# Load .env from the admin_console root (one level above backend/)
_BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
load_dotenv(os.path.join(_BASE_DIR, ".env"))

# ── Server ────────────────────────────────────────────────────────────────────
PORT: int = int(os.getenv("PORT", 8000))

# ── CORS ─────────────────────────────────────────────────────────────────────
# Comma-separated list of allowed origins.
# Streamlit runs on 8501 by default; add your deployed frontend URL in .env.
_raw_origins = os.getenv("ALLOWED_ORIGINS", "http://localhost:8501")
ALLOWED_ORIGINS: list[str] = [o.strip() for o in _raw_origins.split(",")]

# ── Razorpay ──────────────────────────────────────────────────────────────────
# Required for HMAC-SHA256 payment signature verification.
# Set RAZORPAY_KEY_SECRET in .env before accepting live Razorpay payments.
# Mock gateway payments do NOT require this key.
RAZORPAY_KEY_SECRET: str = os.getenv("RAZORPAY_KEY_SECRET", "")
