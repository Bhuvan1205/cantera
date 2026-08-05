from pydantic import BaseModel
from typing import Optional


class UserProfile(BaseModel):
    """
    Read-only view of a user document from the Users collection.
    Fields exactly mirror what the Flutter app writes on registration.
    """
    uid: str
    name: Optional[str] = None
    email: Optional[str] = None
    phone: Optional[str] = None
    is_admin: bool = False
    profile_photo: Optional[str] = None
    pickup_pin: Optional[str] = None

    @classmethod
    def from_firestore(cls, uid: str, data: dict) -> "UserProfile":
        return cls(
            uid=uid,
            name=data.get("name"),
            email=data.get("email"),
            phone=data.get("phone"),
            is_admin=data.get("isAdmin", False),
            profile_photo=data.get("profilePhoto"),
            pickup_pin=data.get("pickupPin"),
        )


class WalletSummary(BaseModel):
    """Wallet balance snapshot for a user."""
    balance: float = 0.0
    total_added: float = 0.0
    total_spent: float = 0.0


class WalletTransaction(BaseModel):
    """A single wallet transaction record."""
    transaction_id: str
    type: Optional[str] = None           # 'purchase' | 'deposit'
    amount: float = 0.0
    status: Optional[str] = None
    reference_type: Optional[str] = None # 'order' | 'pending_deposit'
    reference_id: Optional[str] = None
    balance_after: Optional[float] = None
    gateway: Optional[str] = None
    initiated_by: Optional[str] = None
    timestamp: Optional[str] = None      # ISO string (converted from Firestore Timestamp)

    @classmethod
    def from_firestore(cls, txn_id: str, data: dict) -> "WalletTransaction":
        ts = data.get("timestamp") or data.get("created_at")
        return cls(
            transaction_id=txn_id,
            type=data.get("type"),
            amount=float(data.get("amount", 0)),
            status=data.get("status"),
            reference_type=data.get("reference_type"),
            reference_id=data.get("reference_id"),
            balance_after=data.get("balance_after"),
            gateway=data.get("gateway"),
            initiated_by=data.get("initiated_by"),
            timestamp=str(ts) if ts else None,
        )


class UserDetail(BaseModel):
    """
    Full user detail: profile + wallet summary + transaction history.
    Returned by GET /api/users/{uid}.
    """
    profile: UserProfile
    wallet: Optional[WalletSummary] = None
    transactions: list[WalletTransaction] = []


class CreateUserProfileRequest(BaseModel):
    """Payload for initializing/updating a user profile from Flutter auth flow."""
    name: str
    email: str
    phone: Optional[str] = None
    pickup_pin: Optional[str] = None


class ChangePinRequest(BaseModel):
    """Payload for updating delivery pickup PIN."""
    new_pin: str


class PickupPinInfo(BaseModel):
    """Metadata regarding user's current pickup PIN and cooldown status."""
    has_pin: bool
    last_changed: Optional[str] = None
    can_change_in_days: int = 0

