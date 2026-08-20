"""
Authorization dependency tests — Phase 1 security fix verification.

Tests A-F cover every branch of get_current_admin(), including the
critical regression test (Test C) that directly prevents the
privilege-escalation vulnerability where a missing Firestore record
previously granted full admin access.
"""
import pytest
from unittest.mock import patch, MagicMock
from fastapi import HTTPException

from auth.dependencies import get_current_admin, get_current_sensitive_admin, get_current_staff_or_admin


# ── Shared mock token claims ───────────────────────────────────────────────────

ADMIN_CLAIMS = {
    "uid": "admin_user_001",
    "sub": "admin_user_001",
    "email": "admin@mvsrec.edu.in",
}

NORMAL_USER_CLAIMS = {
    "uid": "normal_user_002",
    "sub": "normal_user_002",
    "email": "user@mvsrec.edu.in",
}

ADMIN_FIRESTORE_DOC = {
    "uid": "admin_user_001",
    "name": "Admin User",
    "email": "admin@mvsrec.edu.in",
    "isAdmin": True,
    "role": "admin",
}

NORMAL_FIRESTORE_DOC = {
    "uid": "normal_user_002",
    "name": "Normal User",
    "email": "user@mvsrec.edu.in",
    "isAdmin": False,
    "role": "customer",
}


def _make_snap(exists: bool, data: dict | None = None):
    """Creates a mock Firestore DocumentSnapshot."""
    snap = MagicMock()
    snap.exists = exists
    snap.to_dict.return_value = data or {}
    return snap


def _make_bearer(token: str = "mock.token.value"):
    """Creates a mock HTTPAuthorizationCredentials object."""
    creds = MagicMock()
    creds.credentials = token
    return creds


# ── Test A — Valid admin token + existing admin Firestore record ───────────────

def test_A_valid_admin_with_existing_firestore_record_is_authorized():
    """Test A: Valid Firebase token + existing admin Firestore record -> authorized."""
    with patch("auth.dependencies.verify_firebase_token", return_value=ADMIN_CLAIMS), \
         patch("auth.dependencies.db") as mock_db:

        mock_snap = _make_snap(exists=True, data=ADMIN_FIRESTORE_DOC)
        mock_db.collection.return_value.document.return_value.get.return_value = mock_snap

        result = get_current_admin(_make_bearer())

        assert result["uid"] == "admin_user_001"
        assert result["user_data"]["isAdmin"] is True


# ── Test B — Valid token + existing normal (non-admin) user record -> 403 ──────

def test_B_valid_token_non_admin_user_is_denied():
    """Test B: Valid Firebase token + existing Firestore record with isAdmin=False -> HTTP 403."""
    with patch("auth.dependencies.verify_firebase_token", return_value=NORMAL_USER_CLAIMS), \
         patch("auth.dependencies.db") as mock_db:

        mock_snap = _make_snap(exists=True, data=NORMAL_FIRESTORE_DOC)
        mock_db.collection.return_value.document.return_value.get.return_value = mock_snap

        with pytest.raises(HTTPException) as exc_info:
            get_current_admin(_make_bearer())

        assert exc_info.value.status_code == 403
        assert "Administrator privileges required" in exc_info.value.detail


# ── Test C — CRITICAL: Valid token + NO Firestore record -> 403 ───────────────

def test_C_valid_token_missing_firestore_record_is_denied():
    """
    Test C (CRITICAL): Valid Firebase token + missing Users/{uid} document -> HTTP 403.

    This directly tests the vulnerability where a missing Firestore document
    previously caused get_current_admin() to GRANT admin access.

    After the fix, a missing user document must never result in admin access.
    """
    with patch("auth.dependencies.verify_firebase_token", return_value=ADMIN_CLAIMS), \
         patch("auth.dependencies.db") as mock_db:

        # Firestore document does NOT exist
        mock_snap = _make_snap(exists=False)
        mock_db.collection.return_value.document.return_value.get.return_value = mock_snap

        with pytest.raises(HTTPException) as exc_info:
            get_current_admin(_make_bearer())

        # Must be 403, never 200 or any success response
        assert exc_info.value.status_code == 403
        assert "not found" in exc_info.value.detail.lower()


