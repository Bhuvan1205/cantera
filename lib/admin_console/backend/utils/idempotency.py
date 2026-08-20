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
        if request.method not in MUTATING_METHODS or request.url.path in EXCLUDED_PATHS:
            return await call_next(request)

        idempotency_key = request.headers.get("Idempotency-Key") or request.headers.get("idempotency-key")
        if not idempotency_key:
            return await call_next(request)

        idempotency_key = idempotency_key.strip()
        if len(idempotency_key) < 8 or len(idempotency_key) > 128:
            return JSONResponse(status_code=400, content={"detail": "Invalid Idempotency-Key header length."})

        from config.firebase import db
        doc_ref = db.collection("idempotency_keys").document(idempotency_key)

        try:
            now = datetime.datetime.now(datetime.timezone.utc)
            expires_at = now + datetime.timedelta(hours=24)
            # Atomic create. Raises AlreadyExists if someone else beat us to it.
            doc_ref.create({
                "key": idempotency_key,
                "status": "in_progress",
                "endpoint": request.url.path,
                "method": request.method,
                "created_at": now,
                "expires_at": expires_at,
            })
            # SUCCESS - exactly ONE thread will reach here for a given idempotency key.
        except Exception as exc:
            err_msg = str(exc).lower()
            is_already_exists = ("already exists" in err_msg) or ("409" in err_msg) or (type(exc).__name__ == "AlreadyExists")
            
            if is_already_exists:
                # The lock is already held by someone else, or was recently completed.
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
                        elif status_val == "completed":
                            cached_body = data.get("response_body", "{}")
                            status_code = data.get("status_code", 200)
                            return Response(
                                content=cached_body,
                                status_code=status_code,
                                media_type="application/json",
                                headers={"X-Idempotent-Replay": "true"},
                            )
                except Exception as inner_exc:
                    logger.error(f"Error reading existing idempotency lock: {inner_exc}")
                
                # IMPORTANT: If the document no longer exists (e.g. the other thread just failed and deleted it),
                # OR we got an error reading it, we MUST return 409 to prevent duplicate execution bypassing the lock.
                # Do NOT fall through.
                return JSONResponse(
                    status_code=409, 
                    content={"detail": "Idempotency lock state is resolving. Please retry shortly."}
                )
            else:
                logger.error(f"Failed to create idempotency lock due to DB error: {exc}")
                # Fail closed on unexpected DB errors (e.g. permission denied, network failure)
                return JSONResponse(status_code=500, content={"detail": "Database error acquiring idempotency lock."})

        # --- EXECUTE DOWNSTREAM REQUEST (Exactly 1 thread per idempotency key) ---
        try:
            response = await call_next(request)

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
                except Exception:
                    pass

                return Response(
                    content=response_body_str,
                    status_code=response.status_code,
                    headers=dict(response.headers),
                    media_type=response.media_type,
                )
            else:
                # If the business logic fails (e.g. validation error, insufficient funds, stock empty),
                # we DELETE the lock so the client can legitimately retry later.
                try:
                    doc_ref.delete()
                except Exception:
                    pass
                return response

        except Exception as exc:
            # If a completely unhandled 500 exception occurs in downstream logic, delete the lock.
            try:
                doc_ref.delete()
            except Exception:
                pass
            raise exc
