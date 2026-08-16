import pytest
from unittest.mock import patch, MagicMock
from fastapi import HTTPException
from firebase_admin import auth
from auth.verify import verify_firebase_token, verify_sensitive_firebase_token, should_check_revocation


def test_revocation_policy_environments():
    # Dev / Local / Staging -> check_revoked should always be False
    with patch.dict("os.environ", {"ENV": "dev", "FIRESTORE_EMULATOR_HOST": ""}):
        assert should_check_revocation(is_sensitive=False) is False
        assert should_check_revocation(is_sensitive=True) is False

    with patch.dict("os.environ", {"ENV": "staging", "FIRESTORE_EMULATOR_HOST": ""}):
        assert should_check_revocation(is_sensitive=False) is False
        assert should_check_revocation(is_sensitive=True) is False

    with patch.dict("os.environ", {"ENV": "emulator", "FIRESTORE_EMULATOR_HOST": "127.0.0.1:9090"}):
        assert should_check_revocation(is_sensitive=False) is False
        assert should_check_revocation(is_sensitive=True) is False

    # Production -> check_revoked should be True ONLY for sensitive operations
    with patch.dict("os.environ", {"ENV": "production", "FIRESTORE_EMULATOR_HOST": ""}):
        assert should_check_revocation(is_sensitive=False) is False
        assert should_check_revocation(is_sensitive=True) is True


def test_verify_firebase_token_success():
    mock_claims = {
        "uid": "user_abc_123",
        "sub": "user_abc_123",
        "email": "user@example.com",
        "aud": "canteen-app-e1c8d",
        "iss": "https://securetoken.google.com/canteen-app-e1c8d",
    }
    with patch("firebase_admin.auth.verify_id_token", return_value=mock_claims) as mock_verify:
        claims = verify_firebase_token("mock.header.payload")
        assert claims["uid"] == "user_abc_123"
        assert claims["email"] == "user@example.com"
        mock_verify.assert_called_once_with("mock.header.payload", check_revoked=False, clock_skew_seconds=10)


def test_verify_firebase_token_invalid_maps_to_401():
    with patch("firebase_admin.auth.verify_id_token", side_effect=auth.InvalidIdTokenError("Bad signature")):
        with pytest.raises(HTTPException) as exc_info:
            verify_firebase_token("invalid.jwt.token")
        assert exc_info.value.status_code == 401
        assert exc_info.value.detail == "Invalid authentication token."


def test_verify_firebase_token_expired_maps_to_401():
    with patch("firebase_admin.auth.verify_id_token", side_effect=auth.ExpiredIdTokenError("Expired", None)):
        with pytest.raises(HTTPException) as exc_info:
            verify_firebase_token("expired.jwt.token")
        assert exc_info.value.status_code == 401
        assert exc_info.value.detail == "Token has expired. Please sign in again."


def test_verify_firebase_token_revoked_maps_to_401():
    with patch("firebase_admin.auth.verify_id_token", side_effect=auth.RevokedIdTokenError("Revoked")):
        with pytest.raises(HTTPException) as exc_info:
            verify_firebase_token("revoked.jwt.token")
        assert exc_info.value.status_code == 401
        assert exc_info.value.detail == "Token has been revoked. Please sign in again."


def test_verify_sensitive_firebase_token_calls_sensitive():
    mock_claims = {"uid": "admin_789", "sub": "admin_789"}
    with patch.dict("os.environ", {"ENV": "production", "FIRESTORE_EMULATOR_HOST": ""}):
        with patch("firebase_admin.auth.verify_id_token", return_value=mock_claims) as mock_verify:
            claims = verify_sensitive_firebase_token("token.part1.part2")
            assert claims["uid"] == "admin_789"
            mock_verify.assert_called_once_with("token.part1.part2", check_revoked=True, clock_skew_seconds=10)
