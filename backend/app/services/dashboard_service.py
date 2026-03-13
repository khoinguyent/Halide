from sqlalchemy.orm import Session
from ..db.models.user import User
from ..db.models.camera import UserCamera
from ..db.models.roll import Roll
from . import gear_service, roll_service

def get_user_dashboard(db: Session, user_id: str):
    user = db.query(User).filter(User.id == user_id).first()
    cameras = gear_service.get_user_cameras(db, user_id=user_id)
    recent_rolls = roll_service.get_rolls(db, user_id=user_id, limit=30)
    
    return {
        "user": user,
        "cameras": cameras,
        "recent_rolls": recent_rolls
    }
