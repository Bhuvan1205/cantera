from .repository import RecommendationRepository
from .schemas import RecommendationItem, RecommendationResponse

# ── Business rule constants ───────────────────────────────────────────────────
# These values are ported verbatim from the Dart implementation to preserve
# identical recommendation behaviour after the architectural migration.

_ORDER_THRESHOLD = 7      # orderCount >= 7 → personalized mode
_TOP_N = 5                # take(5) — maximum items returned
_MIN_CANDIDATES = 5       # supplement with global data if personal < this


class RecommendationService:
    """
    Authoritative recommendation business logic.

    Mirrors the Dart RecommendationService algorithm exactly —
    this is an architectural relocation, NOT a redesign.

    Algorithm:
        1. Fetch user's order history (limit 100).
        2. If orderCount >= 7  → personalized mode:
               a. Extract per-item frequency from user's own orders.
               b. If unique candidates < 5, supplement with CanteenBuzz global data.
               c. Merge and rank.
           Else                → discovery mode:
               a. Use CanteenBuzz global popularity data only.
        3. Sort by frequency descending; tie-break alphabetically by name.
        4. Return top 5 as RecommendationResponse.
    """

    @staticmethod
    def get_recommendations(uid: str) -> RecommendationResponse:
        """
        Main entry point.  UID must come from a verified Firebase ID token —
        never from a client-supplied query parameter.
        """
        # ── 1. Fetch user order history ───────────────────────────────────────
        user_orders = RecommendationRepository.get_user_orders(uid)
        order_count = len(user_orders)

        candidate_frequencies: dict[str, int] = {}
        updated_at: str | None = None

        if order_count >= _ORDER_THRESHOLD:
            # ── Personalized mode ─────────────────────────────────────────────
            candidate_frequencies = RecommendationService._extract_frequencies(user_orders)

            # Supplement with global data when personal candidates are sparse
            if len(candidate_frequencies) < _MIN_CANDIDATES:
                global_items, updated_at = RecommendationRepository.get_canteen_buzz()
                global_freq = RecommendationService._parse_canteen_buzz(global_items)
                RecommendationService._merge_frequencies(candidate_frequencies, global_freq)

            source = "personalized"

        else:
            # ── Discovery mode (new / infrequent user) ────────────────────────
            global_items, updated_at = RecommendationRepository.get_canteen_buzz()
            candidate_frequencies = RecommendationService._parse_canteen_buzz(global_items)
            source = "discovery"

        # ── 2. Empty data fallback ────────────────────────────────────────────
        # Mirrors Dart: if sortedCandidates.isEmpty → return whatever is available.
        # At this layer we simply return an empty list; the router returns it as
        # source="fallback". Flutter already handles empty recommendations gracefully.
        if not candidate_frequencies:
            return RecommendationResponse(
                recommendations=[],
                source="fallback",
                updated_at=updated_at,
            )

        # ── 3. Sort: frequency desc, name asc (tie-break) ────────────────────
        sorted_candidates = sorted(
            candidate_frequencies.items(),
            key=lambda kv: (-kv[1], kv[0]),
        )

        # ── 4. Take top N ─────────────────────────────────────────────────────
        top_items = [
            RecommendationItem(name=name, count=count)
            for name, count in sorted_candidates[:_TOP_N]
        ]

        return RecommendationResponse(
            recommendations=top_items,
            source=source,
            updated_at=updated_at,
        )

    # ── Private helpers ───────────────────────────────────────────────────────

    @staticmethod
    def _extract_frequencies(orders: list[dict]) -> dict[str, int]:
        """
        Counts item occurrences across a list of order dicts, weighted by quantity.

        Mirrors Dart _extractFrequencies exactly:
            for each order → for each item → freq[name] += quantity
        """
        freq: dict[str, int] = {}
        for order in orders:
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
                qty_raw = item.get("quantity")
                try:
                    qty = int(qty_raw) if qty_raw is not None else 1
                except (ValueError, TypeError):
                    qty = 1
                freq[name] = freq.get(name, 0) + qty
        return freq

    @staticmethod
    def _parse_canteen_buzz(top_items: list) -> dict[str, int]:
        """
        Converts the CanteenBuzz topItems array into a frequency dict.

        Mirrors Dart _fetchGlobalFrequencies:
            for each entry → freq[name] = count
        Note: names from CanteenBuzz are already lowercased by the Cloud Function.
        """
        freq: dict[str, int] = {}
        for item in top_items:
            if not isinstance(item, dict):
                continue
            name_raw = item.get("name")
            count_raw = item.get("count")
            if isinstance(name_raw, str) and isinstance(count_raw, (int, float)):
                freq[name_raw] = int(count_raw)
        return freq

    @staticmethod
    def _merge_frequencies(target: dict[str, int], source: dict[str, int]) -> None:
        """
        Additively merges source into target in-place.

        Mirrors Dart _mergeFrequencies:
            if key exists → target[key] += source[key]
            else          → target[key]  = source[key]
        """
        for key, value in source.items():
            if key in target:
                target[key] += value
            else:
                target[key] = value
