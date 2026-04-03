from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime
from uuid import UUID

class CameraRef(BaseModel):
    """Minimal camera info for embedding in UserCameraOut."""
    id: UUID
    brand: str
    model: str
    image_urls: Optional[List[str]] = None
    class Config:
        from_attributes = True

class LensBase(BaseModel):
    brand: str
    model: str
    focal_length: Optional[str] = None
    max_aperture: Optional[str] = None

class LensCreate(LensBase):
    pass

class LensOut(LensBase):
    id: UUID
    class Config:
        from_attributes = True

class UserLensBase(BaseModel):
    lens_id: UUID
    parent_camera_id: Optional[UUID] = None
    gear_nickname: Optional[str] = None

class UserLensCreate(BaseModel):
    lens_id: Optional[UUID] = None
    brand: Optional[str] = None
    model: Optional[str] = None
    serial_number: Optional[str] = None
    parent_camera_id: Optional[UUID] = None
    gear_nickname: Optional[str] = None
class UserLensUpdate(BaseModel):
    parent_camera_id: Optional[UUID] = None
    gear_nickname: Optional[str] = None

class UserLensOut(UserLensBase):
    id: UUID
    user_id: str
    created_at: datetime
    lens: Optional[LensOut] = None
    class Config:
        from_attributes = True

from ..models.camera import GearStatusEnum

class UserCameraBase(BaseModel):
    camera_id: UUID
    gear_nickname: Optional[str] = None
    rating_functional: Optional[int] = None
    rating_view: Optional[int] = None
    rating_looking: Optional[int] = None
    image_urls: Optional[List[str]] = None
    primary_image_index: int = 0
    status: GearStatusEnum = GearStatusEnum.active

class UserCameraCreate(BaseModel):
    camera_id: Optional[UUID] = None
    brand: Optional[str] = None
    model: Optional[str] = None
    gear_nickname: Optional[str] = None
    image_urls: Optional[List[str]] = None
    primary_image_index: int = 0
    status: GearStatusEnum = GearStatusEnum.active

class UserCameraUpdate(BaseModel):
    """Partial update for user camera (e.g. gear images)."""
    gear_nickname: Optional[str] = None
    image_urls: Optional[List[str]] = None
    primary_image_index: Optional[int] = None
    status: Optional[GearStatusEnum] = None

class UserCameraOut(UserCameraBase):
    id: UUID
    user_id: str
    created_at: datetime
    lenses: List[UserLensOut] = []
    camera: Optional[CameraRef] = None
    class Config:
        from_attributes = True
