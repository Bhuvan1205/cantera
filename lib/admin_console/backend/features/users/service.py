from fastapi import HTTPException, status

from .repository import UserRepository
from .schemas import UserProfile, UserDetail, CreateUserProfileRequest, PinInfoResponse, ChangePinRequest


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
        return UserRepository.upsert_user_profile(uid, payload)

    @staticmethod
    def register_fcm_token(uid: str, token: str) -> None:
        """
        Validates and stores an FCM push notification token for the authenticated user.

        The uid is always the authenticated user's uid, extracted server-side from
        the verified Firebase ID token. It is never accepted from the client.

        Raises:
            HTTP 400 — if the token is empty or whitespace only.
        """
        from fastapi import HTTPException, status as http_status
        token = token.strip()
        if not token:
            raise HTTPException(
                status_code=http_status.HTTP_400_BAD_REQUEST,
                detail="FCM token must not be empty.",
            )
        UserRepository.upsert_fcm_token(uid, token)

    @staticmethod
    def delete_fcm_token(uid: str, token: str) -> None:
        """
        Deletes an FCM push notification token for the authenticated user.
        """
        from fastapi import HTTPException, status as http_status
        token = token.strip()
        if not token:
            raise HTTPException(
                status_code=http_status.HTTP_400_BAD_REQUEST,
                detail="FCM token must not be empty.",
            )
        UserRepository.delete_fcm_token(uid, token)

    @staticmethod
    def get_pickup_pin_info(uid: str) -> PinInfoResponse:
        from config.firebase import db
        user_snap = db.collection(UserRepository._users_col).document(uid).get()
        if not user_snap.exists:
            return PinInfoResponse(has_pin=False, last_pin_change=None)

        data = user_snap.to_dict() or {}
        has_pin = bool(data.get("pickupPin"))
        last_change = data.get("lastPinChange")
        last_change_str = last_change.isoformat() if last_change else None
        
        return PinInfoResponse(has_pin=has_pin, last_pin_change=last_change_str)

    @staticmethod
    def change_pickup_pin(uid: str, payload: ChangePinRequest) -> None:
        new_pin = payload.new_pin.strip()
        if len(new_pin) != 4 or not new_pin.isdigit():
            from fastapi import HTTPException, status as http_status
            raise HTTPException(
                status_code=http_status.HTTP_400_BAD_REQUEST,
                detail="PIN must be exactly 4 digits."
            )
        
        from config.firebase import db
        user_snap = db.collection(UserRepository._users_col).document(uid).get()
        if not user_snap.exists:
            from fastapi import HTTPException, status as http_status
            raise HTTPException(
                status_code=http_status.HTTP_404_NOT_FOUND,
                detail="User not found."
            )
        
        data = user_snap.to_dict() or {}
        last_change = data.get("lastPinChange")
        if last_change:
            from datetime import datetime, timezone, timedelta
            now = datetime.now(timezone.utc)
            if (now - last_change) < timedelta(days=30):
                from fastapi import HTTPException, status as http_status
                raise HTTPException(
                    status_code=http_status.HTTP_400_BAD_REQUEST,
                    detail="PIN can only be changed once every 30 days."
                )
                
        UserRepository.update_pickup_pin(uid, new_pin)
