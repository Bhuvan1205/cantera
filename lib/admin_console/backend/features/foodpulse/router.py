"""
FoodPulse – FastAPI REST Router.

Exposes all /foodpulse/* endpoints as specified in the architecture requirements.
Distinguishes between student routes (get_current_user) and vendor/admin routes (get_current_admin).
No existing routes or routers are modified.
"""

from typing import Optional
from fastapi import APIRouter, Depends, Query, status

from auth.dependencies import get_current_admin, get_current_user
from .schemas import (
    CreateSuggestionRequest,
    FoodSuggestion,
    ApproveSuggestionRequest,
    RejectSuggestionRequest,
    VoteResponse,
    TrendingResponse,
    StartTrialRequest,
    EndTrialRequest,
    TrialItem,
    RecordMetricRequest,
    TrialMetric,
    TrialAnalytics,
    Recommendation,
    FoodPulseNotification,
    VendorDashboardResponse,
    CreatePollRequest,
    FoodPulsePoll,
    CastPollVoteRequest,
    PollVoteResponse,
)
from .services.suggestion_service import SuggestionService
from .services.voting_service import VotingService
from .services.analytics_service import AnalyticsService
from .services.trial_service import TrialService
from .services.performance_service import PerformanceService
from .services.recommendation_engine import RecommendationEngine
from .services.notification_service import NotificationService
from .services.poll_service import PollService
from .repository import SuggestionRepository, VoteRepository, TrialRepository, PollRepository

router = APIRouter()



# ─────────────────────────────────────────────
# Student / General Suggestion Routes
# ─────────────────────────────────────────────

@router.post(
    "/suggestions",
    status_code=status.HTTP_201_CREATED,
    summary="Suggest a new food item",
    description="Validates, normalizes, deduplicates, and stores a new student food suggestion.",
)
def submit_suggestion(
    payload: CreateSuggestionRequest,
    user: dict = Depends(get_current_user),
) -> dict:
    return SuggestionService.submit(payload, user_uid=user["uid"])


@router.get(
    "/suggestions",
    response_model=list[FoodSuggestion],
    summary="List food suggestions",
    description="Returns food suggestions. Optionally filter by status (pending, approved, in_trial, permanent).",
)
def list_suggestions(
    status_filter: Optional[str] = Query(None, alias="status", description="Optional status filter"),
    limit: int = Query(100, ge=1, le=500),
    _user: dict = Depends(get_current_user),
) -> list[FoodSuggestion]:
    return SuggestionService.list_all(status_filter=status_filter, limit=limit)


@router.get(
    "/suggestions/mine",
    response_model=list[FoodSuggestion],
    summary="Get suggestions submitted by current user",
)
def my_suggestions(
    user: dict = Depends(get_current_user),
) -> list[FoodSuggestion]:
    return SuggestionService.list_by_user(user["uid"])


@router.post(
    "/vote/{suggestion_id}",
    response_model=VoteResponse,
    summary="Vote for a suggestion",
    description="Casts a vote for a food suggestion. Enforces 1 vote per user and prevents self-voting.",
)
def vote_suggestion(
    suggestion_id: str,
    user: dict = Depends(get_current_user),
) -> VoteResponse:
    return VotingService.cast_vote(suggestion_id, user["uid"])


@router.delete(
    "/vote/{suggestion_id}",
    response_model=VoteResponse,
    summary="Remove vote for a suggestion",
)
def remove_vote(
    suggestion_id: str,
    user: dict = Depends(get_current_user),
) -> VoteResponse:
    return VotingService.remove_vote(suggestion_id, user["uid"])


@router.get(
    "/trending",
    response_model=TrendingResponse,
    summary="Get trending food suggestions",
    description="Returns top suggestions ranked by 4-factor popularity algorithm.",
)
def get_trending(
    limit: int = Query(20, ge=1, le=100),
    _user: dict = Depends(get_current_user),
) -> TrendingResponse:
    return AnalyticsService.get_trending(limit=limit)


@router.get(
    "/notifications",
    response_model=list[FoodPulseNotification],
    summary="Get FoodPulse notifications for current user",
)
def get_notifications(
    limit: int = Query(30, ge=1, le=100),
    user: dict = Depends(get_current_user),
) -> list[FoodPulseNotification]:
    return NotificationService.list_for_user(user["uid"], limit=limit)


@router.patch(
    "/notifications/{notif_id}/read",
    summary="Mark notification as read",
)
def mark_notification_read(
    notif_id: str,
    user: dict = Depends(get_current_user),
) -> dict:
    NotificationService.mark_read(user["uid"], notif_id)
    return {"status": "ok", "message": "Notification marked as read"}


@router.get(
    "/polls/active",
    response_model=FoodPulsePoll,
    summary="Get currently active community poll",
)
def get_active_poll(
    _user: dict = Depends(get_current_user),
) -> FoodPulsePoll:
    return PollService.get_active_poll()


@router.post(
    "/polls/{poll_id}/vote",
    response_model=PollVoteResponse,
    summary="Submit vote for an active poll",
)
def vote_poll(
    poll_id: str,
    payload: CastPollVoteRequest,
    user: dict = Depends(get_current_user),
) -> PollVoteResponse:
    return PollService.vote_poll(poll_id, payload, user_uid=user["uid"])


