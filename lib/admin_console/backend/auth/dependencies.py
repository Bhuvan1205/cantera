from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

from config.firebase import db
from auth.verify import verify_firebase_token

# FastAPI will automatically parse "Authorization: Bearer <token>" headers.
_bearer = HTTPBearer(auto_error=True)


def get_current_admin(
    http_creds: HTTPAuthorizationCredentials = Depends(_bearer),
) -> dict:
    """
    FastAPI dependency that enforces two layers of admin verification:

    Layer 1 — Firebase Auth:
        Verifies the Bearer token is a valid, non-expired Firebase ID token.
        Extracts the uid from the decoded claims.

    Layer 2 — Firestore role check:
        Looks up Users/{uid} in Firestore and confirms isAdmin == True.

    Returns:
        A dict with Firebase decoded claims merged with Firestore user data,
        accessible via request state in any route that depends on this.

    Raises:
        HTTP 401 — invalid / expired token
        HTTP 403 — valid token but user is not an admin (or doesn't exist)
    """
    token = http_creds.credentials
    decoded = verify_firebase_token(token)

    uid: str | None = decoded.get("uid")
    if not uid:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token is missing the uid claim.",
        )

    # ── Fast Path: Firebase Custom Claims (0 Firestore reads) ─────────────────
    if decoded.get("admin") is True or decoded.get("isAdmin") is True:
        return {"uid": uid, **decoded, "user_data": {"isAdmin": True, "admin": True}}

    # ── Fallback: Firestore document check (for legacy tokens) ───────────────
    user_ref = db.collection("Users").document(uid)
    user_snap = user_ref.get()

    if not user_snap.exists:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User record not found in Firestore.",
        )

    user_data: dict = user_snap.to_dict() or {}

    if not user_data.get("isAdmin", False):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied. Administrator privileges required.",
        )

    # Return merged payload — routes can use this to get uid, name, etc.
    return {"uid": uid, **decoded, "user_data": user_data}


def get_current_user(
    http_creds: HTTPAuthorizationCredentials = Depends(_bearer),
) -> dict:
    """
    FastAPI dependency for authenticated (non-admin) user routes.

    Verifies the Firebase ID token and returns the uid.
    Does NOT check isAdmin — any authenticated Firebase user is permitted.

    Used by: POST /api/wallet/deposits/verify (called by the Flutter user app
    immediately after a successful payment gateway callback).

    Raises:
        HTTP 401 — invalid / expired token
    """
    token = http_creds.credentials
    decoded = verify_firebase_token(token)

    uid: str | None = decoded.get("uid")
    if not uid:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token is missing the uid claim.",
        )

    return {"uid": uid, "email": decoded.get("email")}


def get_current_staff_or_admin(
    http_creds: HTTPAuthorizationCredentials = Depends(_bearer),
) -> dict:
    """
    FastAPI dependency that allows staff members or administrators.
    Checks custom claims (admin, staff, role) or Firestore Users/{uid} document.
    """
    token = http_creds.credentials
    decoded = verify_firebase_token(token)

    uid: str | None = decoded.get("uid")
    if not uid:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token is missing the uid claim.",
        )

    # Fast path: Custom Claims
    role = decoded.get("role")
    if decoded.get("admin") is True or decoded.get("staff") is True or role in ("admin", "staff"):
        return {"uid": uid, **decoded, "user_data": {"role": role or "staff", "staff": True}}

    # Fallback: Firestore check
    user_ref = db.collection("Users").document(uid)
    user_snap = user_ref.get()

    if not user_snap.exists:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User record not found in Firestore.",
        )

    user_data: dict = user_snap.to_dict() or {}
    user_role = user_data.get("role")
    is_admin = user_data.get("isAdmin", False) or user_data.get("admin", False)

    if not (is_admin or user_role in ("admin", "staff")):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied. Staff or administrator privileges required.",
        )

    return {"uid": uid, **decoded, "user_data": user_data}

