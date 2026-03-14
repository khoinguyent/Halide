from sqlalchemy.orm import Session, joinedload
from uuid import UUID
from ..db.models.camera import UserCamera, UserLens
from ..db.schemas.camera import UserCameraCreate, UserLensCreate, UserCameraUpdate

def get_user_cameras(db: Session, user_id: str, skip: int = 0, limit: int = 100):
    return db.query(UserCamera).options(
        joinedload(UserCamera.camera),
        joinedload(UserCamera.lenses),
    ).filter(UserCamera.user_id == user_id).offset(skip).limit(limit).all()

def get_user_camera_by_id(db: Session, user_camera_id: UUID, user_id: str):
    return db.query(UserCamera).options(
        joinedload(UserCamera.camera),
        joinedload(UserCamera.lenses),
    ).filter(UserCamera.id == user_camera_id, UserCamera.user_id == user_id).first()

def create_user_camera(db: Session, user_camera: UserCameraCreate, user_id: str):
    db_user_camera = UserCamera(**user_camera.dict(), user_id=user_id)
    db.add(db_user_camera)
    db.commit()
    db.refresh(db_user_camera)
    return db_user_camera

def update_user_camera(db: Session, user_camera_id: UUID, user_id: str, update: UserCameraUpdate):
    row = db.query(UserCamera).filter(UserCamera.id == user_camera_id, UserCamera.user_id == user_id).first()
    if not row:
        return None
    data = update.dict(exclude_unset=True)
    for k, v in data.items():
        setattr(row, k, v)
    db.commit()
    db.refresh(row)
    return row

def create_user_lens(db: Session, user_lens: UserLensCreate, user_id: str):
    db_user_lens = UserLens(**user_lens.dict(), user_id=user_id)
    db.add(db_user_lens)
    db.commit()
    db.refresh(db_user_lens)
    return db_user_lens

def get_user_lenses(db: Session, user_id: str, skip: int = 0, limit: int = 100):
    return db.query(UserLens).filter(UserLens.user_id == user_id).offset(skip).limit(limit).all()
