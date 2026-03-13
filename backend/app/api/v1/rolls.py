from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from typing import List
from ...db.session import get_db
from ...db.schemas.roll import RollCreate, RollOut, RollStatusUpdate
from ...db.models.user import User
from uuid import UUID
from ...core.dependencies import get_current_user
from ...services import roll_service

router = APIRouter()

@router.get("/rolls", response_model=List[RollOut])
def read_rolls(
    skip: int = 0, 
    limit: int = 100, 
    db: Session = Depends(get_db), 
    current_user: User = Depends(get_current_user)
):
    return roll_service.get_rolls(db, user_id=current_user.id, skip=skip, limit=limit)

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

