"""Subscription limits for gear (cameras / mounted lenses)."""

from typing import Optional
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from ..db.models.camera import UserCamera, UserLens
from ..db.models.user import User

FREE_MAX_CAMERAS = 3
FREE_MAX_LENSES_PER_CAMERA = 1


def tier_is_pro(subscription_tier: Optional[str]) -> bool:
    return (subscription_tier or "free").lower() == "pro"


def count_user_cameras(db: Session, user_id: str) -> int:
    return db.query(UserCamera).filter(UserCamera.user_id == user_id).count()


def count_lenses_on_camera(db: Session, parent_camera_id: UUID, *, exclude_lens_id: Optional[UUID] = None) -> int:
    q = db.query(UserLens).filter(UserLens.parent_camera_id == parent_camera_id)
    if exclude_lens_id is not None:
        q = q.filter(UserLens.id != exclude_lens_id)
    return q.count()


def assert_can_create_camera(db: Session, user: User) -> None:
    if tier_is_pro(user.subscription_tier):
        return
    if count_user_cameras(db, user.id) >= FREE_MAX_CAMERAS:
        raise HTTPException(
            status_code=status.HTTP_402_PAYMENT_REQUIRED,
            detail=f"Free tier is limited to {FREE_MAX_CAMERAS} cameras. Upgrade to Halide Pro for unlimited gear.",
        )


def assert_can_create_standalone_lens(user: User) -> None:
    """Free users must mount lenses from a camera (one lens per body)."""
    if tier_is_pro(user.subscription_tier):
        return
    raise HTTPException(
        status_code=status.HTTP_402_PAYMENT_REQUIRED,
        detail="Free tier adds lenses from a camera's Mount screen (one lens per body). Upgrade to Halide Pro for unlimited gear.",
    )


def assert_can_attach_lens(
    db: Session,
    user: User,
    parent_camera_id: UUID,
    *,
    exclude_lens_id: Optional[UUID] = None,
) -> None:
    if tier_is_pro(user.subscription_tier):
        return
    camera = (
        db.query(UserCamera)
        .filter(UserCamera.id == parent_camera_id, UserCamera.user_id == user.id)
        .first()
    )
    if not camera:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User camera not found")
    mounted = count_lenses_on_camera(db, parent_camera_id, exclude_lens_id=exclude_lens_id)
    if mounted >= FREE_MAX_LENSES_PER_CAMERA:
        raise HTTPException(
            status_code=status.HTTP_402_PAYMENT_REQUIRED,
            detail="Free tier is limited to one lens per camera. Upgrade to Halide Pro to mount more.",
        )
