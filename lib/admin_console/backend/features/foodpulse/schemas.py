"""
FoodPulse – Pydantic schemas for all five new Firestore collections.

New Collections:
  food_suggestions       – Student-submitted food item suggestions
  suggestion_votes       – Per-user vote records (1 vote per user per suggestion)
  food_trials            – Vendor-approved trial items
  trial_metrics          – Daily performance metrics per trial
  foodpulse_notifications – Notification documents per user

No existing collections are modified.
"""

from __future__ import annotations

from datetime import datetime
from enum import Enum
from typing import Optional

from pydantic import BaseModel, Field


# ─────────────────────────────────────────────
# Enums
# ─────────────────────────────────────────────

class SuggestionStatus(str, Enum):
    pending   = "pending"
    approved  = "approved"
    rejected  = "rejected"
    in_trial  = "in_trial"
    permanent = "permanent"


class TrialStatus(str, Enum):
    active    = "active"
    completed = "completed"
    decided   = "decided"


class RecommendationAction(str, Enum):
    keep_permanently = "keep_permanently"
    extend_trial     = "extend_trial"
    modify_item      = "modify_item"
    remove_item      = "remove_item"


# ─────────────────────────────────────────────
# Suggestion schemas
# ─────────────────────────────────────────────

class CreateSuggestionRequest(BaseModel):
    """Payload for POST /foodpulse/suggestions — submitted by a student."""
    name: str         = Field(..., min_length=2, max_length=120, description="Food item name")
    description: str  = Field("", max_length=500, description="Optional description")
    category: str     = Field("general", description="mess | bakery | beverages | continental | general")
    suggested_price: Optional[int] = Field(None, ge=0, description="Optional suggested price in rupees")


class FoodSuggestion(BaseModel):
    """Represents one document in the food_suggestions collection."""
    id: str
    name: str
    normalized_name: str
    description: str
    category: str
    suggested_price: Optional[int]
    suggested_by: str                       # Firebase uid
    status: SuggestionStatus
    vote_count: int
    popularity_score: float
    request_count: int                      # how many duplicate attempts were merged
    created_at: Optional[str]
    updated_at: Optional[str]

    @classmethod
    def from_firestore(cls, doc_id: str, data: dict) -> "FoodSuggestion":
        def _ts(val) -> Optional[str]:
            return str(val) if val is not None else None

        return cls(
            id=doc_id,
            name=data.get("name", ""),
            normalized_name=data.get("normalized_name", ""),
            description=data.get("description", ""),
            category=data.get("category", "general"),
            suggested_price=data.get("suggested_price"),
            suggested_by=data.get("suggested_by", ""),
            status=data.get("status", SuggestionStatus.pending),
            vote_count=int(data.get("vote_count", 0)),
            popularity_score=float(data.get("popularity_score", 0.0)),
            request_count=int(data.get("request_count", 1)),
            created_at=_ts(data.get("created_at")),
            updated_at=_ts(data.get("updated_at")),
        )


class ApproveSuggestionRequest(BaseModel):
    """Payload for POST /foodpulse/suggestions/{id}/approve."""
    notes: str = Field("", description="Admin approval notes")


class RejectSuggestionRequest(BaseModel):
    """Payload for POST /foodpulse/suggestions/{id}/reject."""
    reason: str = Field("", description="Reason for rejection")


# ─────────────────────────────────────────────
# Vote schemas
# ─────────────────────────────────────────────

class VoteRecord(BaseModel):
    """One document in suggestion_votes collection."""
    id: str
    suggestion_id: str
    user_id: str
    voted_at: Optional[str]

    @classmethod
    def from_firestore(cls, doc_id: str, data: dict) -> "VoteRecord":
        return cls(
            id=doc_id,
            suggestion_id=data.get("suggestion_id", ""),
            user_id=data.get("user_id", ""),
            voted_at=str(data.get("voted_at")) if data.get("voted_at") else None,
        )


class VoteResponse(BaseModel):
    """Response for vote endpoints."""
    suggestion_id: str
    voted: bool
    vote_count: int


