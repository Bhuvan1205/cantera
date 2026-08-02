from fastapi import APIRouter, Depends

from auth.dependencies import get_current_admin
from .schemas import UserProfile, UserDetail
from .service import UserService

router = APIRouter()


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
