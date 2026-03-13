from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from typing import List
from ...db.session import get_db
from ...db.schemas.camera import UserCameraCreate, UserCameraOut
from ...db.models.user import User
from ...core.dependencies import get_current_user
from ...services import gear_service

router = APIRouter()

@router.get("/user_cameras", response_model=List[UserCameraOut])
def read_user_cameras(
    skip: int = 0, 
    limit: int = 100, 
    db: Session = Depends(get_db), 
    current_user: User = Depends(get_current_user)
):
    return gear_service.get_user_cameras(db, user_id=current_user.id, skip=skip, limit=limit)

@router.post("/user_cameras", response_model=UserCameraOut)
def create_user_camera(
    user_camera: UserCameraCreate, 
    db: Session = Depends(get_db), 
    current_user: User = Depends(get_current_user)
):
    return gear_service.create_user_camera(db=db, user_camera=user_camera, user_id=current_user.id)
