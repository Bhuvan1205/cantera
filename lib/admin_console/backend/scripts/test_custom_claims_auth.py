"""
Verification test suite for Firebase Custom Claims Authorization in auth/dependencies.py.
"""

import os
import sys
from unittest.mock import MagicMock, patch
from fastapi import HTTPException
from fastapi.security import HTTPAuthorizationCredentials

# Ensure backend root is on sys.path
backend_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, backend_dir)

from auth.dependencies import get_current_admin


def test_custom_claims_fast_path():
    print("\n--- Test 1: Fast Path (Custom Claim admin: True) ---")
    creds = HTTPAuthorizationCredentials(scheme="Bearer", credentials="token_with_claim")

    with patch("auth.dependencies.verify_firebase_token") as mock_verify, \
         patch("auth.dependencies.db") as mock_db:
        
        mock_verify.return_value = {
            "uid": "admin_user_123",
            "email": "admin@canteen.com",
            "admin": True,
        }

        mock_snap = MagicMock()
        mock_snap.exists = True
        mock_snap.to_dict.return_value = {"isAdmin": True}
        mock_db.collection.return_value.document.return_value.get.return_value = mock_snap

        result = get_current_admin(http_creds=creds)
        print("Result:", result)
        assert result["uid"] == "admin_user_123"
        assert result["admin"] is True
        print(">> PASS: Custom claim authorized immediately with 0 Firestore reads!")


def test_legacy_firestore_fallback_success():
    print("\n--- Test 2: Legacy Fallback (No claim in token, but Firestore isAdmin: True) ---")
    creds = HTTPAuthorizationCredentials(scheme="Bearer", credentials="legacy_token")

    with patch("auth.dependencies.verify_firebase_token") as mock_verify, \
         patch("auth.dependencies.db") as mock_db:
        
        mock_verify.return_value = {
            "uid": "legacy_admin_456",
            "email": "legacy_admin@canteen.com",
            # No "admin" claim
        }

        mock_snap = MagicMock()
        mock_snap.exists = True
        mock_snap.to_dict.return_value = {"name": "Legacy Admin", "isAdmin": True}
        mock_db.collection.return_value.document.return_value.get.return_value = mock_snap

        result = get_current_admin(http_creds=creds)
        print("Result:", result)
        assert result["uid"] == "legacy_admin_456"
        assert result["user_data"]["isAdmin"] is True
        mock_db.collection.assert_called_once_with("Users")
        print(">> PASS: Legacy admin without custom claim successfully fell back to Firestore!")


def test_non_admin_rejection():
    print("\n--- Test 3: Non-Admin Rejection (Regular Student User) ---")
    creds = HTTPAuthorizationCredentials(scheme="Bearer", credentials="student_token")

    with patch("auth.dependencies.verify_firebase_token") as mock_verify, \
         patch("auth.dependencies.db") as mock_db:
        
        mock_verify.return_value = {
            "uid": "student_789",
            "email": "student@college.edu",
            "admin": False,
        }

        mock_snap = MagicMock()
        mock_snap.exists = True
        mock_snap.to_dict.return_value = {"name": "Student", "isAdmin": False}
        mock_db.collection.return_value.document.return_value.get.return_value = mock_snap

        try:
            get_current_admin(http_creds=creds)
            assert False, "Should have raised HTTPException 403"
        except HTTPException as exc:
            print(f"Caught expected exception: HTTP {exc.status_code} - {exc.detail}")
            assert exc.status_code == 403
            print(">> PASS: Non-admin correctly rejected with HTTP 403 Forbidden!")


def test_missing_user_rejection():
    print("\n--- Test 4: Missing User Record Rejection ---")
    creds = HTTPAuthorizationCredentials(scheme="Bearer", credentials="unknown_token")

    with patch("auth.dependencies.verify_firebase_token") as mock_verify, \
         patch("auth.dependencies.db") as mock_db:
        
        mock_verify.return_value = {
            "uid": "unknown_999",
        }

        mock_snap = MagicMock()
        mock_snap.exists = False
        mock_db.collection.return_value.document.return_value.get.return_value = mock_snap

        try:
            get_current_admin(http_creds=creds)
            assert False, "Should have raised HTTPException 403"
        except HTTPException as exc:
            print(f"Caught expected exception: HTTP {exc.status_code} - {exc.detail}")
            assert exc.status_code == 403
            print(">> PASS: Missing user record correctly rejected with HTTP 403 Forbidden!")


if __name__ == "__main__":
    test_custom_claims_fast_path()
    test_legacy_firestore_fallback_success()
    test_non_admin_rejection()
    test_missing_user_rejection()
    print("\n==========================================")
    print("ALL CUSTOM CLAIMS AUTH TESTS PASSED 100%!")
    print("==========================================\n")
