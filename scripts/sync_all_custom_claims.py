"""
Migration Script: Sync All Custom Claims (P-08)
Reads all documents in the 'Users' collection and assigns appropriate
Firebase Auth custom claims (role, admin, staff).
"""

import os
import sys
import firebase_admin
from firebase_admin import auth, firestore

if not firebase_admin._apps:
    firebase_admin.initialize_app()

db = firestore.client()

def sync_claims():
    print("Starting custom claims synchronization for all users...")
    users_ref = db.collection("Users")
    users = list(users_ref.stream())
    print(f"Found {len(users)} user profiles.")

    count = 0
    for doc in users:
        data = doc.to_dict() or {}
        uid = doc.id
        is_admin = data.get("isAdmin") is True or data.get("role") == "admin"
        role = data.get("role") or ("admin" if is_admin else "customer")
        is_staff = role == "staff" or is_admin

        try:
            auth.set_custom_user_claims(uid, {
                "role": role,
                "admin": is_admin,
                "staff": is_staff,
            })
            count += 1
            print(f"[{count}/{len(users)}] Synced {uid}: role={role}, admin={is_admin}, staff={is_staff}")
        except Exception as err:
            print(f"Error syncing user {uid}: {err}")

    print(f"Successfully synced claims for {count} users.")

if __name__ == "__main__":
    sync_claims()
