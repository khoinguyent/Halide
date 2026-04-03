from pydantic import BaseModel
from typing import Optional
from datetime import datetime
from uuid import UUID

class ImageBase(BaseModel):
    roll_id: Optional[UUID] = None
    frame_number: Optional[int] = None
    image_url: Optional[str] = None
    aperture: Optional[float] = None
    shutter_speed: Optional[str] = None
    notes: Optional[str] = None
    location_lat: Optional[float] = None
    location_lng: Optional[float] = None
    created_at: Optional[datetime] = None

class ImageCreate(ImageBase):
    pass

class ImageOut(ImageBase):
    id: UUID
    class Config:
        from_attributes = True
