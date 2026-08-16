"""
FoodPulse – Notification Service.

Triggers notifications for student suggesters during key lifecycle events:
  - Suggestion approved
  - Trial started
  - Trial ended
  - Item added permanently
  - Item removed / rejected

All notifications are written to the foodpulse_notifications collection.
"""

from __future__ import annotations

from typing import Optional
from ..repository import NotificationRepository
from ..schemas import FoodPulseNotification


class NotificationService:
    """Service layer for creating user notifications."""

    @staticmethod
    def notify_suggestion_approved(
        user_uid: str, suggestion_name: str, suggestion_id: str
    ) -> FoodPulseNotification:
        return NotificationRepository.push(
            user_uid=user_uid,
            title="Suggestion Approved! 🎉",
            body=f"Your suggestion '{suggestion_name}' has been approved by the canteen team!",
            notif_type="suggestion_approved",
            reference_id=suggestion_id,
        )

    @staticmethod
    def notify_trial_started(
        user_uid: str, suggestion_name: str, trial_id: str
    ) -> FoodPulseNotification:
        return NotificationRepository.push(
            user_uid=user_uid,
            title="Trial Started! 🚀",
            body=f"Great news! '{suggestion_name}' is now live as a trial item in the canteen.",
            notif_type="trial_started",
            reference_id=trial_id,
        )

    @staticmethod
    def notify_trial_ended(
        user_uid: str, suggestion_name: str, trial_id: str
    ) -> FoodPulseNotification:
        return NotificationRepository.push(
            user_uid=user_uid,
            title="Trial Completed 📊",
            body=f"The trial period for '{suggestion_name}' has concluded. Performance is being evaluated.",
            notif_type="trial_ended",
            reference_id=trial_id,
        )

    @staticmethod
    def notify_item_permanent(
        user_uid: str, suggestion_name: str, suggestion_id: str
    ) -> FoodPulseNotification:
        return NotificationRepository.push(
            user_uid=user_uid,
            title="Item Added Permanently! ⭐",
            body=f"Congratulations! '{suggestion_name}' performed so well in trials that it is now a permanent menu item!",
            notif_type="item_permanent",
            reference_id=suggestion_id,
        )

    @staticmethod
    def notify_item_removed(
        user_uid: str, suggestion_name: str, suggestion_id: str
    ) -> FoodPulseNotification:
        return NotificationRepository.push(
            user_uid=user_uid,
            title="Trial Update",
            body=f"Thank you for suggesting '{suggestion_name}'. Based on trial data, it will not be added to the permanent menu.",
            notif_type="item_removed",
            reference_id=suggestion_id,
        )

    @staticmethod
    def list_for_user(user_uid: str, limit: int = 30) -> list[FoodPulseNotification]:
        return NotificationRepository.list_for_user(user_uid, limit=limit)

    @staticmethod
    def mark_read(user_uid: str, notif_id: str) -> None:
        NotificationRepository.mark_read(user_uid, notif_id)
