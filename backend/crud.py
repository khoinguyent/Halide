from sqlalchemy.orm import Session
import models, schemas
from uuid import UUID

def get_user(db: Session, user_id: str):
    return db.query(models.User).filter(models.User.id == user_id).first()

def create_user(db: Session, user: schemas.UserCreate):
    db_user = models.User(
        id=user.id,
        email=user.email,
        display_name=user.display_name,
        avatar_url=user.avatar_url
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user

def get_rolls(db: Session, user_id: str, skip: int = 0, limit: int = 100):
    return db.query(models.Roll).filter(models.Roll.user_id == user_id).offset(skip).limit(limit).all()

def create_roll(db: Session, roll: schemas.RollCreate, user_id: str):
    db_roll = models.Roll(**roll.dict(), user_id=user_id)
    db.add(db_roll)
    db.commit()
    db.refresh(db_roll)
    return db_roll

def get_user_cameras(db: Session, user_id: str, skip: int = 0, limit: int = 100):
    return db.query(models.UserCamera).filter(models.UserCamera.user_id == user_id).offset(skip).limit(limit).all()

def create_user_camera(db: Session, user_camera: schemas.UserCameraCreate, user_id: str):
    db_user_camera = models.UserCamera(**user_camera.dict(), user_id=user_id)
    db.add(db_user_camera)
    db.commit()
    db.refresh(db_user_camera)
    return db_user_camera

def get_film_stocks(db: Session, skip: int = 0, limit: int = 100):
    return db.query(models.FilmStock).offset(skip).limit(limit).all()

def get_cameras(db: Session, skip: int = 0, limit: int = 100):
    return db.query(models.Camera).offset(skip).limit(limit).all()
