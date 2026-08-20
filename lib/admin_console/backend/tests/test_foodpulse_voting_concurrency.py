import asyncio
import pytest
from fastapi.testclient import TestClient
from unittest.mock import patch

from main import app
from config.firebase import db
from features.foodpulse.repository import _SUGGESTIONS_COL, _VOTES_COL

client = TestClient(app)

def _make_mock_token(uid: str):
    return {
        "uid": uid,
        "email": f"{uid}@mvsrec.edu.in",
        "sub": uid,
    }


def _setup_suggestion(suggested_by: str = "creator_uid"):
    # Clear previous
    for doc in db.collection(_SUGGESTIONS_COL).stream():
        doc.reference.delete()
    for doc in db.collection(_VOTES_COL).stream():
        doc.reference.delete()

    ref = db.collection(_SUGGESTIONS_COL).document()
    ref.set({
        "name": "Test Suggestion",
        "normalized_name": "test suggestion",
        "description": "desc",
        "category": "mess",
        "suggested_price": 50,
        "suggested_by": suggested_by,
        "status": "pending",
        "vote_count": 0,
        "popularity_score": 0.0,
        "request_count": 1,
    })
    return ref.id


def test_concurrent_duplicate_votes():
    """
    Simulates 10 concurrent requests from the same user voting for the same suggestion.
    Only exactly 1 should return 200. The rest should return 409.
    The final vote_count on the suggestion must be exactly 1.
    There must be exactly 1 vote document.
    """
    suggestion_id = _setup_suggestion(suggested_by="creator_user")
    voter_uid = "voter_user"

    import concurrent.futures

    def _vote():
        with patch("auth.dependencies.verify_firebase_token", return_value=_make_mock_token(voter_uid)):
            response = client.post(
                f"/foodpulse/vote/{suggestion_id}",
                headers={"Authorization": "Bearer fake_token"}
            )
            return response

    with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
        futures = [executor.submit(_vote) for _ in range(10)]
        results = [f.result() for f in concurrent.futures.as_completed(futures)]

    status_codes = [r.status_code for r in results]
    
    assert status_codes.count(200) == 1, f"Expected exactly 1 success, got {status_codes.count(200)}. Statuses: {status_codes}"
    assert status_codes.count(409) == 9, f"Expected 9 conflicts, got {status_codes.count(409)}"

    suggestion_snap = db.collection(_SUGGESTIONS_COL).document(suggestion_id).get()
    assert suggestion_snap.exists
    assert suggestion_snap.to_dict()["vote_count"] == 1

    votes = list(db.collection(_VOTES_COL).where("suggestion_id", "==", suggestion_id).stream())
    assert len(votes) == 1
    assert votes[0].to_dict()["user_id"] == voter_uid


def test_sequential_duplicate_votes():
    """
    Tests that a second sequential vote by the same user returns 409 and doesnt increment count.
    """
    suggestion_id = _setup_suggestion(suggested_by="creator_user")
    voter_uid = "sequential_voter"

    with patch("auth.dependencies.verify_firebase_token", return_value=_make_mock_token(voter_uid)):
        r1 = client.post(f"/foodpulse/vote/{suggestion_id}", headers={"Authorization": "Bearer fake"})
        assert r1.status_code == 200

        r2 = client.post(f"/foodpulse/vote/{suggestion_id}", headers={"Authorization": "Bearer fake"})
        assert r2.status_code == 409
        assert "already voted" in r2.json()["detail"].lower()

    suggestion_snap = db.collection(_SUGGESTIONS_COL).document(suggestion_id).get()
    assert suggestion_snap.to_dict()["vote_count"] == 1

    suggestion_b_id = _setup_suggestion(suggested_by="creator_user")
    with patch("auth.dependencies.verify_firebase_token", return_value=_make_mock_token(voter_uid)):
        r3 = client.post(f"/foodpulse/vote/{suggestion_b_id}", headers={"Authorization": "Bearer fake"})
        assert r3.status_code == 200
        
    suggestion_b_snap = db.collection(_SUGGESTIONS_COL).document(suggestion_b_id).get()
    assert suggestion_b_snap.to_dict()["vote_count"] == 1

