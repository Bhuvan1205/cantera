# Coding Standards & Style Guide

This document establishes style, structure, and quality rules for both Python (Backend) and Dart/Flutter (Client).

---

## 1. Python (FastAPI Backend)

### Style & Formatting
- **Standard:** PEP 8 compliance with `black` formatting (line length 88 chars).
- **Type Annotations:** Mandatory type hints on all function arguments, return types, and class attributes.
- **Async Usage:** All FastAPI endpoint handlers and database calls must be `async def`.

### Structure
- Features are encapsulated in modular packages:
  `lib/admin_console/backend/features/<feature_name>/`
  - `schemas.py`: Pydantic request/response models.
  - `repository.py`: Firestore Admin SDK database access and transactional operations.
  - `service.py`: Business logic and orchestration.
  - `router.py`: FastAPI endpoints and dependency injection.

### Example
```python
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field

router = APIRouter(prefix="/api/example", tags=["Example"])

class ExampleRequest(BaseModel):
    item_id: str = Field(..., description="ID of the target item")
    quantity: int = Field(..., ge=1, le=50)

@router.post("/", status_code=status.HTTP_200_OK)
async def process_example(
    payload: ExampleRequest,
    current_user: dict = Depends(get_current_user),
) -> dict:
    return {"status": "success", "item_id": payload.item_id}
```

---

## 2. Dart & Flutter (Client)

### Style & Formatting
- **Linter:** `flutter_lints` enabled via `analysis_options.yaml`.
- **Formatting:** `dart format` (line length 80 chars).
- **Static Analysis:** Code must produce zero warnings with `flutter analyze`.

### Structure
- **Design System:** Use tokens defined in `lib/theme/app_colors.dart` and `lib/theme/app_theme.dart`. Avoid hardcoded hex colors.
- **State Management:** Use reactive `StreamBuilder` connected to Firestore snapshot streams for read-only dynamic feeds.
- **Network Access:** All backend calls MUST go through `ApiClient.instance`.

---

## Cross-References
- [Feature Development Guide](file:///docs/engineering/FEATURE_DEVELOPMENT_GUIDE.md)
- [Testing Standards](file:///docs/engineering/TESTING_STANDARDS.md)
