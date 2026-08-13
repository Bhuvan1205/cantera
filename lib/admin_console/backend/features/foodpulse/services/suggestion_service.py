"""
FoodPulse – Suggestion Service.

Orchestrates:
  - Input validation
  - Text normalization (via duplicate_detector)
  - Duplicate detection (via duplicate_detector)
  - Storage in food_suggestions collection
  - Returns existing suggestion ID if duplicate found

All business logic lives here — the router only calls this service.
"""

from __future__ import annotations

from fastapi import HTTPException, status

from ..repository import SuggestionRepository
from ..schemas import (
    CreateSuggestionRequest,
    FoodSuggestion,
    SuggestionStatus,
    ApproveSuggestionRequest,
    RejectSuggestionRequest,
)
from .duplicate_detector import normalize_text, find_duplicate


class SuggestionDuplicateFound(Exception):
    """Raised when the submitted suggestion matches an existing one."""
    def __init__(self, existing_id: str):
        self.existing_id = existing_id
        super().__init__(f"Duplicate found: {existing_id}")


class SuggestionService:
    """Business logic for food suggestion lifecycle."""

    @staticmethod
    def submit(
        payload: CreateSuggestionRequest,
        user_uid: str,
    ) -> dict:
        """
        Validates, normalizes, deduplicates, and stores a suggestion.

        Returns:
            {
              "suggestion": FoodSuggestion,
              "is_duplicate": bool,
              "message": str
            }
        """
        # Validate name is not empty after stripping
        if not payload.name.strip():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Suggestion name cannot be empty.",
            )

        # Normalize text
        normalized = normalize_text(payload.name)

        # Enforce strict per-student uniqueness rule
        if SuggestionRepository.has_user_suggested_item(user_uid, normalized):
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="You have already suggested this item.",
            )

        # Load all existing normalized names for comparison
        existing = SuggestionRepository.list_all_normalized()

        # Check for duplicate
        duplicate_id = find_duplicate(normalized, existing)
        if duplicate_id:
            # Increment request_count on the existing suggestion
            SuggestionRepository.increment_request_count(duplicate_id)
            existing_suggestion = SuggestionRepository.get_by_id(duplicate_id)
            return {
                "suggestion": existing_suggestion,
                "is_duplicate": True,
                "message": (
                    "A similar suggestion already exists. "
                    "Your request has been counted — consider voting for it!"
                ),
            }

        # Create new suggestion
        suggestion = SuggestionRepository.create(payload, normalized, user_uid)
        return {
            "suggestion": suggestion,
            "is_duplicate": False,
            "message": "Your suggestion has been submitted successfully!",
        }

    @staticmethod
    def list_all(status_filter: str | None = None, limit: int = 100) -> list[FoodSuggestion]:
        return SuggestionRepository.list_all(status_filter=status_filter, limit=limit)

    @staticmethod
    def list_by_user(user_uid: str) -> list[FoodSuggestion]:
        return SuggestionRepository.list_by_user(user_uid)

    @staticmethod
    def get(suggestion_id: str) -> FoodSuggestion:
        suggestion = SuggestionRepository.get_by_id(suggestion_id)
        if not suggestion:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Suggestion '{suggestion_id}' not found.",
            )
        return suggestion

    @staticmethod
    def approve(suggestion_id: str, payload: ApproveSuggestionRequest) -> FoodSuggestion:
        suggestion = SuggestionService.get(suggestion_id)
        if suggestion.status not in (SuggestionStatus.pending,):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Suggestion is already '{suggestion.status}'. Only pending suggestions can be approved.",
            )
        updated = SuggestionRepository.update_status(
            suggestion_id, SuggestionStatus.approved, notes=payload.notes
        )
        return updated

    @staticmethod
    def reject(suggestion_id: str, payload: RejectSuggestionRequest) -> FoodSuggestion:
        suggestion = SuggestionService.get(suggestion_id)
        if suggestion.status not in (SuggestionStatus.pending, SuggestionStatus.approved):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Cannot reject a suggestion with status '{suggestion.status}'.",
            )
        updated = SuggestionRepository.update_status(
            suggestion_id, SuggestionStatus.rejected, notes=payload.reason
        )
        return updated
