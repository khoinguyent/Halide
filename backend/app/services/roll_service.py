from fastapi import HTTPException
from sqlalchemy.orm import Session
from ..db.models.roll import Roll, RollStatusEnum
from ..db.schemas.roll import RollCreate

def get_roll(db: Session, roll_id: str, user_id: str):
    return db.query(Roll).filter(Roll.id == roll_id, Roll.user_id == user_id).first()

def get_rolls(db: Session, user_id: str, skip: int = 0, limit: int = 100):
    return db.query(Roll).filter(Roll.user_id == user_id).order_by(Roll.created_at.desc()).offset(skip).limit(limit).all()

def create_roll(db: Session, roll: RollCreate, user_id: str):
    db_roll = Roll(**roll.dict(), user_id=user_id)
    db.add(db_roll)
    db.commit()
    db.refresh(db_roll)
    return db_roll

def update_roll_status(db: Session, roll_id: str, new_status: RollStatusEnum, user_id: str):
    db_roll = get_roll(db, roll_id, user_id)
    if not db_roll:
        raise HTTPException(status_code=404, detail="Roll not found")
    
    # Simple transition validation logic
    # loaded -> shooting -> lab -> scanned -> archived
    # We allow skipping but not going backwards (except maybe from archived? No, spec says no illegal jumps)
    
    order = {
        RollStatusEnum.loaded: 0,
        RollStatusEnum.shooting: 1,
        RollStatusEnum.lab: 2,
        RollStatusEnum.scanned: 3,
        RollStatusEnum.archived: 4
    }
    
    current_idx = order.get(db_roll.status)
    new_idx = order.get(new_status)
    
    if new_idx < current_idx:
        raise HTTPException(
            status_code=400, 
            detail={
                "code": "invalid_status_transition",
                "message": f"Cannot transition from {db_roll.status.value} to {new_status.value}"
            }
        )
        
    db_roll.status = new_status
    db.add(db_roll)
    db.commit()
    db.refresh(db_roll)
    return db_roll
