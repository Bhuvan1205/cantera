from fastapi import HTTPException, status

from .repository import UserRepository
from .schemas import UserProfile, UserDetail, CreateUserProfileRequest, PickupPinInfo


class UserService:
    """
    Business logic layer for the Users feature.
    Sits between the router (HTTP) and the repository (Firestore).
    """

    @staticmethod
    def list_users() -> list[UserProfile]:
        """Returns all user profiles sorted by name."""
        return UserRepository.get_all_users()

    @staticmethod
    def get_user(uid: str) -> UserDetail:
        """
        Returns full detail for a single user.
        Raises HTTP 404 if the uid is not found in Firestore.
        """
        detail = UserRepository.get_user_by_uid(uid)
        if detail is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"User '{uid}' not found.",
            )
        return detail

    @staticmethod
    def create_or_update_profile(uid: str, payload: CreateUserProfileRequest) -> UserProfile:
        """
        Registers or updates a user profile and initializes default wallet balance.
        """
        if payload.pickup_pin:
            pin = payload.pickup_pin.strip()
            if len(pin) != 4 or not pin.isdigit():
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Pickup PIN must be exactly 4 digits.",
                )
        return UserRepository.upsert_user_profile(uid, payload)

    @staticmethod
    def get_my_pin_info(uid: str) -> PickupPinInfo:
        """
        Retrieves current pickup PIN status and 30-day change availability.
        """
        _, pin_info = UserRepository.get_pickup_pin_info(uid)
        return pin_info

    @staticmethod
    def change_pickup_pin(uid: str, new_pin: str) -> dict:
        """
        Validates 4-digit PIN format and 30-day cooldown period server-side.
        """
        pin = new_pin.strip()
        if len(pin) != 4 or not pin.isdigit():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="PIN must be exactly 4 numeric digits.",
            )

        _, pin_info = UserRepository.get_pickup_pin_info(uid)
        if pin_info.can_change_in_days > 0:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail=(
                    f"PIN can only be changed once every 30 days. "
                    f"You can change it again in {pin_info.can_change_in_days} day(s)."
                ),
            )

        UserRepository.update_pickup_pin(uid, pin)
        return {
            "status": "success",
            "message": "Delivery pickup PIN updated successfully.",
        }

