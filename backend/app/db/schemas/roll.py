from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime
from uuid import UUID
from ..models.roll import RollStatusEnum
from .image import ImageOut

class RollBase(BaseModel):
    film_stock_id: UUID
    user_camera_id: Optional[UUID] = None
    shot_at_iso: Optional[int] = None
    expired_year: Optional[int] = None
    max_frames: Optional[int] = 36
    title: Optional[str] = None
    description: Optional[str] = None
    shot_offset: Optional[int] = 0

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


class RollMetaUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    shot_offset: Optional[int] = None


class RollDriveUrlUpdate(BaseModel):
    # Store a Google Drive shared URL (folder or ZIP) to sync scans later.
    drive_url: Optional[str] = None


# Dashboard/list view: frontend-friendly shape with joined film, camera, lens, image_urls
class RollOutDashboard(BaseModel):
    id: str
    brand: str
    name: str
    color: str  # hex e.g. #FFCC33
    film_format: Optional[str] = None  # film stock FormatEnum name, e.g. format_135
    status: str
    image_urls: List[str] = []
    shots: List[ImageOut] = []
    drive_url: Optional[str] = None
    nickname: Optional[str] = None
    title: Optional[str] = None
    description: Optional[str] = None
    camera_name: Optional[str] = None
    lens_name: Optional[str] = None
    frame_count: int = 0
    max_frames: int = 36
    shot_offset: int = 0
    created_at: Optional[datetime] = None
