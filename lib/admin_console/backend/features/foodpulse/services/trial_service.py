"""
FoodPulse – Trial Management Service.

Backend manages all trial lifecycle logic:
  - Trial creation with duration tracking
  - Status transitions: active → completed → decided
  - Suggestion status synchronization

No trial logic exists in the frontend.
"""

from __future__ import annotations

from fastapi import HTTPException, status

from ..repository import SuggestionRepository, TrialRepository
from ..schemas import (
    StartTrialRequest,
    TrialItem,
    TrialStatus,
    SuggestionStatus,
    EndTrialRequest,
)
from .notification_service import NotificationService


class TrialService:
    """Manages food trial lifecycle from start to completion."""

    @staticmethod
    def start_trial(payload: StartTrialRequest, admin_uid: str) -> TrialItem:
        """
        Approves and starts a trial for a suggestion.

        Validates:
          - Suggestion exists
          - Suggestion is in 'approved' status
          - No active trial already exists for this suggestion

        Side effects:
          - Creates food_trials document
          - Updates suggestion status to 'in_trial'
          - Notifies the original suggester
        """
        suggestion = SuggestionRepository.get_by_id(payload.suggestion_id)
        if not suggestion:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Suggestion '{payload.suggestion_id}' not found.",
            )

        if suggestion.status != SuggestionStatus.approved:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Only approved suggestions can be trialed. Current status: '{suggestion.status}'.",
            )

        # Check for existing active trial on this suggestion
        active_trials = TrialRepository.list_active()
        for t in active_trials:
            if t.suggestion_id == payload.suggestion_id:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="An active trial already exists for this suggestion.",
                )

        # Create trial
        trial = TrialRepository.create(
            payload=payload,
            suggestion_name=suggestion.name,
            category=suggestion.category,
            admin_uid=admin_uid,
        )

        # Update suggestion status
        SuggestionRepository.update_status(payload.suggestion_id, SuggestionStatus.in_trial)

        # Notify the suggester
        NotificationService.notify_trial_started(
            user_uid=suggestion.suggested_by,
            suggestion_name=suggestion.name,
            trial_id=trial.id,
        )

        return trial

    @staticmethod
    def end_trial(trial_id: str, payload: EndTrialRequest) -> TrialItem:
        """
        Marks a trial as completed.

        Validates:
          - Trial exists
          - Trial is currently active

        Side effects:
          - Updates trial status to 'completed'
          - Notifies the original suggester
        """
        trial = TrialRepository.get_by_id(trial_id)
        if not trial:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Trial '{trial_id}' not found.",
            )

        if trial.status != TrialStatus.active:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Trial is not active (current status: '{trial.status}').",
            )

        completed_trial = TrialRepository.complete_trial(trial_id, payload.notes)

        # Notify the original suggester
        suggestion = SuggestionRepository.get_by_id(trial.suggestion_id)
        if suggestion:
            NotificationService.notify_trial_ended(
                user_uid=suggestion.suggested_by,
                suggestion_name=suggestion.name,
                trial_id=trial_id,
            )

        return completed_trial

    @staticmethod
    def get_trial(trial_id: str) -> TrialItem:
        trial = TrialRepository.get_by_id(trial_id)
        if not trial:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Trial '{trial_id}' not found.",
            )
        return trial

    @staticmethod
    def list_active() -> list[TrialItem]:
        return TrialRepository.list_active()

    @staticmethod
    def list_all(limit: int = 50) -> list[TrialItem]:
        return TrialRepository.list_all(limit=limit)
