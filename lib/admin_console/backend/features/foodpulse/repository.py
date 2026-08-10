"""
FoodPulse – Firestore repository layer.

Handles all CRUD operations for the five new FoodPulse collections:
  - food_suggestions
  - suggestion_votes
  - food_trials
  - trial_metrics
  - foodpulse_notifications

Pattern mirrors existing repositories (OrderRepository, InventoryRepository, etc.).
Only reads/writes to new collections — no existing collections are touched.
"""

from __future__ import annotations

from datetime import datetime, timezone, timedelta
from typing import Optional

from google.cloud import firestore

from config.firebase import db
from .schemas import (
    FoodSuggestion,
    SuggestionStatus,
    VoteRecord,
    TrialItem,
    TrialStatus,
    TrialMetric,
    FoodPulseNotification,
    CreateSuggestionRequest,
    StartTrialRequest,
    RecordMetricRequest,
    CreatePollRequest,
    FoodPulsePoll,
    PollOption,
)

# ── Collection names (new — no existing collections modified) ─────────────────
_SUGGESTIONS_COL   = "food_suggestions"
_VOTES_COL         = "suggestion_votes"
_TRIALS_COL        = "food_trials"
_METRICS_COL       = "trial_metrics"
_NOTIF_COL         = "foodpulse_notifications"
_POLLS_COL         = "foodpulse_polls"
_POLL_VOTES_COL    = "foodpulse_poll_votes"



def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


# ─────────────────────────────────────────────────────────────────────────────
# Suggestion Repository
# ─────────────────────────────────────────────────────────────────────────────

class SuggestionRepository:
    """Firestore CRUD for food_suggestions collection."""

    @staticmethod
    def create(
        payload: CreateSuggestionRequest,
        normalized_name: str,
        user_uid: str,
    ) -> FoodSuggestion:
        ref = db.collection(_SUGGESTIONS_COL).document()
        now = _now_iso()
        data = {
            "name": payload.name,
            "normalized_name": normalized_name,
            "description": payload.description,
            "category": payload.category,
            "suggested_price": payload.suggested_price,
            "suggested_by": user_uid,
            "status": SuggestionStatus.pending,
            "vote_count": 0,
            "popularity_score": 0.0,
            "request_count": 1,
            "created_at": firestore.SERVER_TIMESTAMP,
            "updated_at": firestore.SERVER_TIMESTAMP,
        }
        ref.set(data)
        data["created_at"] = now
        data["updated_at"] = now
        return FoodSuggestion.from_firestore(ref.id, data)

    @staticmethod
    def get_by_id(suggestion_id: str) -> Optional[FoodSuggestion]:
        snap = db.collection(_SUGGESTIONS_COL).document(suggestion_id).get()
        if not snap.exists:
            return None
        return FoodSuggestion.from_firestore(snap.id, snap.to_dict() or {})

    @staticmethod
    def list_all(status_filter: Optional[str] = None, limit: int = 100) -> list[FoodSuggestion]:
        query = db.collection(_SUGGESTIONS_COL)
        if status_filter:
            query = query.where("status", "==", status_filter)
        docs = query.limit(limit).stream()
        items = [FoodSuggestion.from_firestore(d.id, d.to_dict() or {}) for d in docs]
        items.sort(key=lambda x: x.vote_count, reverse=True)
        return items

    @staticmethod
    def list_by_user(user_uid: str) -> list[FoodSuggestion]:
        docs = (
            db.collection(_SUGGESTIONS_COL)
            .where("suggested_by", "==", user_uid)
            .stream()
        )
        return [FoodSuggestion.from_firestore(d.id, d.to_dict() or {}) for d in docs]

    @staticmethod
    def has_user_suggested_item(user_uid: str, normalized_name: str) -> bool:
        docs = (
            db.collection(_SUGGESTIONS_COL)
            .where("suggested_by", "==", user_uid)
            .where("normalized_name", "==", normalized_name)
            .limit(1)
            .stream()
        )
        return any(True for _ in docs)


    @staticmethod
    def list_all_normalized() -> list[dict]:
        """Returns minimal dicts (id, normalized_name) for duplicate scanning."""
        docs = db.collection(_SUGGESTIONS_COL).stream()
        return [
            {"id": d.id, "normalized_name": (d.to_dict() or {}).get("normalized_name", "")}
            for d in docs
        ]

    @staticmethod
    def increment_request_count(suggestion_id: str) -> None:
        db.collection(_SUGGESTIONS_COL).document(suggestion_id).update({
            "request_count": firestore.Increment(1),
            "updated_at": firestore.SERVER_TIMESTAMP,
        })

    @staticmethod
    def update_vote_count(suggestion_id: str, delta: int) -> None:
        db.collection(_SUGGESTIONS_COL).document(suggestion_id).update({
            "vote_count": firestore.Increment(delta),
            "updated_at": firestore.SERVER_TIMESTAMP,
        })

    @staticmethod
    def update_popularity_score(suggestion_id: str, score: float) -> None:
        db.collection(_SUGGESTIONS_COL).document(suggestion_id).update({
            "popularity_score": score,
            "updated_at": firestore.SERVER_TIMESTAMP,
        })

    @staticmethod
    def update_status(suggestion_id: str, status: SuggestionStatus, notes: str = "") -> Optional[FoodSuggestion]:
        update: dict = {
            "status": status,
            "updated_at": firestore.SERVER_TIMESTAMP,
        }
        if notes:
            update["admin_notes"] = notes
        db.collection(_SUGGESTIONS_COL).document(suggestion_id).update(update)
        return SuggestionRepository.get_by_id(suggestion_id)


