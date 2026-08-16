from fastapi import APIRouter, Depends

from auth.dependencies import get_current_admin, get_current_user
from config.logging import log_audit
from .schemas import UserProfile, UserDetail, CreateUserProfileRequest, RegisterFcmTokenRequest
from .service import UserService

router = APIRouter()


@router.post(
    "/profile",
    response_model=UserProfile,
    status_code=200,
    summary="Register / Sync user profile",
    description="Called after Firebase Auth signup/login. Creates or updates user record in Firestore and initializes 0-balance wallet.",
)
def create_or_update_profile(
    payload: CreateUserProfileRequest,
    user: dict = Depends(get_current_user),
) -> UserProfile:
    res = UserService.create_or_update_profile(user["uid"], payload)
    log_audit(
        action="USER_PROFILE_SYNCED",
        actor_uid=user["uid"],
        target=f"Users/{user['uid']}",
        details={"name": res.name, "email": res.email},
    )
    return res





@router.get(
    "/",
    response_model=list[UserProfile],
    summary="List all users",
    description=(
        "Returns every user registered in the system, sorted by name. "
        "Includes isAdmin flag so you can distinguish staff accounts."
    ),
)
def list_users(
    _admin: dict = Depends(get_current_admin),
) -> list[UserProfile]:
    return UserService.list_users()


@router.get(
    "/{uid}",
    response_model=UserDetail,
    summary="Get user detail",
    description=(
        "Returns the full profile for a single user, including their wallet "
        "balance and complete transaction history. Use this for investigating "
        "suspicious wallet activity."
    ),
)
def get_user(
    uid: str,
    _admin: dict = Depends(get_current_admin),
) -> UserDetail:
    return UserService.get_user(uid)


@router.post("/fcm-token", summary="Register FCM Token")
def register_fcm_token(
    payload: RegisterFcmTokenRequest,
    current_user: dict = Depends(get_current_user),
):
    """
    Registers a device FCM token for push notifications.
    The uid is derived securely from the auth token, so users cannot register tokens
    for other accounts.
    """
    uid = current_user["uid"]
    UserService.register_fcm_token(uid, payload.token)
    return {"status": "success", "message": "FCM token registered successfully."}

@router.delete("/fcm-token", summary="Delete FCM Token")
def delete_fcm_token(
    payload: RegisterFcmTokenRequest,
    current_user: dict = Depends(get_current_user),
):
    """
    Deletes a device FCM token before logout to prevent cross-user leakage.
    The uid is derived securely from the auth token.
    """
    uid = current_user["uid"]
    UserService.delete_fcm_token(uid, payload.token)
    return {"status": "success", "message": "FCM token deleted successfully."}
