"""
FoodPulse – Poll Management Service.

Business rules (enforced strictly on backend):
  - Vendors create polls with options for a section
  - Creating a new poll closes previous active polls
  - Students can retrieve the active poll
  - Students can vote ONLY ONCE per poll
  - Duplicate vote attempts return 409 Conflict: "You have already voted in this poll."
"""

from __future__ import annotations

from fastapi import HTTPException, status

from ..repository import PollRepository
from ..schemas import (
    CreatePollRequest,
    FoodPulsePoll,
    CastPollVoteRequest,
    PollVoteResponse,
)


class PollService:
    """Service layer for vendor polls and student voting."""

    @staticmethod
    def create_poll(payload: CreatePollRequest, admin_uid: str) -> FoodPulsePoll:
        if len(payload.options) < 2:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="A poll must have at least 2 options.",
            )
        return PollRepository.create(payload, admin_uid)

    @staticmethod
    def get_active_poll() -> FoodPulsePoll:
        active = PollRepository.get_active_poll()
        if not active:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="No active poll available at this time.",
            )
        return active

    @staticmethod
    def vote_poll(poll_id: str, payload: CastPollVoteRequest, user_uid: str) -> PollVoteResponse:
        poll = PollRepository.get_by_id(poll_id)
        if not poll:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Poll '{poll_id}' not found.",
            )

        if poll.status != "active":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="This poll is no longer active.",
            )

        # Verify option_id exists in poll options
        valid_option = any(opt.id == payload.option_id for opt in poll.options)
        if not valid_option:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Invalid option '{payload.option_id}' for this poll.",
            )

        # Enforce one vote per user per poll rule
        if PollRepository.has_user_voted(poll_id, user_uid):
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="You have already voted in this poll.",
            )

        success = PollRepository.cast_vote(poll_id, payload.option_id, user_uid)
        if not success:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="You have already voted in this poll.",
            )

        return PollVoteResponse(
            poll_id=poll_id,
            option_id=payload.option_id,
            message="Your vote has been recorded successfully!",
        )

    @staticmethod
    def close_poll(poll_id: str) -> FoodPulsePoll:
        poll = PollRepository.close_poll(poll_id)
        if not poll:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Poll '{poll_id}' not found.",
            )
        return poll