# ─────────────────────────────────────────────────────────────────────────────
# Vote Repository
# ─────────────────────────────────────────────────────────────────────────────

class VoteRepository:
    """Firestore CRUD for suggestion_votes collection."""

    @staticmethod
    def _vote_doc_id(suggestion_id: str, user_uid: str) -> str:
        """Deterministic document ID ensures 1 vote per user per suggestion."""
        return f"{suggestion_id}__{user_uid}"

    @staticmethod
    def has_voted(suggestion_id: str, user_uid: str) -> bool:
        doc_id = VoteRepository._vote_doc_id(suggestion_id, user_uid)
        return db.collection(_VOTES_COL).document(doc_id).get().exists

    @staticmethod
    def cast_vote(suggestion_id: str, user_uid: str) -> VoteRecord:
        doc_id = VoteRepository._vote_doc_id(suggestion_id, user_uid)
        data = {
            "suggestion_id": suggestion_id,
            "user_id": user_uid,
            "voted_at": firestore.SERVER_TIMESTAMP,
        }
        db.collection(_VOTES_COL).document(doc_id).set(data)
        return VoteRecord.from_firestore(doc_id, data)

    @staticmethod
    def remove_vote(suggestion_id: str, user_uid: str) -> None:
        doc_id = VoteRepository._vote_doc_id(suggestion_id, user_uid)
        db.collection(_VOTES_COL).document(doc_id).delete()

    @staticmethod
    def count_votes(suggestion_id: str) -> int:
        docs = (
            db.collection(_VOTES_COL)
            .where("suggestion_id", "==", suggestion_id)
            .stream()
        )
        return sum(1 for _ in docs)

    @staticmethod
    def total_votes_across_all() -> int:
        docs = db.collection(_VOTES_COL).stream()
        return sum(1 for _ in docs)


# ─────────────────────────────────────────────────────────────────────────────
# Trial Repository
# ─────────────────────────────────────────────────────────────────────────────

