import httpx
from pydantic import BaseModel
from fastapi import APIRouter, HTTPException, status
from config.firebase import db
from auth.verify import verify_firebase_token

router = APIRouter()

FIREBASE_WEB_API_KEY = "AIzaSyA_A4VW6FECnFDuEwqnPmbnenEv-V16b9g"
FIREBASE_AUTH_SIGNIN_URL = (
    f"https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key={FIREBASE_WEB_API_KEY}"
)


class LoginRequest(BaseModel):
    email: str
    password: str


class LoginResponse(BaseModel):
    id_token: str
    refresh_token: str
    expires_in: str
    uid: str
    email: str
    is_admin: bool
    message: str


@router.post(
    "/login",
    response_model=LoginResponse,
    summary="Login to obtain a Firebase ID token",
    description=(
        "Exchanges admin email and password for a Firebase ID token to use in Swagger UI Authorize header. "
        "Also verifies that the user exists in Firestore and has administrator privileges."
    ),
)
async def login(payload: LoginRequest) -> LoginResponse:
    async with httpx.AsyncClient() as client:
        try:
            resp = await client.post(
                FIREBASE_AUTH_SIGNIN_URL,
                json={
                    "email": payload.email.strip(),
                    "password": payload.password,
                    "returnSecureToken": True,
                },
                timeout=10.0,
            )
        except Exception as exc:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail=f"Unable to reach Firebase Auth: {exc}",
            )

    data = resp.json()

    if resp.status_code != 200:
        error_msg = data.get("error", {}).get("message", "Authentication failed")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Firebase login failed: {error_msg}",
        )

    uid = data.get("localId", "")
    id_token = data.get("idToken", "")
    refresh_token = data.get("refreshToken", "")
    expires_in = data.get("expiresIn", "3600")
    email = data.get("email", payload.email)

    # 1. Authorize via Firestore 'Users' collection (Requested by User)
    is_admin = False
    if uid:
        user_snap = db.collection("Users").document(uid).get()
        if user_snap.exists:
            is_admin = bool(user_snap.to_dict().get("isAdmin", False))

    if not is_admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Authenticated successfully, but this account does not have admin privileges (isAdmin: false).",
        )

    return LoginResponse(
        id_token=id_token,
        refresh_token=refresh_token,
        expires_in=expires_in,
        uid=uid,
        email=email,
        is_admin=is_admin,
        message="Copy the 'id_token' and paste it into the Swagger UI Authorize box.",
    )
