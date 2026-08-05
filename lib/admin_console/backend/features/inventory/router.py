from fastapi import APIRouter, Depends

from auth.dependencies import get_current_admin, get_current_staff_or_admin
from config.logging import log_audit
from .schemas import MenuItem, CreateMenuItemRequest, UpdateMenuItemRequest
from .service import InventoryService

router = APIRouter()


@router.get(
    "/",
    response_model=list[MenuItem],
    summary="List all menu items",
    description="Returns every item in the Menu collection, sorted by category then name, with current stock levels.",
)
def list_items(
    _user: dict = Depends(get_current_staff_or_admin),
) -> list[MenuItem]:
    return InventoryService.list_items()


@router.get(
    "/{menu_id}",
    response_model=MenuItem,
    summary="Get a single menu item",
)
def get_item(
    menu_id: str,
    _user: dict = Depends(get_current_staff_or_admin),
) -> MenuItem:
    return InventoryService.get_item(menu_id)


@router.post(
    "/",
    response_model=MenuItem,
    status_code=201,
    summary="Add a new menu item",
    description="Creates a new item in the Menu collection with a Firestore auto-generated ID.",
)
def create_item(
    payload: CreateMenuItemRequest,
    _admin: dict = Depends(get_current_admin),
) -> MenuItem:
    item = InventoryService.create_item(payload)
    log_audit(
        action="INVENTORY_ITEM_CREATE",
        actor_uid=_admin.get("uid", "unknown"),
        target=f"Menu/{item.id}",
        details={"name": item.name, "price": item.price, "stock": item.stock, "category": item.category},
    )
    return item


@router.patch(
    "/{menu_id}",
    response_model=MenuItem,
    summary="Update a menu item",
    description=(
        "Partially updates a menu item. Only fields included in the request body are changed. "
        "Use this to update price, stock level, availability, or image URL."
    ),
)
def update_item(
    menu_id: str,
    payload: UpdateMenuItemRequest,
    user: dict = Depends(get_current_staff_or_admin),
) -> MenuItem:
    item = InventoryService.update_item(menu_id, payload)
    log_audit(
        action="INVENTORY_ITEM_UPDATE",
        actor_uid=user.get("uid", "unknown"),
        target=f"Menu/{menu_id}",
        details={"updated_fields": payload.model_dump(exclude_unset=True), "new_stock": item.stock, "new_price": item.price},
    )
    return item

