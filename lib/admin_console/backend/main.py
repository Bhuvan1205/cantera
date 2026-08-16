import os
from contextlib import asynccontextmanager
from fastapi import FastAPI, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

# ── Bootstrap ────────────────────────────────────────────────────────────────
# settings MUST be imported first: it calls load_dotenv(), which populates
# os.environ with GOOGLE_APPLICATION_CREDENTIALS (and other vars) from .env.
# config.firebase reads GOOGLE_APPLICATION_CREDENTIALS via os.environ at
# module-import time, so it must run AFTER load_dotenv has populated the env.
from config.settings import ALLOWED_ORIGINS, ENV

# Importing firebase triggers fail-fast initialization. If Firestore cannot be
# initialized (bad/missing credentials), this raises RuntimeError immediately,
# before FastAPI registers any middleware or route.
import config.firebase  # noqa: F401
import config.firebase  # noqa: F401
from config.logging import setup_logging

setup_logging()

from auth.dependencies import get_current_admin


# ── Lifespan: Startup Probe ───────────────────────────────────────────────────
@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    FastAPI lifespan handler.

    On startup:
      - Verifies the Firestore client (db) is non-None and responsive.
      - If Firestore is unreachable within 10 seconds, aborts startup with a clear error.

    This is the final safety net after module-level fail-fast initialization.
    It guarantees the application never enters a "Zombie State" where startup
    succeeds but all business requests fail at runtime.
    """
    import asyncio
    import logging
    from config.firebase import db

    _log = logging.getLogger("canteen-api.lifespan")

    # ── Firestore Liveness Probe ──────────────────────────────────────────────
    if db is None:
        raise RuntimeError(
            "Lifespan startup probe failed: Firestore client is None. "
            "Check FIRESTORE_EMULATOR_HOST or GOOGLE_APPLICATION_CREDENTIALS."
        )

    async def _probe():
        loop = asyncio.get_event_loop()
        await loop.run_in_executor(None, lambda: db.collection("_startup_probe_").limit(1).get())

    try:
        await asyncio.wait_for(_probe(), timeout=30.0)
        _log.info("[Lifespan] Firestore liveness probe PASSED. Backend is ready.")
    except asyncio.TimeoutError:
        raise RuntimeError(
            "Lifespan startup probe TIMED OUT after 30s — Firestore unreachable.\n"
            "Ensure you have internet access and ADC credentials are valid."
        )
    except Exception as exc:
        err_type = type(exc).__name__
        err_msg = str(exc).lower()
        if "unavailable" in err_msg or "connection" in err_msg:
            raise RuntimeError(
                f"Lifespan startup probe FAILED — Firestore unreachable: {exc}\n"
                "Ensure ADC credentials are valid and you are connected to the internet."
            ) from exc
        # Non-fatal: collection not found or empty — emulator is reachable.
        _log.info(f"[Lifespan] Firestore liveness probe PASSED (non-fatal: {err_type}: {exc}).")

    yield  # Application is running and accepting requests.

    # ── Shutdown ──────────────────────────────────────────────────────────────
    _log.info("[Lifespan] Application shutdown complete.")


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
    lifespan=lifespan,
)

from utils.idempotency import IdempotencyMiddleware
from utils.app_check import AppCheckMonitoringMiddleware

# ── CORS ──────────────────────────────────────────────────────────────────────
# Allows configured Flutter Web and React/Vite frontend origins to call the API.
app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Idempotency ───────────────────────────────────────────────────────────────
# Enforces safe retries on mutating POST/PUT/PATCH endpoints using Idempotency-Key
app.add_middleware(IdempotencyMiddleware)

# ── App Check (Monitoring & Telemetry) ────────────────────────────────────────
# Logs App Check validation results without blocking requests during phased rollout
app.add_middleware(AppCheckMonitoringMiddleware)




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
from features.recommendations.router import router as recommendations_router
from features.foodpulse.router import router as foodpulse_router

app.include_router(auth_router,            prefix="/api/auth",            tags=["Auth"])
app.include_router(users_router,           prefix="/api/users",           tags=["Users"])
app.include_router(inventory_router,       prefix="/api/inventory",       tags=["Inventory"])
app.include_router(orders_router,          prefix="/api/orders",          tags=["Orders"])
app.include_router(wallet_router,          prefix="/api/wallet",          tags=["Wallet"])
app.include_router(recommendations_router, prefix="/api/recommendations", tags=["Recommendations"])
app.include_router(foodpulse_router,       prefix="/foodpulse",           tags=["FoodPulse"])


# Only serve the Flutter Web build as static files in non-dev environments
# (e.g. a self-contained Cloud Run deployment where the build artifact is bundled).
# In dev, Flutter runs its own dev server independently via `flutter run`.
# If build/web exists on a dev machine from a prior `flutter build web`, mounting it
# here would silently intercept preflight OPTIONS requests before CORSMiddleware
# can respond, stripping CORS headers and causing browser CORS failures.
if ENV != "dev":
    build_web_path = os.path.abspath(
        os.path.join(os.path.dirname(__file__), "../../../build/web")
    )
    if os.path.exists(build_web_path):
        app.mount(
            "/",
            StaticFiles(directory=build_web_path, html=True),
            name="flutter",
        )
