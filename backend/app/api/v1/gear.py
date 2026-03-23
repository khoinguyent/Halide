from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from uuid import UUID
from ...db.session import get_db
from ...db.schemas.camera import UserCameraCreate, UserCameraOut, UserCameraUpdate, UserLensCreate, UserLensOut, UserLensUpdate
from ...db.models.user import User
from ...core.dependencies import get_current_user
from ...services import gear_service

router = APIRouter()

@router.patch("/user_lenses/{user_lens_id}", response_model=UserLensOut)
def update_user_lens(
    user_lens_id: UUID,
    body: UserLensUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    row = gear_service.update_user_lens(db, user_lens_id, current_user.id, body)
    if not row:
        raise HTTPException(status_code=404, detail="User lens not found")
    return row

@router.get("/user_cameras", response_model=List[UserCameraOut])
def read_user_cameras(
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    return gear_service.get_user_cameras(db, user_id=current_user.id, skip=skip, limit=limit)

@router.get("/user_cameras/{user_camera_id}", response_model=UserCameraOut)
def read_user_camera(
    user_camera_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    row = gear_service.get_user_camera_by_id(db, user_camera_id, current_user.id)
    if not row:
        raise HTTPException(status_code=404, detail="User camera not found")
    return row

@router.post("/user_cameras", response_model=UserCameraOut)
def create_user_camera(
    user_camera: UserCameraCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    return gear_service.create_user_camera(db=db, user_camera=user_camera, user_id=current_user.id)

@router.patch("/user_cameras/{user_camera_id}", response_model=UserCameraOut)
def update_user_camera(
    user_camera_id: UUID,
    body: UserCameraUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    row = gear_service.update_user_camera(db, user_camera_id, current_user.id, body)
    if not row:
        raise HTTPException(status_code=404, detail="User camera not found")
    return row

@router.get("/user_lenses", response_model=List[UserLensOut])
def read_user_lenses(
    skip: int = 0, 
    limit: int = 100, 
    db: Session = Depends(get_db), 
    current_user: User = Depends(get_current_user)
):
    return gear_service.get_user_lenses(db, user_id=current_user.id, skip=skip, limit=limit)

@router.post("/user_lenses", response_model=UserLensOut)
def create_user_lens(
    user_lens: UserLensCreate, 
    db: Session = Depends(get_db), 
    current_user: User = Depends(get_current_user)
):
    return gear_service.create_user_lens(db=db, user_lens=user_lens, user_id=current_user.id)
