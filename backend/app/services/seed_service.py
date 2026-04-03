from sqlalchemy.orm import Session, joinedload
from ..db import models
from uuid import uuid4
import datetime
import random
from typing import List

# Default gear image URLs by (brand, model) when master camera has none
_GEAR_IMAGE_URLS = {
    ("Leica", "M6"): ["https://images.unsplash.com/photo-1516035069371-29a1b244cc32"],
    ("Hasselblad", "500C/M"): ["https://images.unsplash.com/photo-1585155770148-7d436f2e2c0a"],
    ("Canon", "AE-1"): ["https://images.unsplash.com/photo-1606983340126-99ab4feaa64a"],
    ("Pentax", "67"): ["https://images.unsplash.com/photo-1492691527719-9d1e07e534b4"],
}

class SeedService:
    @staticmethod
    def seed_master_data(db: Session):
        # 1. Seed Film Stocks
        film_stocks = [
            {"brand": "Kodak", "name": "Portra 400", "iso": 400, "format": models.FormatEnum.format_135, "color_type": models.ColorTypeEnum.color_negative},
            {"brand": "Kodak", "name": "Tri-X 400", "iso": 400, "format": models.FormatEnum.format_135, "color_type": models.ColorTypeEnum.b_w},
            {"brand": "Fujifilm", "name": "Pro 400H", "iso": 400, "format": models.FormatEnum.format_120, "color_type": models.ColorTypeEnum.color_negative},
            {"brand": "Fujifilm", "name": "Superia 400", "iso": 400, "format": models.FormatEnum.format_135, "color_type": models.ColorTypeEnum.color_negative},
            {"brand": "Ilford", "name": "HP5 Plus", "iso": 400, "format": models.FormatEnum.format_135, "color_type": models.ColorTypeEnum.b_w},
        ]
        
        for fs in film_stocks:
            exists = db.query(models.FilmStock).filter(
                models.FilmStock.brand == fs["brand"],
                models.FilmStock.name == fs["name"],
                models.FilmStock.format == fs["format"]
            ).first()
            if not exists:
                db.add(models.FilmStock(**fs))
        
        # 2. Seed Master Cameras (with seed images for locker UI)
        cameras = [
            {"brand": "Leica", "model": "M6", "camera_type": models.CameraTypeEnum.rangefinder, "image_urls": ["https://images.unsplash.com/photo-1516035069371-29a1b244cc32"]},
            {"brand": "Hasselblad", "model": "500C/M", "camera_type": models.CameraTypeEnum.slr, "image_urls": ["https://images.unsplash.com/photo-1585155770148-7d436f2e2c0a"]},
            {"brand": "Canon", "model": "AE-1", "camera_type": models.CameraTypeEnum.slr, "image_urls": ["https://images.unsplash.com/photo-1606983340126-99ab4feaa64a"]},
            {"brand": "Pentax", "model": "67", "camera_type": models.CameraTypeEnum.slr, "image_urls": ["https://images.unsplash.com/photo-1492691527719-9d1e07e534b4"]},
        ]
        
        for cam in cameras:
            existing = db.query(models.Camera).filter(
                models.Camera.brand == cam["brand"],
                models.Camera.model == cam["model"]
            ).first()
            if not existing:
                db.add(models.Camera(**cam))
            elif existing.image_urls is None or existing.image_urls == []:
                existing.image_urls = cam.get("image_urls")

        # 2b. Backfill user_cameras image_urls / primary_image_index from linked camera
        SeedService._backfill_user_camera_gear_urls(db)

        # 3. Seed Master Lenses
        lenses = [
            {"brand": "Leica", "model": "Summicron 35mm f/2", "focal_length_mm": 35, "max_aperture": 2.0},
            {"brand": "Carl Zeiss", "model": "Planar 80mm f/2.8", "focal_length_mm": 80, "max_aperture": 2.8},
            {"brand": "Canon", "model": "50mm f/1.8 SC", "focal_length_mm": 50, "max_aperture": 1.8},
            {"brand": "Voigtlander", "model": "Nokton 40mm f/1.4", "focal_length_mm": 40, "max_aperture": 1.4},
            {"brand": "Nikon", "model": "Nikkor-S 50mm f/1.4", "focal_length_mm": 50, "max_aperture": 1.4},
        ]
        
        for lens in lenses:
            exists = db.query(models.Lens).filter(
                models.Lens.brand == lens["brand"],
                models.Lens.model == lens["model"]
            ).first()
            if not exists:
                db.add(models.Lens(**lens))
        
        db.commit()

    @staticmethod
    def _backfill_user_camera_gear_urls(db: Session):
        """Set image_urls and primary_image_index on user_cameras that have none."""
        rows = db.query(models.UserCamera).options(joinedload(models.UserCamera.camera)).all()
        updated = 0
        for uc in rows:
            if uc.image_urls and len(uc.image_urls) > 0:
                continue
            urls = None
            if uc.camera:
                urls = uc.camera.image_urls or _GEAR_IMAGE_URLS.get((uc.camera.brand, uc.camera.model))
            uc.image_urls = urls or []
            uc.primary_image_index = 0
            updated += 1
        if updated:
            db.commit()

    @staticmethod
    def _backfill_user_camera_gear_urls(db: Session):
        """Set image_urls and primary_image_index on user_cameras that have none."""
        rows = db.query(models.UserCamera).options(joinedload(models.UserCamera.camera)).all()
        updated = 0
        for uc in rows:
            if uc.image_urls and len(uc.image_urls) > 0:
                continue
            urls = None
            if uc.camera:
                urls = uc.camera.image_urls or _GEAR_IMAGE_URLS.get((uc.camera.brand, uc.camera.model))
            uc.image_urls = urls or []
            uc.primary_image_index = 0
            updated += 1
        if updated:
            db.commit()
