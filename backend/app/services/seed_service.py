from sqlalchemy.orm import Session
from ..db import models
from uuid import uuid4
import datetime
import random
from typing import List

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
        
        # 2. Seed Master Cameras
        cameras = [
            {"brand": "Leica", "model": "M6", "camera_type": models.CameraTypeEnum.rangefinder},
            {"brand": "Hasselblad", "model": "500C/M", "camera_type": models.CameraTypeEnum.slr},
            {"brand": "Canon", "model": "AE-1", "camera_type": models.CameraTypeEnum.slr},
        ]
        
        for cam in cameras:
            exists = db.query(models.Camera).filter(
                models.Camera.brand == cam["brand"],
                models.Camera.model == cam["model"]
            ).first()
            if not exists:
                db.add(models.Camera(**cam))

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
    def populate_dev_data(db: Session, user_id: str):
        # Ensure user exists
        user = db.query(models.User).filter(models.User.id == user_id).first()
        if not user:
            user = models.User(id=user_id, email=f"{user_id}@example.com", display_name=user_id)
            db.add(user)
            db.commit()

        # 1. Link Cameras to User
        master_cameras = db.query(models.Camera).all()
        user_cameras = []
        for m_cam in master_cameras[:3]:
            exists = db.query(models.UserCamera).filter(
                models.UserCamera.user_id == user_id,
                models.UserCamera.camera_id == m_cam.id
            ).first()
            if not exists:
                uc = models.UserCamera(
                    user_id=user_id,
                    camera_id=m_cam.id,
                    rating_functional=random.randint(7, 10),
                    rating_view=random.randint(7, 10),
                    rating_looking=random.randint(7, 10)
                )
                db.add(uc)
                user_cameras.append(uc)
            else:
                user_cameras.append(exists)
        
        # 2. Link Lenses to User
        master_lenses = db.query(models.Lens).all()
        user_lenses = []
        for m_lens in master_lenses[:5]:
            exists = db.query(models.UserLens).filter(
                models.UserLens.user_id == user_id,
                models.UserLens.lens_id == m_lens.id
            ).first()
            if not exists:
                ul = models.UserLens(
                    user_id=user_id,
                    lens_id=m_lens.id,
                    serial_number=str(random.randint(100000, 999999)),
                    notes="Seeded developer data"
                )
                db.add(ul)
                user_lenses.append(ul)
            else:
                user_lenses.append(exists)
        
        db.commit()

        # 3. Create 10 historical rolls
        film_stocks = db.query(models.FilmStock).all()
        if not film_stocks or not user_cameras or not user_lenses:
            return

        rolls = []
        for i in range(10):
            fs = random.choice(film_stocks)
            cam = random.choice(user_cameras)
            lens = random.choice(user_lenses)
            
            roll = models.Roll(
                user_id=user_id,
                film_stock_id=fs.id,
                user_camera_id=cam.id,
                user_lens_id=lens.id,
                shot_at_iso=fs.iso,
                status=models.RollStatusEnum.scanned,
                created_at=datetime.datetime.now() - datetime.timedelta(days=random.randint(10, 100))
            )
            db.add(roll)
            rolls.append(roll)
        
        db.commit()

        # 4. Create 20 frames with rich metadata
        shutter_speeds = ["1/1000", "1/500", "1/250", "1/125", "1/60", "1/30"]
        apertures = [1.4, 2.0, 2.8, 4.0, 5.6, 8.0, 11.0, 16.0]
        
        for i in range(20):
            roll = random.choice(rolls)
            image = models.Image(
                roll_id=roll.id,
                frame_number=i+1,
                image_url=f"https://picsum.photos/seed/{uuid4()}/1200/800",
                aperture=random.choice(apertures),
                shutter_speed=random.choice(shutter_speeds),
                location_lat=random.uniform(-90, 90),
                location_lng=random.uniform(-180, 180),
                notes=f"Sample frame {i+1} metadata for development"
            )
            db.add(image)
        
        db.commit()