def test_C_missing_firestore_record_also_fails_for_claimed_admin():
    """
    Test C (extended): Even if token claims admin=True, a missing Firestore doc -> 403.
    Custom claims alone are not sufficient -- the Firestore record must exist.
    """
    claims_with_admin_flag = {**ADMIN_CLAIMS, "admin": True}

    with patch("auth.dependencies.verify_firebase_token", return_value=claims_with_admin_flag), \
         patch("auth.dependencies.db") as mock_db:

        mock_snap = _make_snap(exists=False)
        mock_db.collection.return_value.document.return_value.get.return_value = mock_snap

        with pytest.raises(HTTPException) as exc_info:
            get_current_admin(_make_bearer())

        assert exc_info.value.status_code == 403


# ── Test D — Firestore unavailable (db is None) -> 503 ────────────────────────

def test_D_firestore_unavailable_returns_503():
    """
    Test D (CRITICAL): db is None (Firestore unavailable) -> HTTP 503, never admin access.

    After the fix, an unavailable Firestore client must return 503, not grant admin.
    """
    with patch("auth.dependencies.verify_firebase_token", return_value=ADMIN_CLAIMS), \
         patch("auth.dependencies.db", None):

        with pytest.raises(HTTPException) as exc_info:
            get_current_admin(_make_bearer())

        assert exc_info.value.status_code == 503
        assert "unavailable" in exc_info.value.detail.lower()


# ── Test E — Invalid Firebase token -> 401 ────────────────────────────────────

def test_E_invalid_firebase_token_returns_401():
    """Test E: Invalid / malformed Firebase token -> HTTP 401."""
    with patch("auth.dependencies.verify_firebase_token",
               side_effect=HTTPException(status_code=401, detail="Invalid authentication token.")):
        with pytest.raises(HTTPException) as exc_info:
            get_current_admin(_make_bearer("invalid.jwt.token"))

        assert exc_info.value.status_code == 401


# ── Test F — Expired Firebase token -> 401 ────────────────────────────────────

def test_F_expired_firebase_token_returns_401():
    """Test F: Expired Firebase token -> HTTP 401."""
    with patch("auth.dependencies.verify_firebase_token",
               side_effect=HTTPException(status_code=401, detail="Token has expired. Please sign in again.")):
        with pytest.raises(HTTPException) as exc_info:
            get_current_admin(_make_bearer("expired.jwt.token"))

        assert exc_info.value.status_code == 401
        assert "expired" in exc_info.value.detail.lower()


# ── get_current_sensitive_admin tests ─────────────────────────────────────────

def test_sensitive_admin_missing_doc_returns_403():
    """get_current_sensitive_admin: missing Firestore document -> 403."""
    with patch("auth.dependencies.verify_sensitive_firebase_token", return_value=ADMIN_CLAIMS), \
         patch("auth.dependencies.db") as mock_db:

        mock_snap = _make_snap(exists=False)
        mock_db.collection.return_value.document.return_value.get.return_value = mock_snap

        with pytest.raises(HTTPException) as exc_info:
            get_current_sensitive_admin(_make_bearer())

        assert exc_info.value.status_code == 403


def test_sensitive_admin_db_none_returns_503():
    """get_current_sensitive_admin: db is None -> 503."""
    with patch("auth.dependencies.verify_sensitive_firebase_token", return_value=ADMIN_CLAIMS), \
         patch("auth.dependencies.db", None):

        with pytest.raises(HTTPException) as exc_info:
            get_current_sensitive_admin(_make_bearer())

        assert exc_info.value.status_code == 503


