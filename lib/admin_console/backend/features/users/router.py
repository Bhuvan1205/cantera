from fastapi import APIRouter, Depends

from auth.dependencies import get_current_admin, get_current_user
from config.logging import log_audit
from .schemas import UserProfile, UserDetail, CreateUserProfileRequest, ChangePinRequest, PickupPinInfo
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
    "/me/pin",
    response_model=PickupPinInfo,
    summary="Get user pickup PIN info",
    description="Returns whether the caller has a pickup PIN and remaining cooldown days.",
)
def get_my_pin_info(
    user: dict = Depends(get_current_user),
) -> PickupPinInfo:
    return UserService.get_my_pin_info(user["uid"])


@router.post(
    "/change-pin",
    summary="Change user pickup delivery PIN",
    description="Validates 4-digit PIN format and 30-day cooldown period server-side.",
)
def change_pickup_pin(
    payload: ChangePinRequest,
    user: dict = Depends(get_current_user),
) -> dict:
    res = UserService.change_pickup_pin(user["uid"], payload.new_pin)
    log_audit(
        action="USER_PIN_CHANGED",
        actor_uid=user["uid"],
        target=f"Users/{user['uid']}",
        details={"status": "updated"},
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

