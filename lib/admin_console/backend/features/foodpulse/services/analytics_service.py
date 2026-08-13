"""
FoodPulse – Popularity Analytics Service.

Computes a composite popularity score for each suggestion using:
  - Vote Count         (weight: 0.40) — raw vote total
  - Recent Growth      (weight: 0.30) — vote velocity (recent vs older)
  - Seasonal Weight    (weight: 0.20) — category demand by time of day/month
  - Request Frequency  (weight: 0.10) — how many duplicate submissions were merged

All weights are configurable at the top of this file.

No analytics logic lives in the frontend — this service provides ranked data through the API.
"""

from __future__ import annotations

from datetime import datetime, timezone

from ..repository import SuggestionRepository
from ..schemas import PopularityScore, TrendingResponse, FoodSuggestion


# ── Configurable Weights ──────────────────────────────────────────────────────
WEIGHT_VOTES:            float = 0.40
WEIGHT_RECENT_GROWTH:    float = 0.30
WEIGHT_SEASONAL:         float = 0.20
WEIGHT_REQUEST_FREQ:     float = 0.10

# Seasonal category demand maps (multipliers by current hour ranges)
# Can be extended with month-based seasonality
_PEAK_BREAKFAST  = range(7, 10)   # 7am – 10am
_PEAK_LUNCH      = range(11, 15)  # 11am – 3pm
_PEAK_SNACK      = range(15, 18)  # 3pm – 6pm
_PEAK_DINNER     = range(18, 21)  # 6pm – 9pm

_CATEGORY_SEASONAL: dict[str, dict] = {
    "mess": {
        "peak_hours": list(_PEAK_LUNCH) + list(_PEAK_DINNER),
        "peak_multiplier": 1.5,
    },
    "bakery": {
        "peak_hours": list(_PEAK_BREAKFAST) + list(_PEAK_SNACK),
        "peak_multiplier": 1.4,
    },
    "beverages": {
        "peak_hours": list(_PEAK_BREAKFAST) + list(_PEAK_SNACK),
        "peak_multiplier": 1.3,
    },
    "continental": {
        "peak_hours": list(_PEAK_LUNCH) + list(_PEAK_SNACK),
        "peak_multiplier": 1.2,
    },
}


def _seasonal_weight(category: str) -> float:
    """
    Returns a seasonal weight multiplier based on current hour and category.
    Returns 1.0 (neutral) for unknown categories.
    """
    current_hour = datetime.now(timezone.utc).hour
    # Convert UTC to IST (UTC+5:30) for canteen context
    ist_hour = (current_hour + 5) % 24
    cat_data = _CATEGORY_SEASONAL.get(category.lower(), {})
    peak_hours = cat_data.get("peak_hours", [])
    multiplier = cat_data.get("peak_multiplier", 1.0)
    return float(multiplier) if ist_hour in peak_hours else 1.0


def _compute_score(suggestion: FoodSuggestion) -> float:
    """
    Computes the popularity score for a single suggestion.

    Formula:
      score = (norm_votes     × WEIGHT_VOTES)
            + (recent_growth  × WEIGHT_RECENT_GROWTH)
            + (seasonal       × WEIGHT_SEASONAL)
            + (request_freq   × WEIGHT_REQUEST_FREQ)

    Components are normalized to [0, 1] using practical caps:
      - votes:         cap at 200
      - recent_growth: always 0.5 (placeholder — needs time-series data)
      - seasonal:      (multiplier - 1.0) capped at 1.0
      - request_freq:  cap at 20
    """
    # Votes (normalized)
    vote_norm = min(suggestion.vote_count / 200, 1.0)

    # Recent growth — without time-series data we approximate from vote velocity
    # (request_count acts as a proxy for repeated interest)
    recent_growth = min(suggestion.request_count / 10, 1.0) * 0.5 + 0.5 * vote_norm

    # Seasonal weight (normalized from multiplier)
    seasonal = min((_seasonal_weight(suggestion.category) - 1.0) / 0.5, 1.0)

    # Request frequency (normalized)
    freq_norm = min(suggestion.request_count / 20, 1.0)

    score = (
        vote_norm     * WEIGHT_VOTES
        + recent_growth * WEIGHT_RECENT_GROWTH
        + seasonal      * WEIGHT_SEASONAL
        + freq_norm     * WEIGHT_REQUEST_FREQ
    )
    return round(score, 6)


class AnalyticsService:
    """Popularity scoring and trending list computation."""

    @staticmethod
    def compute_popularity(suggestion_id: str) -> float:
        """
        Computes and returns the popularity score for a single suggestion.
        Called by VotingService after each vote change.
        """
        suggestion = SuggestionRepository.get_by_id(suggestion_id)
        if not suggestion:
            return 0.0
        return _compute_score(suggestion)

    @staticmethod
    def get_trending(limit: int = 20) -> TrendingResponse:
        """
        Returns all suggestions ranked by popularity score descending.
        Scores are recomputed on-the-fly for freshness.
        """
        suggestions = SuggestionRepository.list_all(limit=500)
        from ..repository import TrialRepository
        active_trials_suggestion_ids = {t.suggestion_id for t in TrialRepository.list_active()}

        scored: list[PopularityScore] = []
        for suggestion in suggestions:
            # Task 1: Filter out completed trials. Only show active / pending trial items.
            if suggestion.status not in ("pending", "approved"):
                if suggestion.status != "in_trial" or suggestion.id not in active_trials_suggestion_ids:
                    continue

            score = _compute_score(suggestion)
            # Update score in DB asynchronously (best-effort, no strict need)
            SuggestionRepository.update_popularity_score(suggestion.id, score)

            recent_growth = min(suggestion.request_count / 10, 1.0) * 0.5
            seasonal = _seasonal_weight(suggestion.category)
            freq = min(suggestion.request_count / 20, 1.0)

            scored.append(PopularityScore(
                suggestion_id=suggestion.id,
                name=suggestion.name,
                category=suggestion.category,
                vote_count=suggestion.vote_count,
                recent_growth=round(recent_growth, 4),
                seasonal_weight=round(seasonal, 4),
                request_frequency=round(freq, 4),
                popularity_score=round(score, 4),
                rank=0,  # filled below
            ))

        # Sort by actual user activity: vote_count descending, then request_count descending
        scored.sort(key=lambda x: (x.vote_count, x.request_frequency), reverse=True)
        for i, item in enumerate(scored[:limit], start=1):
            item.rank = i

        return TrendingResponse(
            items=scored[:limit],
            computed_at=datetime.now(timezone.utc).isoformat(),
        )
