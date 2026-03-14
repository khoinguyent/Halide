from fastapi import APIRouter, Depends, UploadFile, File, HTTPException, status
from typing import List
from sqlalchemy.orm import Session
import uuid

from ...db.models.user import User
from ...db.models.roll import Roll
from ...db.models.image import Image
from ...db.session import get_db
from ...db.schemas.image import ImageOut
from ...core.dependencies import get_current_user
from ...services.storage_service import storage_service

router = APIRouter()

@router.post("/rolls/{roll_id}/images", response_model=List[ImageOut])
async def upload_roll_images(
    roll_id: str,
    files: List[UploadFile] = File(...),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # Verify roll ownership
    roll = db.query(Roll).filter(Roll.id == roll_id).first()
    if not roll:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Roll not found"
        )
    
    if roll.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to upload to this roll"
        )
    
    uploaded_images = []
    for file in files:
        file_content = await file.read()
        image_id = str(uuid.uuid4())
        
        # Upload to Storage
        key = storage_service.upload_roll_image(
            user_id=current_user.id,
            roll_id=roll_id,
            image_id=image_id,
            file_content=file_content,
            content_type=file.content_type
        )
        
        # Save to DB
        # Note: In a real scenario we might derive URL from key or store key
        # Here we follow the model's image_url field
        db_image = Image(
            roll_id=roll_id,
            image_url=key,  # Storing the key as the URL for now
            # frame_number, aperture, shutter_speed could be extracted from EXIF in later sprints
        )
        db.add(db_image)
        uploaded_images.append(db_image)
    
    db.commit()
    return uploaded_images

from ...db.models.storage_credential import StorageCredential
from ...db.schemas.storage_credential import StorageCredentialCreate, StorageCredentialOut
from ...core.encryption import encrypt_credential

@router.post("/connect", response_model=StorageCredentialOut)
def connect_storage(
    data: StorageCredentialCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # Depending on provider, you would typically run OAuth flow here.
    # For now we save the incoming config directly.
    encrypted_data = encrypt_credential(data.auth_data)
    cred = StorageCredential(
        user_id=current_user.id,
        provider=data.provider,
        identifier=data.identifier,
        host=data.host,
        username=data.username,
        encrypted_auth_data=encrypted_data,
        is_archive=data.is_archive
    )
    db.add(cred)
    db.commit()
    db.refresh(cred)
    return cred

@router.get("/connections", response_model=List[StorageCredentialOut])
def list_connections(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    return db.query(StorageCredential).filter(StorageCredential.user_id == current_user.id).all()
