import uuid as uuid_lib
import logging
from typing import List, Optional

from sqlalchemy.orm import Session, joinedload
from uuid import UUID
from ..db.models.camera import UserCamera, UserLens, Camera, Lens
from ..db.models.user import User
from ..db.schemas.camera import UserCameraCreate, UserLensCreate, UserCameraUpdate, UserLensUpdate
from .storage_service import storage_service
from .roll_service import public_http_url_for_storage_key
from .gear_tier_limits import (
    assert_can_attach_lens,
    assert_can_create_camera,
    assert_can_create_standalone_lens,
)

logger = logging.getLogger(__name__)

def get_user_cameras(db: Session, user_id: str, skip: int = 0, limit: int = 100):
    return db.query(UserCamera).options(
        joinedload(UserCamera.camera),
        joinedload(UserCamera.lenses).joinedload(UserLens.lens),
    ).filter(UserCamera.user_id == user_id).offset(skip).limit(limit).all()

def get_user_camera_by_id(db: Session, user_camera_id: UUID, user_id: str):
    return db.query(UserCamera).options(
        joinedload(UserCamera.camera),
        joinedload(UserCamera.lenses).joinedload(UserLens.lens),
    ).filter(UserCamera.id == user_camera_id, UserCamera.user_id == user_id).first()

def create_user_camera(db: Session, user_camera: UserCameraCreate, user_id: str, *, user: Optional[User] = None):
    if user is not None:
        assert_can_create_camera(db, user)
    data = user_camera.dict(exclude_unset=True)
    camera_id = data.get("camera_id")
    
    if not camera_id and data.get("brand") and data.get("model"):
        # Look up or create master camera
        brand = data.pop("brand")
        model = data.pop("model")
        master = db.query(Camera).filter(
            Camera.brand.ilike(brand),
            Camera.model.ilike(model)
        ).first()
        
        if not master:
            master = Camera(
                brand=brand,
                model=model,
                camera_type='SLR' # Default for auto-created
            )
            db.add(master)
            db.flush() # Get the new ID
        camera_id = master.id
        data["camera_id"] = camera_id
    
    db_user_camera = UserCamera(**data, user_id=user_id)
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

def create_user_lens(db: Session, user_lens: UserLensCreate, user_id: str, *, user: Optional[User] = None):
    data = user_lens.dict(exclude_unset=True)
    parent_id = data.get("parent_camera_id")
    if user is not None:
        if parent_id is None:
            assert_can_create_standalone_lens(user)
        else:
            assert_can_attach_lens(db, user, parent_id)
    lens_id = data.get("lens_id")
    
    if not lens_id and data.get("brand") and data.get("model"):
        # Look up or create master lens
        brand = data.pop("brand")
        model = data.pop("model")
        master = db.query(Lens).filter(
            Lens.brand.ilike(brand),
            Lens.model.ilike(model)
        ).first()
        
        if not master:
            master = Lens(
                brand=brand,
                model=model
            )
            db.add(master)
            db.flush()
        lens_id = master.id
        data["lens_id"] = lens_id
        
    db_user_lens = UserLens(**data, user_id=user_id)
    db.add(db_user_lens)
    db.commit()
    # Reload with relations
    return db.query(UserLens).options(joinedload(UserLens.lens)).filter(UserLens.id == db_user_lens.id).first()

def update_user_lens(db: Session, user_lens_id: UUID, user_id: str, update: UserLensUpdate, *, user: Optional[User] = None):
    row = db.query(UserLens).filter(UserLens.id == user_lens_id, UserLens.user_id == user_id).first()
    if not row:
        return None
    data = update.dict(exclude_unset=True)
    new_parent = data.get("parent_camera_id")
    if user is not None and new_parent is not None and new_parent != row.parent_camera_id:
        assert_can_attach_lens(db, user, new_parent, exclude_lens_id=user_lens_id)
    for k, v in data.items():
        setattr(row, k, v)
    db.commit()
    return db.query(UserLens).options(joinedload(UserLens.lens)).filter(UserLens.id == user_lens_id).first()

def get_user_lenses(db: Session, user_id: str, skip: int = 0, limit: int = 100):
    return db.query(UserLens).options(joinedload(UserLens.lens)).filter(UserLens.user_id == user_id).offset(skip).limit(limit).all()


def upload_gear_photos(
    db: Session,
    user_camera_id: UUID,
    user_id: str,
    files_content: List[bytes],
) -> Optional[UserCamera]:
    """
    Upload each image to R2 under users/{uid}/gear/{camera_id}/..., append **HTTPS** URLs to
    user_cameras.image_urls (device-local paths are not durable across reinstalls).
    """
    row = db.query(UserCamera).filter(UserCamera.id == user_camera_id, UserCamera.user_id == user_id).first()
    if not row:
        other = db.query(UserCamera).filter(UserCamera.id == user_camera_id).first()
        logger.warning(
            "upload_gear_photos: no UserCamera for user_camera_id=%s user_id=%s row_exists_other_user=%s",
            user_camera_id,
            user_id,
            other is not None,
        )
        return None

    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        return None

    max_bytes = 15 * 1024 * 1024
    existing_urls = list(row.image_urls or []) if isinstance(row.image_urls, list) else []

    for file_content in files_content:
        if len(file_content) > max_bytes:
            continue
        if user.storage_used_bytes + len(file_content) > user.total_storage_limit:
            break

        image_id = str(uuid_lib.uuid4())
        key, stored_main_bytes = storage_service.upload_gear_image(
            user_id,
            str(user_camera_id),
            image_id,
            file_content,
        )
        public_url = public_http_url_for_storage_key(key)
        existing_urls.append(public_url)
        user.storage_used_bytes += stored_main_bytes
        db.add(user)

    row.image_urls = existing_urls
    db.add(row)
    db.commit()
    db.refresh(row)
    return db.query(UserCamera).options(
        joinedload(UserCamera.camera),
        joinedload(UserCamera.lenses).joinedload(UserLens.lens),
    ).filter(UserCamera.id == user_camera_id).first()
