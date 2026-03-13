from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime
from uuid import UUID

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

class UserLensCreate(UserLensBase):
    pass

class UserLensOut(UserLensBase):
    id: UUID
    user_id: str
    created_at: datetime
    class Config:
        from_attributes = True

class UserCameraBase(BaseModel):
    camera_id: UUID
    gear_nickname: Optional[str] = None
    rating_functional: Optional[int] = None
    rating_view: Optional[int] = None
    rating_looking: Optional[int] = None

class UserCameraCreate(UserCameraBase):
    pass

class UserCameraOut(UserCameraBase):
    id: UUID
    user_id: str
    created_at: datetime
    lenses: List[UserLensOut] = []
    class Config:
        from_attributes = True
