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
        Uses a WriteBatch to commit user and wallet writes in a single RPC.
        """
        user_ref = db.collection(UserRepository._users_col).document(uid)
        wallet_ref = db.collection(UserRepository._wallets_col).document(uid)

        # Read both docs in a single batched read
        user_snap, wallet_snap = db.get_all([user_ref, wallet_ref])

        data_to_set = {
            "uid": uid,
            "name": payload.name.strip(),
            "email": payload.email.strip().lower(),
            "updatedAt": firestore.SERVER_TIMESTAMP,
        }
        if payload.phone:
            data_to_set["phone"] = payload.phone.strip()

        batch = db.batch()

        if not user_snap.exists:
            data_to_set["createdAt"] = firestore.SERVER_TIMESTAMP
            data_to_set["isAdmin"] = False
            data_to_set["role"] = "customer"
            batch.set(user_ref, data_to_set)
        else:
            batch.set(user_ref, data_to_set, merge=True)

        # Create wallet only if it doesn't already exist
        if not wallet_snap.exists:
            batch.set(wallet_ref, {
                "balance": 0.0,
                "total_added": 0.0,
                "total_spent": 0.0,
                "created_at": firestore.SERVER_TIMESTAMP,
            })

        batch.commit()

        # Construct return value from known committed state — no extra Firestore read needed
        known_data = {
            **(user_snap.to_dict() or {} if user_snap.exists else {}),
            **{k: v for k, v in data_to_set.items() if k != "updatedAt"},
            "uid": uid,
        }
        return UserProfile.from_firestore(uid, known_data)




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
