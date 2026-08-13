from google.cloud import firestore
from config.firebase import db

_ORDERS_COL = "Orders"
_RECOMMENDATIONS_COL = "Recommendations"
_CANTEEN_BUZZ_DOC = "CanteenBuzz"

# Mirrors the Dart constant: .limit(100)
_USER_ORDER_LIMIT = 100


class RecommendationRepository:
    """
    Firestore read operations for the recommendation feature.

    All Firestore access for recommendations is isolated here —
    the service layer never touches db directly.
    """

    @staticmethod
    def get_user_orders(uid: str) -> list[dict]:
        """
        Fetches the most recent orders belonging to the given user.

        Mirrors the Dart query exactly:
            FirebaseFirestore.instance
                .collection('Orders')
                .where('userId', isEqualTo: uid)
                .orderBy('timestamp', descending: true)
                .limit(100)
                .get(...)

        Returns a list of raw Firestore document dicts.
        """
        try:
            docs = (
                db.collection(_ORDERS_COL)
                .where("userId", "==", uid)
                .order_by("timestamp", direction=firestore.Query.DESCENDING)
                .limit(_USER_ORDER_LIMIT)
                .stream()
            )
            return [doc.to_dict() or {} for doc in docs]
        except Exception:
            return []

    @staticmethod
    def get_canteen_buzz() -> tuple[list[dict], str | None]:
        """
        Reads the precomputed Recommendations/CanteenBuzz document written by
        the updateCanteenBuzz Cloud Function every 10 minutes.

        Returns:
            (top_items, updated_at_str)
            top_items    — list of {"name": str, "count": int} dicts
            updated_at   — ISO-8601 string of last update, or None
        """
        try:
            doc = (
                db.collection(_RECOMMENDATIONS_COL)
                .document(_CANTEEN_BUZZ_DOC)
                .get()
            )
            if not doc.exists:
                return [], None

            data = doc.to_dict() or {}
            top_items = data.get("topItems", [])
            if not isinstance(top_items, list):
                top_items = []

            raw_ts = data.get("updatedAt")
            updated_at = str(raw_ts) if raw_ts is not None else None

            return top_items, updated_at
        except Exception:
            return [], None
