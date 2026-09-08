from typing import Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from ...core.dependencies import get_current_user
from ...db.models.user import User
from ...db.schemas.analytics import ShootingMatrixResponse
from ...db.session import get_db
from ...services import analytics_service

router = APIRouter()


@router.get("/analytics/shooting-matrix", response_model=ShootingMatrixResponse)
def get_shooting_matrix(
    timezone: Optional[str] = Query(
        None,
        description="Device IANA timezone override (falls back to stored user timezone, then UTC)",
    ),
    sync_timezone: bool = Query(
        False,
        description="When true and timezone is provided, persist it on the user profile",
    ),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> ShootingMatrixResponse:
    return analytics_service.get_shooting_matrix(
        db,
        user=current_user,
        device_timezone=timezone,
        sync_timezone=sync_timezone,
    )
