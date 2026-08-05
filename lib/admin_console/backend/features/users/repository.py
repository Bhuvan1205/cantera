from google.cloud import firestore
from config.firebase import db
from .schemas import UserProfile, WalletSummary, WalletTransaction, UserDetail, CreateUserProfileRequest, PickupPinInfo
from datetime import datetime, timezone


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
        """
        user_ref = db.collection(UserRepository._users_col).document(uid)
        user_snap = user_ref.get()

        data_to_set = {
            "uid": uid,
            "name": payload.name.strip(),
            "email": payload.email.strip().lower(),
            "updatedAt": firestore.SERVER_TIMESTAMP,
        }
        if payload.phone:
            data_to_set["phone"] = payload.phone.strip()

        if not user_snap.exists:
            data_to_set["createdAt"] = firestore.SERVER_TIMESTAMP
            data_to_set["isAdmin"] = False
            data_to_set["role"] = "customer"
            if payload.pickup_pin:
                data_to_set["pickupPin"] = payload.pickup_pin.strip()
                data_to_set["lastPinChange"] = firestore.SERVER_TIMESTAMP
            user_ref.set(data_to_set)
        else:
            if payload.pickup_pin and not user_snap.to_dict().get("pickupPin"):
                data_to_set["pickupPin"] = payload.pickup_pin.strip()
                data_to_set["lastPinChange"] = firestore.SERVER_TIMESTAMP
            user_ref.set(data_to_set, merge=True)

        # Ensure wallet exists
        wallet_ref = db.collection(UserRepository._wallets_col).document(uid)
        if not wallet_ref.get().exists:
            wallet_ref.set({
                "balance": 0.0,
                "total_added": 0.0,
                "total_spent": 0.0,
                "created_at": firestore.SERVER_TIMESTAMP,
            })

        updated_snap = user_ref.get()
        return UserProfile.from_firestore(uid, updated_snap.to_dict() or {})

    @staticmethod
    def get_pickup_pin_info(uid: str) -> tuple[dict, PickupPinInfo]:
        """
        Returns the raw user doc dict and parsed PickupPinInfo.
        """
        user_ref = db.collection(UserRepository._users_col).document(uid)
        user_snap = user_ref.get()
        if not user_snap.exists:
            return {}, PickupPinInfo(has_pin=False, last_changed=None, can_change_in_days=0)

        data = user_snap.to_dict() or {}
        pin = data.get("pickupPin")
        last_changed_ts = data.get("lastPinChange")

        can_change_in_days = 0
        last_changed_iso = None
        if last_changed_ts:
            if hasattr(last_changed_ts, "to_datetime"):
                dt = last_changed_ts.to_datetime()
            elif isinstance(last_changed_ts, datetime):
                dt = last_changed_ts
            else:
                dt = datetime.now(timezone.utc)

            last_changed_iso = dt.isoformat()
            now = datetime.now(timezone.utc)
            if dt.tzinfo is None:
                dt = dt.replace(tzinfo=timezone.utc)
            days_passed = (now - dt).days
            if days_passed < 30:
                can_change_in_days = 30 - days_passed

        return data, PickupPinInfo(
            has_pin=bool(pin),
            last_changed=last_changed_iso,
            can_change_in_days=can_change_in_days,
        )

    @staticmethod
    def update_pickup_pin(uid: str, new_pin: str) -> None:
        """
        Updates pickup PIN and updates lastPinChange to server timestamp.
        """
        user_ref = db.collection(UserRepository._users_col).document(uid)
        user_ref.set({
            "pickupPin": new_pin,
            "lastPinChange": firestore.SERVER_TIMESTAMP,
            "updatedAt": firestore.SERVER_TIMESTAMP,
        }, merge=True)

