from typing import Literal, Optional
from pydantic import BaseModel, Field


class GroupCartItem(BaseModel):
    menu_item_id: str = Field(..., min_length=1)
    quantity: int = Field(..., ge=1, le=50)


class CreateGroupRequest(BaseModel):
    items: list[GroupCartItem] = []
    user_name: Optional[str] = None


class JoinGroupRequest(BaseModel):
    group_code: str = Field(..., min_length=6, max_length=6)
    items: list[GroupCartItem] = []
    user_name: Optional[str] = None


class GroupIdRequest(BaseModel):
    group_id: str = Field(..., min_length=1)


class GroupItemRequest(GroupIdRequest):
    operation: Literal['add', 'set_quantity', 'remove']
    menu_item_id: str = Field(..., min_length=1)
    quantity: Optional[int] = Field(None, ge=1, le=50)


class GroupCheckoutRequest(GroupIdRequest):
    user_name: Optional[str] = None
    payment_method: str = 'wallet'


class GroupOrderResponse(BaseModel):
    group_id: str
    group_code: str
    initiator_uid: str
    status: str
    members: list[dict]
    member_uids: list[str]
    items: list[dict]
    expires_at: Optional[str] = None
    order_id: Optional[str] = None
    paid_at: Optional[str] = None

    @classmethod
    def from_firestore(cls, data: dict) -> 'GroupOrderResponse':
        return cls(
            group_id=data.get('groupId', ''), group_code=data.get('groupCode', ''),
            initiator_uid=data.get('initiatorUid', ''), status=data.get('status', 'OPEN'),
            members=data.get('members', []), member_uids=data.get('memberUids', []),
            items=data.get('items', []), expires_at=str(data['expiresAt']) if data.get('expiresAt') else None,
            order_id=data.get('orderId'), paid_at=str(data['paidAt']) if data.get('paidAt') else None,
        )
