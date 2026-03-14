from fastapi import APIRouter, Depends, Form, File, UploadFile, HTTPException, status
from sqlalchemy.orm import Session
from typing import Optional

from ...db.session import get_db
from ...db.schemas.user import UserOut
from ...db.models.user import User
from ...core.dependencies import get_current_user
from ...services.storage_service import storage_service
from ...core.config import settings

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
        if not avatar.content_type.startswith("image/"):
            raise HTTPException(status_code=400, detail="File provided is not an image.")
            
        content = await avatar.read()
        storage_service.upload_avatar(
            user_id=current_user.id,
            file_content=content,
            content_type=avatar.content_type
        )
        # Note: Depending on your S3 setup you might want to prepend the endpoint/bucket url,
        # but storing the key or relative path is sometimes preferred.
        # Here we'll construct a full CDN/S3 URL if needed, or just set it:
        # Constructing a generic URL based on S3_ENDPOINT and S3_BUCKET_NAME as fallback
        
        base_url = settings.S3_ENDPOINT.rstrip('/')
        bucket = settings.S3_BUCKET_NAME
        # Very simple URL construction - adjust strictly according to your actual setup if different.
        if "r2.cloudflarestorage.com" in base_url or "amazonaws.com" in base_url:
            # Often virtual hosted style or path style. Let's use path style as a safe default for dev.
            avatar_url = f"{base_url}/{bucket}/users/{current_user.id}/profile/avatar.jpg"
        else:
             avatar_url = f"{base_url}/{bucket}/users/{current_user.id}/profile/avatar.jpg"
             
        current_user.avatar_url = avatar_url

    db.commit()
    db.refresh(current_user)
    
    return current_user
