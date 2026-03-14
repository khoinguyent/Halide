from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from ...db.session import get_db
from ...db.schemas.roll import RollCreate, RollOut, RollOutDashboard, RollStatusUpdate
from ...db.models.user import User
from uuid import UUID
from ...core.dependencies import get_current_user
from ...services import roll_service

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

