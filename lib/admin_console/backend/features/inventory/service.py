from fastapi import HTTPException, status

from .repository import InventoryRepository
from .schemas import MenuItem, CreateMenuItemRequest, UpdateMenuItemRequest


class InventoryService:
    """Business logic for the Inventory / Menu feature."""

    @staticmethod
    def list_items() -> list[MenuItem]:
        """Returns all menu items sorted by category then name."""
        return InventoryRepository.get_all_items()

    @staticmethod
    def get_item(menu_id: str) -> MenuItem:
        """Returns a single menu item. Raises HTTP 404 if not found."""
        item = InventoryRepository.get_item_by_id(menu_id)
        if item is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Menu item '{menu_id}' not found.",
            )
        return item

    @staticmethod
    def create_item(payload: CreateMenuItemRequest) -> MenuItem:
        """Creates and returns a new menu item."""
        return InventoryRepository.create_item(payload)

    @staticmethod
    def update_item(menu_id: str, payload: UpdateMenuItemRequest) -> MenuItem:
        """
        Partially updates a menu item.
        Raises HTTP 404 if the item doesn't exist.
        Raises HTTP 400 if the update payload is completely empty.
        """
        # Verify the item exists first
        existing = InventoryRepository.get_item_by_id(menu_id)
        if existing is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Menu item '{menu_id}' not found.",
            )

        # Check that at least one field was actually provided
        provided = payload.model_dump(exclude_none=True)
        if not provided:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Update payload must contain at least one field.",
            )

        updated = InventoryRepository.update_item(menu_id, payload)
        return updated