# ─────────────────────────────────────────────
# Vendor / Admin Routes
# ─────────────────────────────────────────────

@router.get(
    "/vendor/dashboard",
    response_model=VendorDashboardResponse,
    summary="Vendor FoodPulse Dashboard Overview",
    description="Returns pending/approved suggestions, top requested items, active trials, and aggregate stats.",
)
def vendor_dashboard(
    _admin: dict = Depends(get_current_admin),
) -> VendorDashboardResponse:
    all_suggestions = SuggestionRepository.list_all(limit=500)
    pending = [s for s in all_suggestions if s.status == "pending"]
    approved = [s for s in all_suggestions if s.status == "approved"]
    trending = AnalyticsService.get_trending(limit=10).items
    active_trials = TrialRepository.list_active()
    active_poll = PollRepository.get_active_poll()
    total_votes = VoteRepository.total_votes_across_all()

    return VendorDashboardResponse(
        pending_suggestions=pending,
        approved_suggestions=approved,
        top_requested=trending,
        active_trials=active_trials,
        active_poll=active_poll,
        total_suggestions=len(all_suggestions),
        total_votes=total_votes,
    )


@router.post(
    "/polls",
    response_model=FoodPulsePoll,
    status_code=status.HTTP_201_CREATED,
    summary="Vendor creates a new community poll",
)
def create_poll(
    payload: CreatePollRequest,
    admin: dict = Depends(get_current_admin),
) -> FoodPulsePoll:
    return PollService.create_poll(payload, admin_uid=admin["uid"])


@router.post(
    "/polls/{poll_id}/close",
    response_model=FoodPulsePoll,
    summary="Vendor closes a poll",
)
def close_poll(
    poll_id: str,
    _admin: dict = Depends(get_current_admin),
) -> FoodPulsePoll:
    return PollService.close_poll(poll_id)



@router.post(
    "/suggestions/{suggestion_id}/approve",
    response_model=FoodSuggestion,
    summary="Vendor approves a suggestion",
)
def approve_suggestion(
    suggestion_id: str,
    payload: ApproveSuggestionRequest,
    _admin: dict = Depends(get_current_admin),
) -> FoodSuggestion:
    suggestion = SuggestionService.approve(suggestion_id, payload)
    NotificationService.notify_suggestion_approved(
        user_uid=suggestion.suggested_by,
        suggestion_name=suggestion.name,
        suggestion_id=suggestion_id,
    )
    return suggestion


@router.post(
    "/suggestions/{suggestion_id}/reject",
    response_model=FoodSuggestion,
    summary="Vendor rejects a suggestion",
)
def reject_suggestion(
    suggestion_id: str,
    payload: RejectSuggestionRequest,
    _admin: dict = Depends(get_current_admin),
) -> FoodSuggestion:
    return SuggestionService.reject(suggestion_id, payload)


@router.post(
    "/trial/start",
    response_model=TrialItem,
    status_code=status.HTTP_201_CREATED,
    summary="Launch a trial item",
    description="Creates a trial item record from an approved suggestion and sets status to in_trial.",
)
def start_trial(
    payload: StartTrialRequest,
    admin: dict = Depends(get_current_admin),
) -> TrialItem:
    return TrialService.start_trial(payload, admin_uid=admin["uid"])


@router.post(
    "/trial/end/{trial_id}",
    response_model=TrialItem,
    summary="End an active trial",
)
def end_trial(
    trial_id: str,
    payload: EndTrialRequest,
    _admin: dict = Depends(get_current_admin),
) -> TrialItem:
    return TrialService.end_trial(trial_id, payload)


@router.get(
    "/trial",
    response_model=list[TrialItem],
    summary="List all trials",
)
def list_trials(
    _admin: dict = Depends(get_current_admin),
) -> list[TrialItem]:
    return TrialService.list_all()


@router.post(
    "/trial/{trial_id}/metrics",
    response_model=TrialMetric,
    summary="Record daily performance metrics for a trial",
)
def record_trial_metrics(
    trial_id: str,
    payload: RecordMetricRequest,
    _admin: dict = Depends(get_current_admin),
) -> TrialMetric:
    return PerformanceService.record_metric(trial_id, payload)


@router.get(
    "/analytics/{trial_id}",
    response_model=TrialAnalytics,
    summary="Get aggregated trial performance analytics",
)
def get_trial_analytics(
    trial_id: str,
    _admin: dict = Depends(get_current_admin),
) -> TrialAnalytics:
    return PerformanceService.get_analytics(trial_id)


@router.get(
    "/recommendation/{trial_id}",
    response_model=Recommendation,
    summary="Get AI recommendation for a trial",
    description="Compares predicted demand vs actual performance to recommend: keep_permanently, extend_trial, modify_item, or remove_item.",
)
def get_recommendation(
    trial_id: str,
    _admin: dict = Depends(get_current_admin),
) -> Recommendation:
    return RecommendationEngine.get_recommendation(trial_id)
