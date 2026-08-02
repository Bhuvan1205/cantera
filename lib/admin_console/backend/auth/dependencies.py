from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

from config.firebase import db
from auth.verify import verify_firebase_token

# FastAPI will automatically parse "Authorization: Bearer <token>" headers.
_bearer = HTTPBearer(auto_error=True)


async def get_current_admin(
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

    # ── Firestore admin role check ────────────────────────────────────────────
    user_ref = db.collection("Users").document(uid)
    user_snap = user_ref.get()

    if not user_snap.exists:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User record not found in Firestore.",
        )

    user_data: dict = user_snap.to_dict()

    if not user_data.get("isAdmin", False):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied. Administrator privileges required.",
        )

    # Return merged payload — routes can use this to get uid, name, etc.
    return {"uid": uid, **decoded, "user_data": user_data}


async def get_current_user(
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

    return {"uid": uid}
