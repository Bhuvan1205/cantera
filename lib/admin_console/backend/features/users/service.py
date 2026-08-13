from fastapi import HTTPException, status

from .repository import UserRepository
from .schemas import UserProfile, UserDetail, CreateUserProfileRequest


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
