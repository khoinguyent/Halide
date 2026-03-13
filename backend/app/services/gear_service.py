from sqlalchemy.orm import Session, joinedload
from ..db.models.camera import UserCamera, UserLens
from ..db.schemas.camera import UserCameraCreate, UserLensCreate

def get_user_cameras(db: Session, user_id: str, skip: int = 0, limit: int = 100):
    return db.query(UserCamera).options(joinedload(UserCamera.lenses)).filter(UserCamera.user_id == user_id).offset(skip).limit(limit).all()

def create_user_camera(db: Session, user_camera: UserCameraCreate, user_id: str):
    db_user_camera = UserCamera(**user_camera.dict(), user_id=user_id)
    db.add(db_user_camera)
    db.commit()
    db.refresh(db_user_camera)
    return db_user_camera

def create_user_lens(db: Session, user_lens: UserLensCreate, user_id: str):
    db_user_lens = UserLens(**user_lens.dict(), user_id=user_id)
    db.add(db_user_lens)
    db.commit()
    db.refresh(db_user_lens)
    return db_user_lens

def get_user_lenses(db: Session, user_id: str, skip: int = 0, limit: int = 100):
    return db.query(UserLens).filter(UserLens.user_id == user_id).offset(skip).limit(limit).all()
