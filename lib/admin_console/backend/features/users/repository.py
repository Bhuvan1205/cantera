from config.firebase import db
from .schemas import UserProfile, WalletSummary, WalletTransaction, UserDetail


class UserRepository:
    """
    All Firestore reads for the Users feature.
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
