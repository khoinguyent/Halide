from sqlalchemy.orm import Session
from ..db.models.roll import Roll
from ..db.schemas.roll import RollCreate

def get_rolls(db: Session, user_id: str, skip: int = 0, limit: int = 100):
    return db.query(Roll).filter(Roll.user_id == user_id).offset(skip).limit(limit).all()

def create_roll(db: Session, roll: RollCreate, user_id: str):
    db_roll = Roll(**roll.dict(), user_id=user_id)
    db.add(db_roll)
    db.commit()
    db.refresh(db_roll)
    return db_roll
