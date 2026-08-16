from fastapi import APIRouter, Depends, HTTPException, status

from auth.dependencies import get_current_user
from .service import RecommendationService
from .schemas import RecommendationResponse

router = APIRouter()


@router.get(
    "",
    response_model=RecommendationResponse,
    summary="Get personalised menu recommendations",
    description=(
        "Returns up to 5 recommended menu items for the authenticated user. "
        "Uses personal order history when the user has 7+ orders (personalized), "
        "otherwise falls back to global Canteen Buzz popularity data (discovery). "
        "Identity is derived exclusively from the verified Firebase ID token — "
        "no userId query parameter is accepted."
    ),
)
def get_recommendations(
    user: dict = Depends(get_current_user),
) -> RecommendationResponse:
    """
    GET /api/recommendations

    Authentication: Bearer <Firebase ID Token>
    Returns: RecommendationResponse with up to 5 items and a source label.
    """
    uid: str = user["uid"]

    try:
        return RecommendationService.get_recommendations(uid)
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to compute recommendations: {exc}",
        )
