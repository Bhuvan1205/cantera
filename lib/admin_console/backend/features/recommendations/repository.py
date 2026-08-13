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
            if doc.exists:
                data = doc.to_dict() or {}
                top_items = data.get("topItems", [])
                if not isinstance(top_items, list):
                    top_items = []

                raw_ts = data.get("updatedAt")
                updated_at = str(raw_ts) if raw_ts is not None else None

                return top_items, updated_at
                
            # ── Emergency Fallback ──────────────────────────────────────────────
            # If the scheduled Cloud Function hasn't run or is blocked from deploying,
            # we compute the latest 30 orders on-the-fly to guarantee recommendations.
            return RecommendationRepository._compute_emergency_fallback()
        except Exception:
            return [], None

    @staticmethod
    def _compute_emergency_fallback() -> tuple[list[dict], str | None]:
        try:
            docs = (
                db.collection(_ORDERS_COL)
                .order_by("timestamp", direction=firestore.Query.DESCENDING)
                .limit(30)
                .stream()
            )
            freq: dict[str, int] = {}
            for doc in docs:
                order = doc.to_dict() or {}
                items = order.get("items", [])
                if not isinstance(items, list):
                    continue
                for item in items:
                    if not isinstance(item, dict):
                        continue
                    name_raw = item.get("name")
                    if not name_raw or not isinstance(name_raw, str):
                        continue
                    name = name_raw.lower().strip()
                    qty_raw = item.get("quantity", 1)
                    try:
                        qty = int(qty_raw)
                    except (ValueError, TypeError):
                        qty = 1
                    freq[name] = freq.get(name, 0) + qty

            sorted_items = sorted(freq.items(), key=lambda kv: (-kv[1], kv[0]))
            top_items = [{"name": k, "count": v} for k, v in sorted_items[:5]]
            return top_items, None
        except Exception:
            return [], None
