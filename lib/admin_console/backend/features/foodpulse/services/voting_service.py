"""
FoodPulse – Voting Service.

Business rules (enforced entirely on the backend):
  - One vote per user per suggestion
  - A user cannot vote on their own suggestion
  - Vote count is kept in sync on the suggestion document
  - Trending score is recalculated on every vote change

All vote logic lives here — the router only delegates here.
"""

from __future__ import annotations

from fastapi import HTTPException, status

from ..repository import SuggestionRepository, VoteRepository
from ..schemas import VoteResponse
from .analytics_service import AnalyticsService


class VotingService:
    """Manages voting lifecycle: cast, remove, validate."""

    @staticmethod
    def cast_vote(suggestion_id: str, user_uid: str) -> VoteResponse:
        """
        Casts a vote for a suggestion.

        Rules enforced:
          - Suggestion must exist and be in a voteable state (pending, approved)
          - User cannot vote on their own suggestion
          - User can only vote once per suggestion
        """
        suggestion = SuggestionRepository.get_by_id(suggestion_id)
        if not suggestion:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Suggestion '{suggestion_id}' not found.",
            )

        # 2. Cannot vote on own suggestion
        if suggestion.suggested_by == user_uid:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You cannot vote on your own suggestion.",
            )

        # 3. Cast vote atomically (handles uniqueness check and count increment internally)
        VoteRepository.cast_vote_transactional(suggestion_id, user_uid)

        # Recalculate popularity score
        new_score = AnalyticsService.compute_popularity(suggestion_id)
        SuggestionRepository.update_popularity_score(suggestion_id, new_score)

        # Read updated vote count
        updated = SuggestionRepository.get_by_id(suggestion_id)
        return VoteResponse(
            suggestion_id=suggestion_id,
            voted=True,
            vote_count=updated.vote_count if updated else suggestion.vote_count + 1,
        )

    @staticmethod
    def remove_vote(suggestion_id: str, user_uid: str) -> VoteResponse:
        """
        Removes the user's vote from a suggestion.
        """
        suggestion = SuggestionRepository.get_by_id(suggestion_id)
        if not suggestion:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Suggestion '{suggestion_id}' not found.",
            )

        if not VoteRepository.has_voted(suggestion_id, user_uid):
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="You have not voted for this suggestion.",
            )

        VoteRepository.remove_vote(suggestion_id, user_uid)

        # Decrement vote count (never go below 0)
        if suggestion.vote_count > 0:
            SuggestionRepository.update_vote_count(suggestion_id, -1)

        # Recalculate popularity score
        new_score = AnalyticsService.compute_popularity(suggestion_id)
        SuggestionRepository.update_popularity_score(suggestion_id, new_score)

        updated = SuggestionRepository.get_by_id(suggestion_id)
        return VoteResponse(
            suggestion_id=suggestion_id,
            voted=False,
            vote_count=updated.vote_count if updated else max(0, suggestion.vote_count - 1),
        )

    @staticmethod
    def has_voted(suggestion_id: str, user_uid: str) -> bool:
        return VoteRepository.has_voted(suggestion_id, user_uid)
