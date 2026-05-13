import logging
from fastapi import APIRouter, Depends, Form, File, UploadFile, HTTPException, status
from sqlalchemy.orm import Session
from typing import Optional

from firebase_admin import auth as firebase_auth

from ...db.session import get_db
from ...db.schemas.user import UserOut
from ...db.models.user import User, PurchaseHistory
from ...db.models.roll import Roll
from ...db.models.image import Image
from ...db.models.camera import UserCamera, UserLens
from ...db.models.storage_credential import StorageCredential
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


@router.delete("/account", status_code=status.HTTP_204_NO_CONTENT)
def delete_account(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Permanently delete the authenticated user's account and associated application data
    (rolls, images, gear, storage credentials, purchase history). Does not delete
    master catalog rows (cameras, lenses, film stocks).
    """
    uid = current_user.id
    try:
        roll_ids = [row[0] for row in db.query(Roll.id).filter(Roll.user_id == uid).all()]
        if roll_ids:
            db.query(Image).filter(Image.roll_id.in_(roll_ids)).delete(synchronize_session=False)
        db.query(Roll).filter(Roll.user_id == uid).delete(synchronize_session=False)
        db.query(UserLens).filter(UserLens.user_id == uid).delete(synchronize_session=False)
        db.query(UserCamera).filter(UserCamera.user_id == uid).delete(synchronize_session=False)
        db.query(StorageCredential).filter(StorageCredential.user_id == uid).delete(synchronize_session=False)
        db.query(PurchaseHistory).filter(PurchaseHistory.user_id == uid).delete(synchronize_session=False)
        db.query(User).filter(User.id == uid).delete(synchronize_session=False)
        db.commit()
    except Exception:
        logger.exception("delete_account: database delete failed for user_id=%s", uid)
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Could not delete account data. Please try again.",
        )

    try:
        firebase_auth.delete_user(uid)
    except Exception:
        logger.exception("delete_account: Firebase delete_user failed for uid=%s", uid)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Account data was removed but sign-in could not be finalized. Please contact support.",
        )

    return None
