"""
FoodPulse – Recommendation Engine.

Compares predicted demand vs actual trial performance to generate one of four actions:
  - keep_permanently  → strong performance, add to regular menu
  - extend_trial      → moderate performance, needs more data
  - modify_item       → mixed signals, suggest price/portion changes
  - remove_item       → poor performance, discontinue

All thresholds are configurable at the top of this file.
All business rules live here — no recommendation logic in the frontend.
"""

from __future__ import annotations

from datetime import datetime, timezone
from fastapi import HTTPException, status

from ..repository import TrialRepository, SuggestionRepository
from ..schemas import (
    Recommendation,
    RecommendationAction,
    TrialStatus,
    SuggestionStatus,
)
from .performance_service import PerformanceService
from .notification_service import NotificationService


# ── Configurable Business Rules ───────────────────────────────────────────────
# Performance vs prediction thresholds (as percentages)
THRESHOLD_KEEP_PERMANENTLY  = 80.0   # >= 80% of predicted → keep
THRESHOLD_EXTEND_TRIAL      = 50.0   # 50-79% of predicted → extend
THRESHOLD_MODIFY_ITEM       = 25.0   # 25-49% of predicted → modify
# < 25% → remove

# Rating thresholds
MIN_RATING_FOR_KEEP         = 3.5
MIN_RATING_FOR_EXTEND       = 3.0

# Cancellation rate thresholds
MAX_CANCEL_RATE_FOR_KEEP    = 0.10   # ≤ 10% cancellation
MAX_CANCEL_RATE_FOR_EXTEND  = 0.20   # ≤ 20% cancellation

# Minimum days of data required for a recommendation
MIN_DAYS_FOR_RECOMMENDATION = 3


def _determine_action(
    performance_pct: float,
    avg_rating: float,
    avg_cancel_rate: float,
    total_days: int,
) -> tuple[RecommendationAction, float, str]:
    """
    Core decision logic. Returns (action, confidence, reasoning).

    Decision matrix:
      - Insufficient data → extend trial (low confidence)
      - Strong sales + good rating + low cancellation → keep
      - Moderate sales + acceptable rating → extend
      - Low sales but decent quality → modify
      - Poor sales + poor quality → remove
    """
    if total_days < MIN_DAYS_FOR_RECOMMENDATION:
        return (
            RecommendationAction.extend_trial,
            0.4,
            f"Insufficient data ({total_days} days). Minimum {MIN_DAYS_FOR_RECOMMENDATION} days required for a confident recommendation.",
        )

    if (
        performance_pct >= THRESHOLD_KEEP_PERMANENTLY
        and avg_rating >= MIN_RATING_FOR_KEEP
        and avg_cancel_rate <= MAX_CANCEL_RATE_FOR_KEEP
    ):
        confidence = min(0.95, 0.6 + (performance_pct - THRESHOLD_KEEP_PERMANENTLY) / 100)
        return (
            RecommendationAction.keep_permanently,
            round(confidence, 2),
            (
                f"Achieved {performance_pct:.1f}% of predicted demand with a {avg_rating:.1f}/5 rating "
                f"and a {avg_cancel_rate:.0%} cancellation rate. Strong performance across all KPIs."
            ),
        )

    if (
        performance_pct >= THRESHOLD_EXTEND_TRIAL
        and avg_rating >= MIN_RATING_FOR_EXTEND
        and avg_cancel_rate <= MAX_CANCEL_RATE_FOR_EXTEND
    ):
        confidence = 0.55 + (performance_pct - THRESHOLD_EXTEND_TRIAL) / 200
        return (
            RecommendationAction.extend_trial,
            round(confidence, 2),
            (
                f"Moderate performance at {performance_pct:.1f}% of predicted demand. "
                f"Rating of {avg_rating:.1f}/5 is acceptable. Extending the trial will provide "
                f"more data to make a confident decision."
            ),
        )

    if performance_pct >= THRESHOLD_MODIFY_ITEM:
        confidence = 0.50
        return (
            RecommendationAction.modify_item,
            confidence,
            (
                f"Below-target demand at {performance_pct:.1f}% of prediction. "
                f"Rating of {avg_rating:.1f}/5 suggests the concept has potential. "
                f"Consider adjusting price, portion size, or recipe before re-trialing."
            ),
        )

    # Default: poor performance
    confidence = min(0.90, 0.6 + (THRESHOLD_MODIFY_ITEM - performance_pct) / 100)
    return (
        RecommendationAction.remove_item,
        round(confidence, 2),
        (
            f"Only {performance_pct:.1f}% of predicted demand achieved with a {avg_rating:.1f}/5 rating "
            f"and {avg_cancel_rate:.0%} cancellation rate. Item does not show sufficient market demand."
        ),
    )


class RecommendationEngine:
    """Generates AI-driven menu recommendations based on trial performance."""

    @staticmethod
    def get_recommendation(trial_id: str) -> Recommendation:
        """
        Generates a recommendation for the given completed trial.

        Only works for trials in 'completed' or 'decided' status.
        """
        trial = TrialRepository.get_by_id(trial_id)
        if not trial:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Trial '{trial_id}' not found.",
            )

        if trial.status not in (TrialStatus.completed, TrialStatus.decided, TrialStatus.active):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Recommendations require a trial in 'active', 'completed', or 'decided' status. Current: '{trial.status}'.",
            )

        analytics = PerformanceService.get_analytics(trial_id)
        total_days = len(analytics.daily_breakdown)

        action, confidence, reasoning = _determine_action(
            performance_pct=analytics.performance_vs_prediction_pct,
            avg_rating=analytics.avg_rating,
            avg_cancel_rate=analytics.avg_cancellation_rate,
            total_days=total_days,
        )

        # If action leads to a permanent decision, notify the suggester and update statuses
        if action == RecommendationAction.keep_permanently:
            RecommendationEngine._apply_keep(trial_id, trial.suggestion_id, trial.suggestion_name)
        elif action == RecommendationAction.remove_item:
            RecommendationEngine._apply_remove(trial_id, trial.suggestion_id, trial.suggestion_name)

        return Recommendation(
            trial_id=trial_id,
            suggestion_name=trial.suggestion_name,
            action=action,
            confidence=confidence,
            reasoning=reasoning,
            computed_at=datetime.now(timezone.utc).isoformat(),
        )

    @staticmethod
    def _apply_keep(trial_id: str, suggestion_id: str, name: str) -> None:
        """Marks trial as decided and suggestion as permanent. Notifies suggester."""
        TrialRepository.mark_decided(trial_id)
        suggestion = SuggestionRepository.get_by_id(suggestion_id)
        SuggestionRepository.update_status(suggestion_id, SuggestionStatus.permanent)
        if suggestion:
            NotificationService.notify_item_permanent(
                user_uid=suggestion.suggested_by,
                suggestion_name=name,
                suggestion_id=suggestion_id,
            )

    @staticmethod
    def _apply_remove(trial_id: str, suggestion_id: str, name: str) -> None:
        """Marks trial as decided and suggestion as rejected. Notifies suggester."""
        TrialRepository.mark_decided(trial_id)
        suggestion = SuggestionRepository.get_by_id(suggestion_id)
        SuggestionRepository.update_status(suggestion_id, SuggestionStatus.rejected)
        if suggestion:
            NotificationService.notify_item_removed(
                user_uid=suggestion.suggested_by,
                suggestion_name=name,
                suggestion_id=suggestion_id,
            )
