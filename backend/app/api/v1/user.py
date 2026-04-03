import logging
from fastapi import APIRouter, Depends, Form, File, UploadFile, HTTPException, status
from sqlalchemy.orm import Session
from typing import Optional

from ...db.session import get_db
from ...db.schemas.user import UserOut
from ...db.models.user import User
from ...core.dependencies import get_current_user
from ...services.storage_service import storage_service
from ...core.config import settings

logger = logging.getLogger(__name__)
router = APIRouter()

@router.patch("/profile", response_model=UserOut)
async def update_profile(
    name: Optional[str] = Form(None),
    professional_nickname: Optional[str] = Form(None),
    bio: Optional[str] = Form(None),
    avatar: Optional[UploadFile] = File(None),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Update the professional user profile.
    Accepts multipart/form-data for avatar image, name, professional_nickname, and bio.
    """
    if name is not None:
        current_user.display_name = name
    if professional_nickname is not None:
        current_user.professional_nickname = professional_nickname
    if bio is not None:
        current_user.bio = bio
        
    if avatar:
        if not avatar.content_type or not avatar.content_type.startswith("image/"):
            raise HTTPException(status_code=400, detail="File provided is not an image.")
        content = await avatar.read()
        result = storage_service.upload_avatar(
            user_id=current_user.id,
            file_content=content,
            content_type=avatar.content_type or "image/jpeg",
        )
        if result == "local":
            # Local storage mode: no cloud; app loads image from device. Store sentinel so app uses local file.
            current_user.avatar_url = "local"
            logger.info("avatar_url set to 'local' (no cloud); device stores file, DB stores sentinel")
        else:
            base_url = (settings.S3_ENDPOINT or "").rstrip("/")
            bucket = settings.S3_BUCKET_NAME or ""
            if "r2.cloudflarestorage.com" in base_url or "amazonaws.com" in base_url:
                avatar_url = f"{base_url}/{bucket}/users/{current_user.id}/profile/avatar.jpg"
            else:
                avatar_url = f"{base_url}/{bucket}/users/{current_user.id}/profile/avatar.jpg"
            current_user.avatar_url = avatar_url
            logger.info("avatar_url set to cloud URL: %s", avatar_url)

    db.commit()
    logger.debug("profile after update: avatar_url=%s", getattr(current_user, "avatar_url", None))
    db.refresh(current_user)
    
    return current_user


@router.patch("/onboarding-seen", response_model=UserOut)
def mark_onboarding_seen(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    current_user.has_seen_onboarding = True
    db.commit()
    db.refresh(current_user)
    return current_user


@router.patch("/roll-guide-seen", response_model=UserOut)
def mark_roll_guide_seen(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    current_user.has_seen_roll_guide = True
    db.commit()
    db.refresh(current_user)
    return current_user


@router.patch("/lab-guide-seen", response_model=UserOut)
def mark_lab_guide_seen(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    current_user.has_seen_lab_guide = True
    db.commit()
    db.refresh(current_user)
    return current_user
