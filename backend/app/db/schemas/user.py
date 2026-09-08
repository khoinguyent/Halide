from pydantic import BaseModel, EmailStr, Field, model_validator
from typing import Optional
from datetime import datetime

class TimezoneUpdate(BaseModel):
    timezone: str = Field(
        description="IANA timezone name, e.g. Asia/Bangkok or America/New_York",
        min_length=1,
        max_length=64,
    )


class LocaleUpdate(BaseModel):
    locale: str = Field(
        description="App UI language: 'system', 'en', 'vi', 'ja', 'ko', 'zh', 'es', or 'fr'",
        min_length=2,
        max_length=16,
    )

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
    has_seen_onboarding: bool = False
    has_seen_roll_guide: bool = False
    has_seen_lab_guide: bool = False
    timezone: Optional[str] = None
    preferred_locale: Optional[str] = None

    @model_validator(mode="after")
    def sync_limit(self) -> "UserOut":
        if self.plan in ("pro", "plus"):
            base = 5 * 1024 * 1024 * 1024
        else:
            base = 104857600
        
        self.storage_limit_bytes = base
        self.total_storage_limit = base + (self.additional_storage_bytes or 0)
        return self

    model_config = {
        "from_attributes": True,
        "populate_by_name": True,
    }
