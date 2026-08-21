from google.cloud import firestore
from config.firebase import db
from .schemas import UserProfile, WalletSummary, WalletTransaction, UserDetail, CreateUserProfileRequest, RegisterFcmTokenRequest
from datetime import datetime, timezone
import hashlib


class UserRepository:
    """
    All Firestore reads and writes for the Users feature.
    Talks directly to the Firebase Admin SDK — bypasses Firestore Security Rules.
    """

    _users_col = "Users"
    _wallets_col = "wallets"
    _txns_col = "wallet_transactions"

    @staticmethod
    def get_all_users() -> list[UserProfile]:
        """
        Fetches every document in the Users collection.
        Returns a list of UserProfile objects sorted by name.
        """
        docs = db.collection(UserRepository._users_col).stream()
        users = [
            UserProfile.from_firestore(doc.id, doc.to_dict() or {})
            for doc in docs
        ]
        # Sort alphabetically by name; nameless users go to the end
        users.sort(key=lambda u: (u.name or "").lower())
        return users

    @staticmethod
    def get_user_by_uid(uid: str) -> UserDetail | None:
        """
        Fetches a single user's profile, wallet balance, and full
        transaction history from Firestore.

        Returns None if the user document does not exist.
        """
        # ── Profile ───────────────────────────────────────────────────────────
        user_snap = db.collection(UserRepository._users_col).document(uid).get()
        if not user_snap.exists:
            return None

        profile = UserProfile.from_firestore(uid, user_snap.to_dict() or {})

        # ── Wallet balance ────────────────────────────────────────────────────
        wallet_snap = db.collection(UserRepository._wallets_col).document(uid).get()
        wallet: WalletSummary | None = None
        if wallet_snap.exists:
            w = wallet_snap.to_dict() or {}
            wallet = WalletSummary(
                balance=float(w.get("balance", 0)),
                total_added=float(w.get("total_added", 0)),
                total_spent=float(w.get("total_spent", 0)),
            )

        # ── Transaction history ───────────────────────────────────────────────
        txn_docs = (
            db.collection(UserRepository._txns_col)
            .where("user_uid", "==", uid)
            .stream()
        )
        transactions = [
            WalletTransaction.from_firestore(doc.id, doc.to_dict() or {})
            for doc in txn_docs
        ]
        # Sort in memory to avoid requiring a Firestore composite index
        transactions.sort(key=lambda t: str(t.timestamp or ""), reverse=True)

        return UserDetail(profile=profile, wallet=wallet, transactions=transactions)

    @staticmethod
    def upsert_user_profile(uid: str, payload: CreateUserProfileRequest) -> UserProfile:
        """
        Initializes or updates user profile in Users/{uid} and creates initial 0-balance wallet.

        On CREATION (new document), writes the full required schema:
          - uid, name, email, isAdmin (False), pickupPin, createdAt, updatedAt, role

        On UPDATE (existing document), only merges mutable fields:
          - name, email, pickupPin (if changing), updatedAt
          - isAdmin is NEVER overwritten here — only admins can elevate privileges.

        Uses a WriteBatch to commit user and wallet writes in a single RPC.
        """
        user_ref = db.collection(UserRepository._users_col).document(uid)
        wallet_ref = db.collection(UserRepository._wallets_col).document(uid)

        # Read both docs in a single batched read
        user_snap, wallet_snap = db.get_all([user_ref, wallet_ref])

        batch = db.batch()

        if not user_snap.exists:
            # ── NEW USER: Write the full required document schema ──────────────
            # All 6 required fields are guaranteed to be present on creation.
            new_doc = {
                "uid": uid,
                "name": payload.name.strip(),
                "email": payload.email.strip().lower(),
                "isAdmin": False,
                "pickupPin": payload.pickup_pin.strip() if payload.pickup_pin else "",
                "createdAt": firestore.SERVER_TIMESTAMP,
                "updatedAt": firestore.SERVER_TIMESTAMP,
                "role": "customer",
            }
            if payload.pickup_pin:
                new_doc["lastPinChange"] = firestore.SERVER_TIMESTAMP
            if payload.phone:
                new_doc["phone"] = payload.phone.strip()
            batch.set(user_ref, new_doc)
            committed_data = new_doc
        else:
            # ── EXISTING USER: Merge only mutable profile fields ───────────────
            # isAdmin is intentionally excluded — privilege escalation is admin-only.
            existing = user_snap.to_dict() or {}
            update_data: dict = {
                "uid": uid,
                "name": payload.name.strip(),
                "email": payload.email.strip().lower(),
                "updatedAt": firestore.SERVER_TIMESTAMP,
            }
            if payload.phone:
                update_data["phone"] = payload.phone.strip()
            # Only update pickupPin if a new PIN is supplied and none exists yet
            if payload.pickup_pin and not existing.get("pickupPin"):
                update_data["pickupPin"] = payload.pickup_pin.strip()
                update_data["lastPinChange"] = firestore.SERVER_TIMESTAMP
            batch.set(user_ref, update_data, merge=True)
            # Merge existing + updates for the return value
            committed_data = {**existing, **update_data}

        # ── WALLET: Create initial 0-balance wallet if it doesn't exist ────────
        if not wallet_snap.exists:
            batch.set(wallet_ref, {
                "balance": 0.0,
                "total_added": 0.0,
                "total_spent": 0.0,
                "created_at": firestore.SERVER_TIMESTAMP,
            })

        batch.commit()

        return UserProfile.from_firestore(uid, committed_data)




    @staticmethod
    def upsert_fcm_token(uid: str, token: str) -> None:
        """
        Registers or refreshes an FCM push notification token for the given user.

        Storage path: Users/{uid}/fcm_tokens/{sha256(token)}

        The document ID is derived from a sha256 hash of the token, making the
        operation deterministic and idempotent. Registering the same token twice
        (e.g., on app restart or token refresh) always sets the same document.

        Security:
          - uid is always derived from the verified Firebase ID token on the
            server side. It is never accepted from the client.
          - Writing to another user's fcm_tokens subcollection is impossible
            because the authenticated uid is injected by the dependency.
          - Firestore security rules block direct client writes entirely
            (ADR-001). This method uses the Admin SDK which bypasses rules.
        """
        token_hash = hashlib.sha256(token.encode("utf-8")).hexdigest()
        token_ref = (
            db.collection(UserRepository._users_col)
            .document(uid)
            .collection("fcm_tokens")
            .document(token_hash)
        )
        token_ref.set({
            "token": token,
            "updated_at": firestore.SERVER_TIMESTAMP,
        })

    @staticmethod
    def delete_fcm_token(uid: str, token: str) -> None:
        """
        Deterministically removes a specific FCM token for the given user.
        """
        token_hash = hashlib.sha256(token.encode("utf-8")).hexdigest()
        token_ref = (
            db.collection(UserRepository._users_col)
            .document(uid)
            .collection("fcm_tokens")
            .document(token_hash)
        )
        token_ref.delete()

    @staticmethod
    def update_pickup_pin(uid: str, new_pin: str) -> None:
        """
        Updates the user's pickup PIN and sets the last pin change timestamp.
        """
        user_ref = db.collection(UserRepository._users_col).document(uid)
        user_ref.update({
            "pickupPin": new_pin,
            "lastPinChange": firestore.SERVER_TIMESTAMP
        })
