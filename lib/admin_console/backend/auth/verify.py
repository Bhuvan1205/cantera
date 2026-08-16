import os
import logging
import json
import base64
import threading
from datetime import datetime, timezone
from firebase_admin import auth
from fastapi import HTTPException, status

logger = logging.getLogger("canteen-api.auth")


def _trace_backend_step(step: str, exception: str = "None") -> None:
    print(
        f"{step}\n"
        f"Executed: YES\n"
        f"Timestamp: {datetime.now(timezone.utc).isoformat()}\n"
        f"Process: {os.getpid()}\n"
        f"Thread: {threading.current_thread().name}\n"
        f"Exception: {exception}",
        flush=True,
    )


def _decode_jwt_unverified(token: str) -> tuple[dict, dict]:
    """
    Decodes JWT header and payload without cryptographic verification.
    Used strictly for diagnostic logging on verification failures.
    """
    try:
        parts = token.split(".")
        if len(parts) != 3:
            return {}, {}
        
        def _b64_decode(s: str) -> dict:
            rem = len(s) % 4
            if rem > 0:
                s += "=" * (4 - rem)
            return json.loads(base64.urlsafe_b64decode(s).decode("utf-8"))
        
        header = _b64_decode(parts[0])
        payload = _b64_decode(parts[1])
        return header, payload
    except Exception as e:
        logger.debug(f"[Auth Diagnostics] Could not decode JWT parts: {e}")
        return {}, {}


def should_check_revocation(is_sensitive: bool = False) -> bool:
    """
    Revocation Policy:
      - Local Development: check_revoked = False
      - Emulator:          check_revoked = False
      - Staging:           check_revoked = False
      - Production:
          - Standard API requests:     check_revoked = False (Stateless)
          - Security-sensitive only:   check_revoked = True  (Stateful)
    """
    env = os.getenv("ENV", "dev").lower()

    if env in ("dev", "development", "local", "staging"):
        return False

    if env in ("prod", "production"):
        return bool(is_sensitive)

    return False


def verify_firebase_token(id_token: str, is_sensitive: bool = False) -> dict:
    """
    Verifies a Firebase ID token and returns the decoded claims dict.
    
    Performs stateless cryptographic verification (signature, audience, issuer, expiration).
    Applies revocation checks only when mandated by policy for security-sensitive operations in production.
    Logs structured diagnostics on failure without exposing the full JWT.

    Raises:
        HTTP 401 — if the token is expired, malformed, revoked, or signature is invalid.
    """
    check_revoked = should_check_revocation(is_sensitive=is_sensitive)
    trace_exception = "None"

    try:
        decoded: dict = auth.verify_id_token(id_token, check_revoked=check_revoked, clock_skew_seconds=10)
        return decoded

    except Exception as exc:
        trace_exception = f"{type(exc).__name__}: {exc}"
        header, payload = _decode_jwt_unverified(id_token)
        logger.error(
            f"[Auth Diagnostics] Token verification failed:\n"
            f"  exception_type : {type(exc).__name__}\n"
            f"  exception_msg  : {exc}\n"
            f"  jwt_issuer     : {payload.get('iss')}\n"
            f"  jwt_audience   : {payload.get('aud')}\n"
            f"  jwt_kid        : {header.get('kid')}\n"
            f"  jwt_alg        : {header.get('alg')}\n"
            f"  jwt_exp        : {payload.get('exp')}\n"
            f"  jwt_uid        : {payload.get('sub')}\n"
            f"  check_revoked  : {check_revoked}"
        )

        if isinstance(exc, auth.RevokedIdTokenError):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token has been revoked. Please sign in again.",
            )
        elif isinstance(exc, auth.ExpiredIdTokenError):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token has expired. Please sign in again.",
            )
        elif isinstance(exc, auth.InvalidIdTokenError):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid authentication token.",
            )
        else:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Authentication failed. Please sign in again.",
            )
    finally:
        _trace_backend_step("STEP 8", trace_exception)


def verify_sensitive_firebase_token(id_token: str) -> dict:
    """
    Dedicated verification path for security-sensitive operations (e.g. payout config, role changes).
    Enforces revocation checks in production environments.
    """
    return verify_firebase_token(id_token, is_sensitive=True)
