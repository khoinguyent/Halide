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
    max_frames: Optional[int] = 36

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


# Dashboard/list view: frontend-friendly shape with joined film, camera, lens, image_urls
class RollOutDashboard(BaseModel):
    id: str
    brand: str
    name: str
    color: str  # hex e.g. #FFCC33
    status: str
    image_urls: List[str] = []
    nickname: Optional[str] = None
    camera_name: Optional[str] = None
    lens_name: Optional[str] = None
    frame_count: int = 0
    max_frames: int = 36
    created_at: Optional[datetime] = None
