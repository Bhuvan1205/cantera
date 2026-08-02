from pydantic import BaseModel, Field
from typing import Optional


class MenuItem(BaseModel):
    """
    A single item from the Menu collection, as stored in Firestore.
    """
    menu_id: str
    name: str
    price: int                          # in rupees, always whole number
    category: str                       # 'mess' | 'bakery' | 'beverages' | 'continental'
    stock: Optional[int] = None         # None means unlimited / non-trackable
    is_available: bool = True
    image_url: Optional[str] = None
    description: Optional[str] = None

    @classmethod
    def from_firestore(cls, doc_id: str, data: dict) -> "MenuItem":
        return cls(
            menu_id=doc_id,
            name=data.get("name", ""),
            price=int(data.get("price", 0)),
            category=(data.get("category") or "general").lower(),
            stock=data.get("stock"),        # may be absent for mess/continental
            is_available=data.get("isAvailable", data.get("is_available", True)),
            image_url=data.get("imageUrl") or data.get("image_url"),
            description=data.get("description"),
        )


class CreateMenuItemRequest(BaseModel):
    """Payload for POST /api/inventory — add a new menu item."""
    name: str = Field(..., min_length=1, max_length=100)
    price: int = Field(..., gt=0, description="Price in rupees")
    category: str = Field(..., description="mess | bakery | beverages | continental")
    stock: Optional[int] = Field(None, ge=0, description="Omit for unlimited/non-trackable items")
    is_available: bool = True
    image_url: Optional[str] = None
    description: Optional[str] = None


class UpdateMenuItemRequest(BaseModel):
    """
    Payload for PATCH /api/inventory/{menu_id}.
    All fields are optional — only provided fields will be updated.
    """
    price: Optional[int] = Field(None, gt=0)
    stock: Optional[int] = Field(None, ge=0)
    is_available: Optional[bool] = None
    image_url: Optional[str] = None
    description: Optional[str] = None
