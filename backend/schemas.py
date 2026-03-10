from pydantic import BaseModel, EmailStr
from typing import Optional, List
from datetime import datetime
from uuid import UUID
from models import FormatEnum, ColorTypeEnum, CameraTypeEnum, RollStatusEnum

class UserCreate(BaseModel):
    id: str  # Firebase UID
    email: EmailStr
    display_name: str
    avatar_url: Optional[str] = None

class UserOut(BaseModel):
    id: str
    email: EmailStr
    display_name: str
    avatar_url: Optional[str] = None
    created_at: datetime
    class Config:
        from_attributes = True

class Token(BaseModel):
    access_token: str
    token_type: str

class TokenData(BaseModel):
    user_id: Optional[str] = None

class RollCreate(BaseModel):
    film_stock_id: UUID
    user_camera_id: UUID
    shot_at_iso: Optional[int] = None
    expired_year: Optional[int] = None

class RollOut(BaseModel):
    id: UUID
    user_id: str
    film_stock_id: UUID
    user_camera_id: UUID
    shot_at_iso: Optional[int]
    expired_year: Optional[int]
    status: RollStatusEnum
    created_at: datetime
    class Config:
        from_attributes = True

class UserCameraCreate(BaseModel):
    camera_id: UUID
    rating_functional: Optional[int] = None
    rating_view: Optional[int] = None
    rating_looking: Optional[int] = None

class UserCameraOut(BaseModel):
    id: UUID
    user_id: str
    camera_id: UUID
    rating_functional: Optional[int]
    rating_view: Optional[int]
    rating_looking: Optional[int]
    created_at: datetime
    class Config:
        from_attributes = True
