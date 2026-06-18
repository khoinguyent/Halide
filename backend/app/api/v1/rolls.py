from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List, Optional
from pydantic import BaseModel
from ...db.session import get_db
from ...db.schemas.roll import RollCreate, RollOut, RollOutDashboard, RollStatusUpdate, RollMetaUpdate, RollDriveUrlUpdate
from ...db.schemas.image import ImageOut
from ...db.models.user import User
from uuid import UUID
from ...core.dependencies import get_current_user
from ...services import roll_service
from ...services.export_service import export_roll_as_zip
from ...services.email_service import send_export_zip_ready
from ...services.storage_service import storage_service

router = APIRouter()

@router.get("/rolls", response_model=List[RollOutDashboard])
def read_rolls(
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    return roll_service.get_rolls_for_dashboard(db, user_id=current_user.id, skip=skip, limit=limit)


@router.get("/rolls/{roll_id}", response_model=RollOutDashboard)
def read_roll(
    roll_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    out = roll_service.get_roll_for_dashboard_by_id(db, roll_id=str(roll_id), user_id=current_user.id)
    if not out:
        raise HTTPException(status_code=404, detail="Roll not found")
    return out

@router.post("/rolls", response_model=RollOut)
def create_roll(
    roll: RollCreate, 
    db: Session = Depends(get_db), 
    current_user: User = Depends(get_current_user)
):
    return roll_service.create_roll(db=db, roll=roll, user_id=current_user.id)

@router.patch("/rolls/{id}/status", response_model=RollOut)
def update_roll_status(
    id: UUID,
    status_update: RollStatusUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    return roll_service.update_roll_status(db, roll_id=id, new_status=status_update.status, user_id=current_user.id)


@router.post("/rolls/{roll_id}/gyro-scan/pause", response_model=RollOut)
def pause_gyro_scan_session(
    roll_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Revert a prematurely scanned roll back to lab while scanning is still in progress."""
    return roll_service.pause_gyro_scan_session(db, roll_id=str(roll_id), user_id=current_user.id)


@router.patch("/rolls/{id}/meta", response_model=RollOutDashboard)
def update_roll_meta(
    id: UUID,
    meta_update: RollMetaUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return roll_service.update_roll_meta(db=db, roll_id=str(id), meta=meta_update, user_id=current_user.id)


@router.patch("/rolls/{id}/drive-url", response_model=RollOutDashboard)
def update_roll_drive_url(
    id: UUID,
    drive_url_update: RollDriveUrlUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return roll_service.update_roll_drive_url(
        db=db,
        roll_id=str(id),
        drive_url_update=drive_url_update,
        user_id=current_user.id,
    )


class LocalImagesRequest(BaseModel):
    local_paths: List[str]


@router.post("/rolls/{id}/local-images", response_model=List[ImageOut])
def add_local_images(
    id: UUID,
    request: LocalImagesRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return roll_service.add_local_images(
        db=db,
        roll_id=str(id),
        local_paths=request.local_paths,
        user_id=current_user.id
    )


class ShotCreate(BaseModel):
    aperture: float
    shutter_speed: str
    lat: Optional[float] = None
    lng: Optional[float] = None
    notes: Optional[str] = None
    # Device time when the user logged the shot (ISO 8601). If omitted, server time is used.
    logged_at: Optional[datetime] = None


@router.post("/rolls/{id}/shots", response_model=ImageOut)
def log_shot(
    id: UUID,
    shot: ShotCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return roll_service.log_shot(
        db=db,
        roll_id=str(id),
        aperture=shot.aperture,
        shutter_speed=shot.shutter_speed,
        lat=shot.lat,
        lng=shot.lng,
        notes=shot.notes,
        logged_at=shot.logged_at,
        user_id=current_user.id
    )


class RollExportOut(BaseModel):
    download_url: str
    expires_in_seconds: int


@router.post("/rolls/{roll_id}/export-zip", response_model=RollExportOut)
def export_roll_zip(
    roll_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Create a ZIP export for one roll and email the download link to the user.
    The link is time-limited (default 7 days).
    """
    zip_key = export_roll_as_zip(db, roll_id=str(roll_id), user=current_user)

    expires = 60 * 60 * 24 * 7  # 7 days
    url = storage_service.presigned_get_object_url(zip_key, expires_in=expires)
    if not url:
        raise HTTPException(status_code=503, detail="Failed to generate download URL")

    # Best-effort email: endpoint still returns URL even if email fails.
    if current_user.email:
        roll = roll_service.get_roll(db, str(roll_id), current_user.id)
        title = getattr(roll, "title", None) or "Your roll"
        send_export_zip_ready(
            to=current_user.email,
            display_name=current_user.display_name or "there",
            roll_title=title,
            download_url=url,
        )

    return RollExportOut(download_url=url, expires_in_seconds=expires)

