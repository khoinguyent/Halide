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
            uc.image_urls = urls or ["https://images.unsplash.com/photo-1516035069371-29a1b244cc32"]
            uc.primary_image_index = 0
            updated += 1
        if updated:
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
                urls = m_cam.image_urls or _GEAR_IMAGE_URLS.get((m_cam.brand, m_cam.model)) or ["https://images.unsplash.com/photo-1516035069371-29a1b244cc32"]
                uc = models.UserCamera(
                    user_id=user_id,
                    camera_id=m_cam.id,
                    rating_functional=random.randint(7, 10),
                    rating_view=random.randint(7, 10),
                    rating_looking=random.randint(7, 10),
                    image_urls=urls,
                    primary_image_index=0,
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

    @staticmethod
    def seed_dashboard_rolls(db: Session, user_id: str):
        """Replace user's rolls with exactly 2 Shooting, 2 At Lab, 1 Scanned (with 5 images)."""
        user = db.query(models.User).filter(models.User.id == user_id).first()
        if not user:
            user = models.User(id=user_id, email=f"{user_id}@example.com", display_name=user_id)
            db.add(user)
            db.commit()
        SeedService.seed_master_data(db)

        # Ensure user has at least one camera and one lens (no extra rolls)
        master_cameras = db.query(models.Camera).all()
        user_cameras = list(db.query(models.UserCamera).filter(models.UserCamera.user_id == user_id).all())
        if not user_cameras and master_cameras:
            m_cam = master_cameras[0]
            urls = m_cam.image_urls or _GEAR_IMAGE_URLS.get((m_cam.brand, m_cam.model)) or ["https://images.unsplash.com/photo-1516035069371-29a1b244cc32"]
            uc = models.UserCamera(
                user_id=user_id,
                camera_id=m_cam.id,
                rating_functional=8,
                rating_view=8,
                rating_looking=8,
                image_urls=urls,
                primary_image_index=0,
            )
            db.add(uc)
            db.commit()
            db.refresh(uc)
            user_cameras = [uc]
        master_lenses = db.query(models.Lens).all()
        user_lenses = list(db.query(models.UserLens).filter(models.UserLens.user_id == user_id).all())
        if not user_lenses and master_lenses:
            ul = models.UserLens(
                user_id=user_id,
                lens_id=master_lenses[0].id,
                serial_number="123456",
                notes="Seeded",
            )
            db.add(ul)
            db.commit()
            db.refresh(ul)
            user_lenses = [ul]

        # Delete existing rolls and their images for this user
        roll_ids = [r.id for r in db.query(models.Roll).filter(models.Roll.user_id == user_id).all()]
        if roll_ids:
            db.query(models.Image).filter(models.Image.roll_id.in_(roll_ids)).delete(synchronize_session=False)
            db.query(models.Roll).filter(models.Roll.user_id == user_id).delete(synchronize_session=False)
            db.commit()

        film_stocks = db.query(models.FilmStock).all()
        user_cameras = db.query(models.UserCamera).filter(models.UserCamera.user_id == user_id).all()
        user_lenses = db.query(models.UserLens).filter(models.UserLens.user_id == user_id).all()
        if not film_stocks or not user_cameras or not user_lenses:
            return

        # Ensure we have Kodak Ektar 100 for the scanned roll
        ektar = db.query(models.FilmStock).filter(
            models.FilmStock.brand == "Kodak",
            models.FilmStock.name == "Ektar 100",
        ).first()
        if not ektar:
            ektar = models.FilmStock(
                brand="Kodak",
                name="Ektar 100",
                iso=100,
                format=models.FormatEnum.format_135,
                color_type=models.ColorTypeEnum.color_negative,
            )
            db.add(ektar)
            db.commit()
            db.refresh(ektar)

        def _roll(film, camera, lens, status, days_ago=0):
            r = models.Roll(
                user_id=user_id,
                film_stock_id=film.id,
                user_camera_id=camera.id,
                user_lens_id=lens.id,
                shot_at_iso=film.iso,
                status=status,
                created_at=datetime.datetime.now() - datetime.timedelta(days=days_ago),
            )
            db.add(r)
            db.flush()
            return r

        # 2 Shooting
        portra = next((f for f in film_stocks if f.name == "Portra 400"), film_stocks[0])
        superia = next((f for f in film_stocks if f.name == "Superia 400"), film_stocks[0])
        cam, lens = user_cameras[0], user_lenses[0]
        _roll(portra, cam, lens, models.RollStatusEnum.shooting, 2)
        _roll(superia, cam, lens, models.RollStatusEnum.shooting, 5)
        # 2 At Lab
        hp5 = next((f for f in film_stocks if f.name == "HP5 Plus"), film_stocks[0])
        trix = next((f for f in film_stocks if f.name == "Tri-X 400"), film_stocks[0])
        _roll(hp5, cam, lens, models.RollStatusEnum.lab, 14)
        _roll(trix, cam, lens, models.RollStatusEnum.lab, 21)
        # 1 Scanned (with 5 images)
        scanned_roll = _roll(ektar, cam, lens, models.RollStatusEnum.scanned, 30)
        db.commit()
        db.refresh(scanned_roll)
        for i in range(5):
            img = models.Image(
                roll_id=scanned_roll.id,
                frame_number=i + 1,
                image_url=f"https://picsum.photos/seed/halide{scanned_roll.id}{i}/200/200",
            )
            db.add(img)
        db.commit()
