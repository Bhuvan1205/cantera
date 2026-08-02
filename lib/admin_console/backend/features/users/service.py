from fastapi import HTTPException, status

from .repository import UserRepository
from .schemas import UserProfile, UserDetail


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
