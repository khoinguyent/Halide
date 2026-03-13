from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime
from uuid import UUID
from ..models.roll import RollStatusEnum

class RollBase(BaseModel):
    film_stock_id: UUID
    user_camera_id: UUID
    shot_at_iso: Optional[int] = None
    expired_year: Optional[int] = None

class RollCreate(RollBase):
    pass

class RollOut(RollBase):
    id: UUID
    user_id: str
    status: RollStatusEnum
    created_at: datetime
    class Config:
        from_attributes = True

class RollStatusUpdate(BaseModel):
    status: RollStatusEnum
