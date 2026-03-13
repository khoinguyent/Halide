from sqlalchemy.orm import Session
from ..db.models.user import User
from ..db.schemas.user import UserCreate

def get_user(db: Session, user_id: str):
    return db.query(User).filter(User.id == user_id).first()

def create_user(db: Session, user: UserCreate):
    db_user = User(
        id=user.id,
        email=user.email,
        display_name=user.display_name,
        avatar_url=user.avatar_url
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user
