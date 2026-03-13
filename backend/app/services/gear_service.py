from sqlalchemy.orm import Session
from ..db.models.camera import UserCamera
from ..db.schemas.camera import UserCameraCreate

def get_user_cameras(db: Session, user_id: str, skip: int = 0, limit: int = 100):
    return db.query(UserCamera).filter(UserCamera.user_id == user_id).offset(skip).limit(limit).all()

def create_user_camera(db: Session, user_camera: UserCameraCreate, user_id: str):
    db_user_camera = UserCamera(**user_camera.dict(), user_id=user_id)
    db.add(db_user_camera)
    db.commit()
    db.refresh(db_user_camera)
    return db_user_camera
