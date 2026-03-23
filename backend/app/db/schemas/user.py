from pydantic import BaseModel, EmailStr, Field, model_validator
from typing import Optional
from datetime import datetime

class UserBase(BaseModel):
    email: EmailStr
    display_name: str
    avatar_url: Optional[str] = None
    professional_nickname: Optional[str] = None
    bio: Optional[str] = None
    storage_used_bytes: int = 0
    storage_limit_bytes: int = 104857600

class UserCreate(UserBase):
    id: str  # Firebase UID

class UserOut(UserBase):
    id: str
    created_at: datetime
    plan: str = Field(validation_alias="subscription_tier")
    additional_storage_bytes: int = 0
    total_storage_limit: int = 0

    @model_validator(mode="after")
    def sync_limit(self) -> "UserOut":
        # Base limits (mirrored from model for simplicity)
        if self.plan == "pro":
            base = 5 * 1024 * 1024 * 1024 
        elif self.plan == "plus":
            base = 1 * 1024 * 1024 * 1024
        else:
            base = 104857600
        
        self.storage_limit_bytes = base
        self.total_storage_limit = base + (self.additional_storage_bytes or 0)
        return self

    model_config = {
        "from_attributes": True,
        "populate_by_name": True,
    }