# ─────────────────────────────────────────────
# Trending / Analytics schemas
# ─────────────────────────────────────────────

class PopularityScore(BaseModel):
    """Computed popularity breakdown for a suggestion."""
    suggestion_id: str
    name: str
    category: str
    vote_count: int
    recent_growth: float
    seasonal_weight: float
    request_frequency: float
    popularity_score: float
    rank: int


class TrendingResponse(BaseModel):
    """Response for GET /foodpulse/trending."""
    items: list[PopularityScore]
    computed_at: str


# ─────────────────────────────────────────────
# Trial schemas
# ─────────────────────────────────────────────

class StartTrialRequest(BaseModel):
    """Payload for POST /foodpulse/trial/start."""
    suggestion_id: str   = Field(..., description="ID of the approved suggestion to trial")
    trial_duration_days: int = Field(7, ge=1, le=90, description="Duration of the trial in days")
    predicted_daily_orders: int = Field(10, ge=0, description="Vendor's demand prediction (orders/day)")
    notes: str           = Field("", description="Optional trial notes")


class TrialItem(BaseModel):
    """One document in food_trials collection."""
    id: str
    suggestion_id: str
    suggestion_name: str
    category: str
    status: TrialStatus
    trial_duration_days: int
    predicted_daily_orders: int
    started_at: Optional[str]
    ends_at: Optional[str]
    completed_at: Optional[str]
    notes: str
    started_by: str                         # admin uid

    @classmethod
    def from_firestore(cls, doc_id: str, data: dict) -> "TrialItem":
        def _ts(val) -> Optional[str]:
            return str(val) if val is not None else None

        return cls(
            id=doc_id,
            suggestion_id=data.get("suggestion_id", ""),
            suggestion_name=data.get("suggestion_name", ""),
            category=data.get("category", "general"),
            status=data.get("status", TrialStatus.active),
            trial_duration_days=int(data.get("trial_duration_days", 7)),
            predicted_daily_orders=int(data.get("predicted_daily_orders", 0)),
            started_at=_ts(data.get("started_at")),
            ends_at=_ts(data.get("ends_at")),
            completed_at=_ts(data.get("completed_at")),
            notes=data.get("notes", ""),
            started_by=data.get("started_by", ""),
        )


class EndTrialRequest(BaseModel):
    """Payload for POST /foodpulse/trial/end/{trial_id}."""
    notes: str = Field("", description="Closing notes from vendor")


# ─────────────────────────────────────────────
# Trial Metrics schemas
# ─────────────────────────────────────────────

class RecordMetricRequest(BaseModel):
    """Payload for POST /foodpulse/trial/{trial_id}/metrics — one day of data."""
    date: str               = Field(..., description="Date of measurement (YYYY-MM-DD)")
    orders: int             = Field(0, ge=0)
    revenue: int            = Field(0, ge=0, description="Revenue in rupees")
    avg_rating: float       = Field(0.0, ge=0.0, le=5.0)
    repeat_purchases: int   = Field(0, ge=0)
    cancellations: int      = Field(0, ge=0)


class TrialMetric(BaseModel):
    """One document in trial_metrics collection."""
    id: str
    trial_id: str
    date: str
    orders: int
    revenue: int
    avg_rating: float
    repeat_purchases: int
    cancellations: int
    cancellation_rate: float

    @classmethod
    def from_firestore(cls, doc_id: str, data: dict) -> "TrialMetric":
        orders = int(data.get("orders", 0))
        cancellations = int(data.get("cancellations", 0))
        cancel_rate = round(cancellations / orders, 4) if orders > 0 else 0.0
        return cls(
            id=doc_id,
            trial_id=data.get("trial_id", ""),
            date=data.get("date", ""),
            orders=orders,
            revenue=int(data.get("revenue", 0)),
            avg_rating=float(data.get("avg_rating", 0.0)),
            repeat_purchases=int(data.get("repeat_purchases", 0)),
            cancellations=cancellations,
            cancellation_rate=data.get("cancellation_rate", cancel_rate),
        )


