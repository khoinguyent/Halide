from pydantic import BaseModel
from typing import Optional, List
from uuid import UUID
from ..models.film_stock import FormatEnum, ColorTypeEnum

class FilmStockBase(BaseModel):
    brand: str
    name: str
    iso: int
    format: FormatEnum
    color_type: ColorTypeEnum
    description: Optional[str] = None
    best_practice: Optional[str] = None

class FilmStockOut(FilmStockBase):
    id: UUID
    image_urls: Optional[List[str]] = None
    class Config:
        from_attributes = True

class LensBase(BaseModel):
    brand: str
    model: str
    focal_length_mm: int
    max_aperture: float
    description: Optional[str] = None

class LensOut(LensBase):
    id: UUID
    image_urls: Optional[List[str]] = None
    class Config:
        from_attributes = True

class CameraBase(BaseModel):
    brand: str
    model: str
    camera_type: str
    description: Optional[str] = None
    best_practice: Optional[str] = None

class CameraOut(CameraBase):
    id: UUID
    image_urls: Optional[List[str]] = None
    class Config:
        from_attributes = True
