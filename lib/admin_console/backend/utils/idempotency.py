import datetime
import json
import logging
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response, JSONResponse

logger = logging.getLogger("canteen-api.idempotency")

MUTATING_METHODS = {"POST", "PUT", "PATCH"}
EXCLUDED_PATHS = {"/health", "/docs", "/openapi.json", "/redoc"}


class IdempotencyMiddleware(BaseHTTPMiddleware):
    """
    Middleware that enforces request idempotency using the Idempotency-Key header.
    Stores metadata in Firestore 'idempotency_keys' collection with a 24-hour TTL.
    """

    async def dispatch(self, request: Request, call_next):
        # Only inspect mutating HTTP requests on API routes
        if request.method not in MUTATING_METHODS or request.url.path in EXCLUDED_PATHS:
            return await call_next(request)

        idempotency_key = request.headers.get("Idempotency-Key") or request.headers.get("idempotency-key")
        if not idempotency_key:
            # Header not provided — proceed normally without idempotency caching
            return await call_next(request)

        idempotency_key = idempotency_key.strip()
        if len(idempotency_key) < 8 or len(idempotency_key) > 128:
            return JSONResponse(
                status_code=400,
                content={"detail": "Invalid Idempotency-Key header length. Must be 8-128 characters."},
            )

        from config.firebase import db

        doc_ref = db.collection("idempotency_keys").document(idempotency_key)

        try:
            doc_snap = doc_ref.get()
            if doc_snap.exists:
                data = doc_snap.to_dict() or {}
                status_val = data.get("status")

                if status_val == "in_progress":
                    return JSONResponse(
                        status_code=409,
                        content={"detail": "A request with this Idempotency-Key is currently in progress. Please retry shortly."},
                    )

                if status_val == "completed":
                    # Replay cached response
                    cached_body = data.get("response_body", "{}")
                    status_code = data.get("status_code", 200)
                    logger.info(f"Replaying idempotent response for key: {idempotency_key}")
                    return Response(
                        content=cached_body,
                        status_code=status_code,
                        media_type="application/json",
                        headers={"X-Idempotent-Replay": "true"},
                    )

            # Record lock in Firestore
            now = datetime.datetime.now(datetime.timezone.utc)
            expires_at = now + datetime.timedelta(hours=24)
            doc_ref.set({
                "key": idempotency_key,
                "status": "in_progress",
                "endpoint": request.url.path,
                "method": request.method,
                "created_at": now,
                "expires_at": expires_at,
            })

        except Exception as exc:
            logger.warning(f"Failed to check idempotency key in Firestore: {exc}. Proceeding without lock.")

        # Execute downstream request
        try:
            response = await call_next(request)

            # Only cache successful responses (2xx / 3xx)
            if response.status_code < 400:
                response_body_bytes = [section async for section in response.body_iterator]
                response_body_str = b"".join(response_body_bytes).decode("utf-8", errors="ignore")

                try:
                    doc_ref.update({
                        "status": "completed",
                        "status_code": response.status_code,
                        "response_body": response_body_str,
                        "completed_at": datetime.datetime.now(datetime.timezone.utc),
                    })
                except Exception as exc:
                    logger.warning(f"Failed to update idempotency key status to completed: {exc}")

                return Response(
                    content=response_body_str,
                    status_code=response.status_code,
                    headers=dict(response.headers),
                    media_type=response.media_type,
                )
            else:
                # Request resulted in client/server error — delete in-progress lock to permit retries
                try:
                    doc_ref.delete()
                except Exception:
                    pass
                return response

        except Exception as exc:
            # Exception during processing — remove lock so client can retry
            try:
                doc_ref.delete()
            except Exception:
                pass
            raise exc