class TrialAnalytics(BaseModel):
    """Aggregated analytics for a trial (GET /foodpulse/analytics/{trial_id})."""
    trial_id: str
    trial_name: str
    status: str
    total_orders: int
    total_revenue: int
    avg_daily_orders: float
    avg_rating: float
    total_repeat_purchases: int
    avg_cancellation_rate: float
    predicted_daily_orders: int
    performance_vs_prediction_pct: float    # % of prediction achieved
    daily_breakdown: list[TrialMetric]


# ─────────────────────────────────────────────
# Recommendation schemas
# ─────────────────────────────────────────────

class Recommendation(BaseModel):
    """Output of the recommendation engine for a completed trial."""
    trial_id: str
    suggestion_name: str
    action: RecommendationAction
    confidence: float                       # 0.0 – 1.0
    reasoning: str
    computed_at: str


# ─────────────────────────────────────────────
# Notification schemas
# ─────────────────────────────────────────────

class FoodPulseNotification(BaseModel):
    """One document in foodpulse_notifications/{uid}/messages/."""
    id: str
    user_id: str
    title: str
    body: str
    type: str                               # suggestion_approved | trial_started | trial_ended | item_permanent | item_removed
    reference_id: Optional[str]            # suggestion_id or trial_id
    read: bool
    created_at: Optional[str]

    @classmethod
    def from_firestore(cls, doc_id: str, uid: str, data: dict) -> "FoodPulseNotification":
        return cls(
            id=doc_id,
            user_id=uid,
            title=data.get("title", ""),
            body=data.get("body", ""),
            type=data.get("type", ""),
            reference_id=data.get("reference_id"),
            read=data.get("read", False),
            created_at=str(data.get("created_at")) if data.get("created_at") else None,
        )


# ─────────────────────────────────────────────
# Poll schemas
# ─────────────────────────────────────────────

class PollOption(BaseModel):
    id: str
    text: str
    vote_count: int = 0


class CreatePollRequest(BaseModel):
    question: str = Field(..., min_length=3, max_length=250, description="Poll question")
    section: str  = Field(..., description="Bakery | Mess | Continental | Beverages")
    options: list[str] = Field(..., min_length=2, max_length=6, description="List of option texts")


class FoodPulsePoll(BaseModel):
    id: str
    question: str
    section: str
    options: list[PollOption]
    status: str                             # active | closed
    total_votes: int
    created_at: Optional[str]
    closed_at: Optional[str]
    created_by: str

    @classmethod
    def from_firestore(cls, doc_id: str, data: dict) -> "FoodPulsePoll":
        opts = []
        for i, o in enumerate(data.get("options", [])):
            if isinstance(o, dict):
                opts.append(PollOption(
                    id=str(o.get("id", f"opt_{i}")),
                    text=str(o.get("text", "")),
                    vote_count=int(o.get("vote_count", 0)),
                ))
            else:
                opts.append(PollOption(id=f"opt_{i}", text=str(o), vote_count=0))

        return cls(
            id=doc_id,
            question=data.get("question", ""),
            section=data.get("section", "general"),
            options=opts,
            status=data.get("status", "active"),
            total_votes=int(data.get("total_votes", 0)),
            created_at=str(data.get("created_at")) if data.get("created_at") else None,
            closed_at=str(data.get("closed_at")) if data.get("closed_at") else None,
            created_by=data.get("created_by", ""),
        )


class CastPollVoteRequest(BaseModel):
    option_id: str = Field(..., description="ID of selected option")


class PollVoteResponse(BaseModel):
    poll_id: str
    option_id: str
    message: str


# ─────────────────────────────────────────────
# Vendor Dashboard schema
# ─────────────────────────────────────────────

class VendorDashboardResponse(BaseModel):
    """Aggregated response for GET /foodpulse/vendor/dashboard."""
    pending_suggestions: list[FoodSuggestion]
    approved_suggestions: list[FoodSuggestion]
    top_requested: list[PopularityScore]
    active_trials: list[TrialItem]
    active_poll: Optional[FoodPulsePoll]
    total_suggestions: int
    total_votes: int

