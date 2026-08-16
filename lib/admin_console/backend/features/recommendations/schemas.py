from pydantic import BaseModel
from typing import Optional


# ── Sub-schemas ───────────────────────────────────────────────────────────────

class RecommendationItem(BaseModel):
    """
    A single recommended menu item returned by the recommendations endpoint.
    Uses item name (normalised to lowercase) so Flutter can map it against the
    locally-cached Menu stream — matching the existing Dart behaviour exactly.
    """
    name: str
    count: int


# ── Response ──────────────────────────────────────────────────────────────────

class RecommendationResponse(BaseModel):
    """
    Response returned by GET /api/recommendations.

    source:
      - "personalized"  — user has >= 7 orders; recs are derived from their history
      - "discovery"     — user has < 7 orders; recs come from global CanteenBuzz
      - "fallback"      — CanteenBuzz unavailable; top available menu items used

    updated_at:
      ISO-8601 string of when CanteenBuzz was last written by the Cloud Function,
      or None when only personal data is used.
    """
    recommendations: list[RecommendationItem]
    source: str  # "personalized" | "discovery" | "fallback"
    updated_at: Optional[str] = None
