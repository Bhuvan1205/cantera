from fastapi import FastAPI, Depends
from fastapi.middleware.cors import CORSMiddleware

# ── Bootstrap: importing firebase triggers _initialize_firebase() on startup ──
import config.firebase  # noqa: F401
from config.logging import setup_logging

setup_logging()

from config.settings import ALLOWED_ORIGINS
from auth.dependencies import get_current_admin

# ── App ───────────────────────────────────────────────────────────────────────
app = FastAPI(
    title="Canteen Admin Console API",
    description=(
        "Backend API for the Canteen Admin Console. "
        "Provides admin-only CRUD operations over Orders, Users, Inventory, and Wallet."
    ),
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

# ── CORS ──────────────────────────────────────────────────────────────────────
# Allows the Streamlit frontend (localhost:8501) and any configured origin to call the API.
app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── System routes ─────────────────────────────────────────────────────────────

@app.get("/health", tags=["System"])
def health_check():
    """
    Public health check. No auth required.
    Use this to verify the server is running before testing protected routes.
    """
    return {"status": "ok", "service": "canteen-admin-api", "version": "1.0.0"}


@app.get("/api/ping", tags=["System"])
def protected_ping(admin: dict = Depends(get_current_admin)):
    """
    Protected ping endpoint.
    Validates that Firebase token verification + Firestore admin check are both working.
    Returns the admin's uid on success.
    """
    return {
        "status": "ok",
        "message": "Auth guard passed — you are a verified admin.",
        "admin_uid": admin["uid"],
    }


# ── Feature routers (mounted as features are built) ───────────────────────────
from auth.router import router as auth_router
from features.users.router import router as users_router
from features.inventory.router import router as inventory_router
from features.orders.router import router as orders_router
from features.wallet.router import router as wallet_router

app.include_router(auth_router,      prefix="/api/auth",      tags=["Auth"])
app.include_router(users_router,     prefix="/api/users",     tags=["Users"])
app.include_router(inventory_router, prefix="/api/inventory", tags=["Inventory"])
app.include_router(orders_router,    prefix="/api/orders",    tags=["Orders"])
app.include_router(wallet_router,    prefix="/api/wallet",    tags=["Wallet"])
