from config.firebase import db
from .schemas import MenuItem, CreateMenuItemRequest, UpdateMenuItemRequest

_MENU_COL = "Menu"


class InventoryRepository:
    """
    All Firestore reads and writes for the Menu/Inventory feature.
    """

    @staticmethod
    def get_all_items() -> list[MenuItem]:
        """Streams every document from the Menu collection, sorted by category then name."""
        docs = db.collection(_MENU_COL).stream()
        items = [
            MenuItem.from_firestore(doc.id, doc.to_dict() or {})
            for doc in docs
        ]
        items.sort(key=lambda m: (m.category, m.name.lower()))
        return items

    @staticmethod
    def get_item_by_id(menu_id: str) -> MenuItem | None:
        """Returns a single MenuItem or None if not found."""
        snap = db.collection(_MENU_COL).document(menu_id).get()
        if not snap.exists:
            return None
        return MenuItem.from_firestore(snap.id, snap.to_dict() or {})

    @staticmethod
    def create_item(payload: CreateMenuItemRequest) -> MenuItem:
        """
        Adds a new document to the Menu collection with a Firestore auto-generated ID.
        Returns the created MenuItem with its new ID.
        """
        doc_ref = db.collection(_MENU_COL).document()  # auto-ID

        data: dict = {
            "name": payload.name,
            "price": payload.price,
            "category": payload.category.lower(),
            "isAvailable": payload.is_available,
        }
        if payload.stock is not None:
            data["stock"] = payload.stock
        if payload.image_url:
            data["imageUrl"] = payload.image_url
        if payload.description:
            data["description"] = payload.description

        doc_ref.set(data)
        return MenuItem.from_firestore(doc_ref.id, data)

    @staticmethod
    def update_item(menu_id: str, payload: UpdateMenuItemRequest) -> MenuItem | None:
        """
        Partially updates a Menu document.
        Only fields explicitly provided in the payload are written.
        Returns the updated MenuItem, or None if the document doesn't exist.
        """
        doc_ref = db.collection(_MENU_COL).document(menu_id)

        # Build the update dict from only the fields that were provided
        updates: dict = {}
        if payload.price is not None:
            updates["price"] = payload.price
        if payload.stock is not None:
            updates["stock"] = payload.stock
        if payload.is_available is not None:
            updates["isAvailable"] = payload.is_available
        if payload.image_url is not None:
            updates["imageUrl"] = payload.image_url
        if payload.description is not None:
            updates["description"] = payload.description

        if not updates:
            # Nothing to update — just return the current state
            return InventoryRepository.get_item_by_id(menu_id)

        doc_ref.update(updates)

        # Fetch and return the updated document
        return InventoryRepository.get_item_by_id(menu_id)