class TrialRepository:
    """Firestore CRUD for food_trials collection."""

    @staticmethod
    def create(
        payload: StartTrialRequest,
        suggestion_name: str,
        category: str,
        admin_uid: str,
    ) -> TrialItem:
        ref = db.collection(_TRIALS_COL).document()
        now = datetime.now(timezone.utc)
        ends_at = now + timedelta(days=payload.trial_duration_days)
        data = {
            "suggestion_id": payload.suggestion_id,
            "suggestion_name": suggestion_name,
            "category": category,
            "status": TrialStatus.active,
            "trial_duration_days": payload.trial_duration_days,
            "predicted_daily_orders": payload.predicted_daily_orders,
            "notes": payload.notes,
            "started_by": admin_uid,
            "started_at": firestore.SERVER_TIMESTAMP,
            "ends_at": ends_at.isoformat(),
            "completed_at": None,
        }
        ref.set(data)
        data["started_at"] = now.isoformat()
        return TrialItem.from_firestore(ref.id, data)

    @staticmethod
    def get_by_id(trial_id: str) -> Optional[TrialItem]:
        snap = db.collection(_TRIALS_COL).document(trial_id).get()
        if not snap.exists:
            return None
        return TrialItem.from_firestore(snap.id, snap.to_dict() or {})

    @staticmethod
    def list_active() -> list[TrialItem]:
        docs = db.collection(_TRIALS_COL).where("status", "==", TrialStatus.active).stream()
        return [TrialItem.from_firestore(d.id, d.to_dict() or {}) for d in docs]

    @staticmethod
    def list_all(limit: int = 50) -> list[TrialItem]:
        docs = db.collection(_TRIALS_COL).limit(limit).stream()
        return [TrialItem.from_firestore(d.id, d.to_dict() or {}) for d in docs]

    @staticmethod
    def complete_trial(trial_id: str, notes: str) -> Optional[TrialItem]:
        now = datetime.now(timezone.utc).isoformat()
        update = {
            "status": TrialStatus.completed,
            "completed_at": now,
        }
        if notes:
            update["closing_notes"] = notes
        db.collection(_TRIALS_COL).document(trial_id).update(update)
        return TrialRepository.get_by_id(trial_id)

    @staticmethod
    def mark_decided(trial_id: str) -> None:
        db.collection(_TRIALS_COL).document(trial_id).update({"status": TrialStatus.decided})


# ─────────────────────────────────────────────────────────────────────────────
# Trial Metrics Repository
# ─────────────────────────────────────────────────────────────────────────────

class MetricsRepository:
    """Firestore CRUD for trial_metrics collection."""

    @staticmethod
    def record(trial_id: str, payload: RecordMetricRequest) -> TrialMetric:
        """Idempotent — uses trial_id + date as the document ID."""
        doc_id = f"{trial_id}__{payload.date}"
        orders = payload.orders
        cancellations = payload.cancellations
        cancel_rate = round(cancellations / orders, 4) if orders > 0 else 0.0
        data = {
            "trial_id": trial_id,
            "date": payload.date,
            "orders": orders,
            "revenue": payload.revenue,
            "avg_rating": payload.avg_rating,
            "repeat_purchases": payload.repeat_purchases,
            "cancellations": cancellations,
            "cancellation_rate": cancel_rate,
            "recorded_at": firestore.SERVER_TIMESTAMP,
        }
        db.collection(_METRICS_COL).document(doc_id).set(data, merge=True)
        return TrialMetric.from_firestore(doc_id, data)

    @staticmethod
    def list_for_trial(trial_id: str) -> list[TrialMetric]:
        docs = (
            db.collection(_METRICS_COL)
            .where("trial_id", "==", trial_id)
            .stream()
        )
        metrics = [TrialMetric.from_firestore(d.id, d.to_dict() or {}) for d in docs]
        metrics.sort(key=lambda m: m.date)
        return metrics


# ─────────────────────────────────────────────────────────────────────────────
# Notification Repository
# ─────────────────────────────────────────────────────────────────────────────

class NotificationRepository:
    """Firestore CRUD for foodpulse_notifications/{uid}/messages/ subcollection."""

    @staticmethod
    def push(
        user_uid: str,
        title: str,
        body: str,
        notif_type: str,
        reference_id: Optional[str] = None,
    ) -> FoodPulseNotification:
        ref = (
            db.collection(_NOTIF_COL)
            .document(user_uid)
            .collection("messages")
            .document()
        )
        data = {
            "title": title,
            "body": body,
            "type": notif_type,
            "reference_id": reference_id,
            "read": False,
            "created_at": firestore.SERVER_TIMESTAMP,
        }
        ref.set(data)
        return FoodPulseNotification.from_firestore(ref.id, user_uid, data)

    @staticmethod
    def list_for_user(user_uid: str, limit: int = 30) -> list[FoodPulseNotification]:
        docs = (
            db.collection(_NOTIF_COL)
            .document(user_uid)
            .collection("messages")
            .limit(limit)
            .stream()
        )
        notifs = [FoodPulseNotification.from_firestore(d.id, user_uid, d.to_dict() or {}) for d in docs]
        notifs.sort(key=lambda n: str(n.created_at or ""), reverse=True)
        return notifs

    @staticmethod
    def mark_read(user_uid: str, notif_id: str) -> None:
        (
            db.collection(_NOTIF_COL)
            .document(user_uid)
            .collection("messages")
            .document(notif_id)
            .update({"read": True})
        )


