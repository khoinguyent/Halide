from pydantic import BaseModel
from typing import Optional
from datetime import datetime
from uuid import UUID

class UserCameraBase(BaseModel):
    camera_id: UUID
    rating_functional: Optional[int] = None
    rating_view: Optional[int] = None
    rating_looking: Optional[int] = None

class UserCameraCreate(UserCameraBase):
    pass

class UserCameraOut(UserCameraBase):
    id: UUID
    user_id: str
    created_at: datetime
    class Config:
        from_attributes = True
