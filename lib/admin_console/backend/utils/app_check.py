import logging
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request

logger = logging.getLogger("canteen-api.app_check")

EXCLUDED_PATHS = {"/health", "/docs", "/openapi.json", "/redoc"}


class AppCheckMonitoringMiddleware(BaseHTTPMiddleware):
    """
    Stage 1 & 2 App Check Rollout (P-14):
    Inspects 'X-Firebase-AppCheck' header, validates token with Firebase Admin SDK,
    and logs verification status for telemetry without blocking requests.
    """

    async def dispatch(self, request: Request, call_next):
        if request.url.path in EXCLUDED_PATHS or request.method == "OPTIONS":
            return await call_next(request)

        token = request.headers.get("X-Firebase-AppCheck") or request.headers.get("x-firebase-appcheck")

        if not token:
            logger.info(
                f"[AppCheck] Missing token | path={request.url.path} | ip={request.client.host if request.client else 'unknown'}"
            )
        else:
            try:
                from firebase_admin import app_check
                app_check_claims = app_check.verify_token(token)
                app_id = getattr(app_check_claims, "app_id", None) or (app_check_claims.get("app_id") if isinstance(app_check_claims, dict) else "unknown")
                logger.debug(f"[AppCheck] Valid token | app_id={app_id}")
            except Exception as exc:
                logger.warning(
                    f"[AppCheck] Invalid token: {exc} | path={request.url.path} | ip={request.client.host if request.client else 'unknown'}"
                )

        return await call_next(request)