# ─────────────────────────────────────────────────────────────────────────────
# Poll Repository
# ─────────────────────────────────────────────────────────────────────────────

class PollRepository:
    """Firestore CRUD for foodpulse_polls and foodpulse_poll_votes collections."""

    @staticmethod
    def create(payload: CreatePollRequest, admin_uid: str) -> FoodPulsePoll:
        # Close any currently active poll first
        active = PollRepository.get_active_poll()
        if active:
            PollRepository.close_poll(active.id)

        ref = db.collection(_POLLS_COL).document()
        now = _now_iso()
        options = [
            {"id": f"opt_{i}", "text": text, "vote_count": 0}
            for i, text in enumerate(payload.options)
        ]
        data = {
            "question": payload.question,
            "section": payload.section,
            "options": options,
            "status": "active",
            "total_votes": 0,
            "created_at": firestore.SERVER_TIMESTAMP,
            "created_by": admin_uid,
        }
        ref.set(data)
        data["created_at"] = now
        return FoodPulsePoll.from_firestore(ref.id, data)

    @staticmethod
    def get_active_poll() -> Optional[FoodPulsePoll]:
        docs = (
            db.collection(_POLLS_COL)
            .where("status", "==", "active")
            .limit(1)
            .stream()
        )
        for d in docs:
            return FoodPulsePoll.from_firestore(d.id, d.to_dict() or {})
        return None

    @staticmethod
    def get_by_id(poll_id: str) -> Optional[FoodPulsePoll]:
        snap = db.collection(_POLLS_COL).document(poll_id).get()
        if not snap.exists:
            return None
        return FoodPulsePoll.from_firestore(snap.id, snap.to_dict() or {})

    @staticmethod
    def has_user_voted(poll_id: str, user_uid: str) -> bool:
        doc_id = f"{poll_id}_{user_uid}"
        snap = db.collection(_POLL_VOTES_COL).document(doc_id).get()
        return snap.exists

    @staticmethod
    def cast_vote(poll_id: str, option_id: str, user_uid: str) -> bool:
        doc_id = f"{poll_id}_{user_uid}"
        vote_ref = db.collection(_POLL_VOTES_COL).document(doc_id)
        if vote_ref.get().exists:
            return False

        now = _now_iso()
        vote_ref.set({
            "poll_id": poll_id,
            "option_id": option_id,
            "user_id": user_uid,
            "voted_at": firestore.SERVER_TIMESTAMP,
        })

        poll_ref = db.collection(_POLLS_COL).document(poll_id)
        snap = poll_ref.get()
        if snap.exists:
            data = snap.to_dict() or {}
            options = data.get("options", [])
            for opt in options:
                if str(opt.get("id")) == option_id:
                    opt["vote_count"] = int(opt.get("vote_count", 0)) + 1
                    break
            total_votes = int(data.get("total_votes", 0)) + 1
            poll_ref.update({
                "options": options,
                "total_votes": total_votes,
            })
        return True

    @staticmethod
    def close_poll(poll_id: str) -> Optional[FoodPulsePoll]:
        poll_ref = db.collection(_POLLS_COL).document(poll_id)
        snap = poll_ref.get()
        if not snap.exists:
            return None
        now = _now_iso()
        poll_ref.update({
            "status": "closed",
            "closed_at": firestore.SERVER_TIMESTAMP,
        })
        updated = poll_ref.get()
        return FoodPulsePoll.from_firestore(poll_id, updated.to_dict() or {})

