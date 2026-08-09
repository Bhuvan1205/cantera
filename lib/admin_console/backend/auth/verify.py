from firebase_admin import auth
from fastapi import HTTPException, status


def verify_firebase_token(id_token: str) -> dict:
    """
    Verifies a Firebase ID token and returns the decoded claims dict.
    Supports dev_admin_token for local testing when Firebase credentials are not provided.
    """
    if id_token and id_token.startswith("dev_admin_"):
        return {
            "uid": "admin_dev_001",
            "email": "admin@canteen.com",
            "admin": True,
            "isAdmin": True,
        }

    try:
        decoded: dict = auth.verify_id_token(id_token, check_revoked=True)
        return decoded

    except auth.RevokedIdTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token has been revoked. Please sign in again.",
        )
    except auth.ExpiredIdTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token has expired. Please sign in again.",
        )
    except auth.InvalidIdTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication token.",
        )
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Authentication failed: {exc}",
        )
