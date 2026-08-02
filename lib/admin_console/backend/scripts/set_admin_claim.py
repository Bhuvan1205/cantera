"""
Standalone Administrative CLI Utility for Firebase Custom Claims.

Usage examples:
    # Grant admin claim by email:
    python scripts/set_admin_claim.py --email admin@canteen.com --grant

    # Grant admin claim by UID:
    python scripts/set_admin_claim.py --uid abc123xyz --grant

    # Revoke admin claim:
    python scripts/set_admin_claim.py --email user@canteen.com --revoke

    # Check claims status:
    python scripts/set_admin_claim.py --email admin@canteen.com --status
"""

import sys
import os
import argparse

# Ensure backend root is on sys.path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from firebase_admin import auth
from config.firebase import db
from config.logging import log_audit


def resolve_uid(email: str | None, uid: str | None) -> str:
    """Resolves and returns the Firebase Auth UID."""
    if uid:
        return uid.strip()
    if email:
        user = auth.get_user_by_email(email.strip())
        return user.uid
    raise ValueError("Either --email or --uid must be provided.")


def get_user_status(uid: str) -> dict:
    """Retrieves current Auth custom claims and Firestore status."""
    user = auth.get_user(uid)
    custom_claims = user.custom_claims or {}

    user_snap = db.collection("Users").document(uid).get()
    firestore_data = user_snap.to_dict() if user_snap.exists else {}

    return {
        "uid": uid,
        "email": user.email,
        "display_name": user.display_name,
        "custom_claims": custom_claims,
        "is_admin_claim": bool(custom_claims.get("admin") or custom_claims.get("isAdmin")),
        "firestore_is_admin": bool(firestore_data.get("isAdmin", False)),
        "firestore_doc_exists": user_snap.exists,
    }


def grant_admin(uid: str) -> None:
    """Grants the admin custom claim and updates Firestore."""
    user = auth.get_user(uid)
    existing_claims = user.custom_claims or {}
    updated_claims = {**existing_claims, "admin": True}

    auth.set_custom_user_claims(uid, updated_claims)

    # Sync Firestore document if present
    user_ref = db.collection("Users").document(uid)
    if user_ref.get().exists:
        user_ref.update({"isAdmin": True})

    log_audit(
        action="ADMIN_CLAIM_GRANTED",
        actor_uid="CLI_OPERATOR",
        target=f"Users/{uid}",
        details={"email": user.email, "custom_claims": updated_claims},
    )
    print(f"[SUCCESS] Admin custom claim GRANTED for user {uid} ({user.email}).")
    print(f"  Custom Claims: {updated_claims}")
    print("  Note: If the user is currently logged in, they must refresh their token to apply claims.")


def revoke_admin(uid: str) -> None:
    """Revokes the admin custom claim and revokes active refresh tokens."""
    user = auth.get_user(uid)
    existing_claims = user.custom_claims or {}
    updated_claims = {k: v for k, v in existing_claims.items() if k not in ("admin", "isAdmin")}

    auth.set_custom_user_claims(uid, updated_claims)
    auth.revoke_refresh_tokens(uid)

    # Sync Firestore document if present
    user_ref = db.collection("Users").document(uid)
    if user_ref.get().exists:
        user_ref.update({"isAdmin": False})

    log_audit(
        action="ADMIN_CLAIM_REVOKED",
        actor_uid="CLI_OPERATOR",
        target=f"Users/{uid}",
        details={"email": user.email, "custom_claims": updated_claims},
    )
    print(f"[SUCCESS] Admin custom claim REVOKED for user {uid} ({user.email}).")
    print(f"  Custom Claims: {updated_claims}")
    print("  Active refresh tokens have been revoked.")


def main():
    parser = argparse.ArgumentParser(
        description="Administrative CLI tool for managing Firebase Custom Claims."
    )
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--email", help="Target user email address")
    group.add_argument("--uid", help="Target user Firebase Auth UID")

    action_group = parser.add_mutually_exclusive_group(required=True)
    action_group.add_argument("--grant", action="store_true", help="Grant admin custom claim")
    action_group.add_argument("--revoke", action="store_true", help="Revoke admin custom claim")
    action_group.add_argument("--status", action="store_true", help="Display current claims and status")

    args = parser.parse_args()

    try:
        uid = resolve_uid(args.email, args.uid)
        if args.status:
            status = get_user_status(uid)
            print("\n=== User Authorization Status ===")
            print(f"UID:                  {status['uid']}")
            print(f"Email:                {status['email']}")
            print(f"Display Name:         {status['display_name']}")
            print(f"Custom Claims:        {status['custom_claims']}")
            print(f"Admin Claim Active:   {status['is_admin_claim']}")
            print(f"Firestore Record:     {'Exists' if status['firestore_doc_exists'] else 'Missing'}")
            print(f"Firestore isAdmin:    {status['firestore_is_admin']}")
            print("=================================\n")
        elif args.grant:
            grant_admin(uid)
        elif args.revoke:
            revoke_admin(uid)
    except Exception as exc:
        print(f"[ERROR] {exc}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
