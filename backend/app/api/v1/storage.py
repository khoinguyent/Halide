from fastapi import APIRouter, Depends, UploadFile, File
from ...db.models.user import User
from ...core.dependencies import get_current_user
from ...services.storage_service import storage_service
import uuid

router = APIRouter()

@router.post("/upload_roll_image/{roll_id}")
async def upload_roll_image(
    roll_id: str,
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user)
):
    file_content = await file.read()
    image_id = str(uuid.uuid4())
    key = storage_service.upload_roll_image(
        user_id=current_user.id,
        roll_id=roll_id,
        image_id=image_id,
        file_content=file_content,
        content_type=file.content_type
    )
    return {"key": key, "image_id": image_id}
