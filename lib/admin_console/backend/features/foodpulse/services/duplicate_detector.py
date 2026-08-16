"""
FoodPulse – Duplicate Detection Engine.

All similarity logic lives here — no duplicate detection in the frontend.

Algorithm:
  1. Normalize both strings (lowercase, strip punctuation, collapse whitespace)
  2. Compute similarity ratio using difflib.SequenceMatcher (stdlib, no extra deps)
  3. If ratio >= SIMILARITY_THRESHOLD, treat as duplicate and return the existing ID
  4. Otherwise return None (new suggestion)

The threshold is configurable at the top of this file.
"""

from __future__ import annotations

import re
import unicodedata
from difflib import SequenceMatcher
from typing import Optional


# ── Configurable Threshold ────────────────────────────────────────────────────
# Raise to make duplicate detection stricter (fewer merges).
# Lower to catch more near-duplicates.
SIMILARITY_THRESHOLD: float = 0.82


def normalize_text(text: str) -> str:
    """
    Normalizes a food item name for similarity comparison.

    Steps:
      - Unicode NFC normalization
      - Lowercase
      - Remove punctuation and special characters
      - Collapse multiple whitespace into single space
      - Strip leading/trailing whitespace
    """
    # Unicode normalization
    text = unicodedata.normalize("NFC", text)
    # Lowercase
    text = text.lower()
    # Remove punctuation / special characters (keep alphanumerics + spaces)
    text = re.sub(r"[^\w\s]", " ", text)
    # Collapse whitespace
    text = re.sub(r"\s+", " ", text).strip()
    return text


def similarity_ratio(a: str, b: str) -> float:
    """
    Returns the similarity ratio between two normalized strings (0.0 – 1.0).
    Uses SequenceMatcher which handles common food name variations well.
    """
    return SequenceMatcher(None, a, b).ratio()


def find_duplicate(normalized_name: str, existing: list[dict]) -> Optional[str]:
    """
    Checks whether `normalized_name` is similar enough to any existing suggestion.

    Args:
        normalized_name: The normalized name of the new suggestion.
        existing: List of dicts with keys 'id' and 'normalized_name'.

    Returns:
        The ID of the matching existing suggestion, or None if no duplicate found.
    """
    best_ratio = 0.0
    best_id: Optional[str] = None

    for entry in existing:
        ratio = similarity_ratio(normalized_name, entry.get("normalized_name", ""))
        if ratio > best_ratio:
            best_ratio = ratio
            best_id = entry["id"]

    if best_ratio >= SIMILARITY_THRESHOLD:
        return best_id
    return None
