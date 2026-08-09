from pydantic import BaseModel, Field
from typing import Optional


AVAILABILITY_ONLY_CATEGORIES = {"mess", "continental"}
AVAILABILITY_ONLY_SUBCATEGORIES = {"hot"}


def is_quantified_item(data: dict) -> bool:
    """
    Authoritative backend classification rule for inventory tracking.
    An item is availability-only (non-quantified) if:
      1. Explicit inventory_type == 'toggle' or is_quantifiable is False, or
      2. stock field is absent/None (as defined in schema: None means unlimited/non-trackable), or
      3. Category or subCategory is inherently availability-driven (mess, continental, hot beverages).
    Otherwise, the item is quantified and subject to numeric stock tracking.
    """
    if data.get("inventory_type") == "toggle" or data.get("is_quantifiable") is False:
        return False
    if data.get("inventory_type") == "quantified" or data.get("is_quantifiable") is True:
        return True
    category = str(data.get("category") or "").lower().strip()
    sub_category = str(data.get("subCategory") or data.get("sub_category") or "").lower().strip()
    if category in AVAILABILITY_ONLY_CATEGORIES or sub_category in AVAILABILITY_ONLY_SUBCATEGORIES:
        return False
    if data.get("stock") is None:
        return False
    return True


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
    sub_category: Optional[str] = None

    @property
    def is_quantified(self) -> bool:
        return is_quantified_item({
            "category": self.category,
            "subCategory": self.sub_category,
            "stock": self.stock,
        })

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
            sub_category=data.get("subCategory") or data.get("sub_category"),
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