def test_sensitive_admin_valid_admin_authorized():
    """get_current_sensitive_admin: valid admin record -> authorized."""
    with patch("auth.dependencies.verify_sensitive_firebase_token", return_value=ADMIN_CLAIMS), \
         patch("auth.dependencies.db") as mock_db:

        mock_snap = _make_snap(exists=True, data=ADMIN_FIRESTORE_DOC)
        mock_db.collection.return_value.document.return_value.get.return_value = mock_snap

        result = get_current_sensitive_admin(_make_bearer())
        assert result["uid"] == "admin_user_001"


# ── get_current_staff_or_admin tests ──────────────────────────────────────────

def test_staff_missing_doc_returns_403():
    """get_current_staff_or_admin: missing Firestore document -> 403."""
    with patch("auth.dependencies.verify_firebase_token", return_value=NORMAL_USER_CLAIMS), \
         patch("auth.dependencies.db") as mock_db:

        mock_snap = _make_snap(exists=False)
        mock_db.collection.return_value.document.return_value.get.return_value = mock_snap

        with pytest.raises(HTTPException) as exc_info:
            get_current_staff_or_admin(_make_bearer())

        assert exc_info.value.status_code == 403


def test_staff_db_none_returns_503():
    """get_current_staff_or_admin: db is None -> 503."""
    with patch("auth.dependencies.verify_firebase_token", return_value=NORMAL_USER_CLAIMS), \
         patch("auth.dependencies.db", None):

        with pytest.raises(HTTPException) as exc_info:
            get_current_staff_or_admin(_make_bearer())

        assert exc_info.value.status_code == 503


def test_staff_valid_staff_role_authorized():
    """get_current_staff_or_admin: valid staff record in Firestore -> authorized."""
    staff_doc = {**NORMAL_FIRESTORE_DOC, "role": "staff", "uid": "normal_user_002"}
    with patch("auth.dependencies.verify_firebase_token", return_value=NORMAL_USER_CLAIMS), \
         patch("auth.dependencies.db") as mock_db:

        mock_snap = _make_snap(exists=True, data=staff_doc)
        mock_db.collection.return_value.document.return_value.get.return_value = mock_snap

        result = get_current_staff_or_admin(_make_bearer())
        assert result["uid"] == "normal_user_002"


def test_staff_custom_claims_with_missing_firestore_doc_denied():
    """
    Even with staff custom claims, a missing Firestore document -> 403.
    Accounts deleted from Firestore must not retain access via stale tokens.
    """
    claims_with_staff = {**NORMAL_USER_CLAIMS, "staff": True, "role": "staff"}

    with patch("auth.dependencies.verify_firebase_token", return_value=claims_with_staff), \
         patch("auth.dependencies.db") as mock_db:

        mock_snap = _make_snap(exists=False)
        mock_db.collection.return_value.document.return_value.get.return_value = mock_snap

        with pytest.raises(HTTPException) as exc_info:
            get_current_staff_or_admin(_make_bearer())

        assert exc_info.value.status_code == 403


# ── Test G — Non-College Domain Rejection ─────────────────────────────────────

def test_G_non_college_domain_is_denied():
    """Test G: Valid token but non-college domain -> HTTP 403."""
    claims = {
        "uid": "outsider",
        "sub": "outsider",
        "email": "hacker@gmail.com",
    }
    with patch("auth.dependencies.verify_firebase_token", return_value=claims), \
         patch("auth.dependencies.db") as mock_db:

        # Even if a doc exists in Firestore, domain check should fail
        mock_snap = _make_snap(exists=True, data={"uid": "outsider", "email": "hacker@gmail.com", "isAdmin": False, "role": "customer"})
        mock_db.collection.return_value.document.return_value.get.return_value = mock_snap

        with pytest.raises(HTTPException) as exc_info:
            get_current_admin(_make_bearer())

        assert exc_info.value.status_code == 403
        assert "Only @mvsrec.edu.in accounts are permitted" in exc_info.value.detail
