import os
from dotenv import load_dotenv

# Load .env from the admin_console root (one level above backend/)
_BASE_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
load_dotenv(os.path.join(_BASE_DIR, ".env"))

# ── Server ────────────────────────────────────────────────────────────────────
PORT: int = int(os.getenv("PORT", 8000))

# ── CORS ─────────────────────────────────────────────────────────────────────
# Comma-separated list of allowed origins.
# Streamlit runs on 8501 by default; add your deployed frontend URL in .env.
_raw_origins = os.getenv("ALLOWED_ORIGINS", "http://localhost:8501,http://localhost:5000,http://127.0.0.1:5000,http://localhost:3000,http://localhost:5173")
ALLOWED_ORIGINS: list[str] = [o.strip() for o in _raw_origins.split(",")]

# ── Environment ───────────────────────────────────────────────────────────────
ENV: str = os.getenv("ENV", "dev")

# ── Razorpay ──────────────────────────────────────────────────────────────────
# RAZORPAY_KEY_SECRET is mounted from Google Cloud Secret Manager in production.
# RAZORPAY_KEY_ID is public and provided via environment variable.
RAZORPAY_KEY_ID: str = os.getenv("RAZORPAY_KEY_ID", "rzp_test_PLACEHOLDER")
RAZORPAY_KEY_SECRET: str = os.getenv("RAZORPAY_KEY_SECRET", "")

