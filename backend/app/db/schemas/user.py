from pydantic import BaseModel, EmailStr
from typing import Optional
from datetime import datetime

class UserBase(BaseModel):
    email: EmailStr
    display_name: str
    avatar_url: Optional[str] = None

class UserCreate(UserBase):
    id: str  # Firebase UID

class UserOut(UserBase):
    id: str
    created_at: datetime
    class Config:
        from_attributes = True
