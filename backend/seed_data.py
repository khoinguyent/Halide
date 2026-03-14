import os
from sqlalchemy.orm import Session
from app.db.session import SessionLocal, engine
from app.db import models
from uuid import uuid4
import datetime

# Default gear image URLs by (brand, model) for user_cameras when master camera has none
GEAR_IMAGE_URLS = {
    ("Leica", "M6"): ["https://images.unsplash.com/photo-1516035069371-29a1b244cc32", "https://images.unsplash.com/photo-1606983340126-99ab4feaa64a"],
    ("Canon", "AE-1"): ["https://images.unsplash.com/photo-1606983340126-99ab4feaa64a", "https://images.unsplash.com/photo-1492691527719-9d1e07e534b4"],
    ("Pentax", "67"): ["https://images.unsplash.com/photo-1492691527719-9d1e07e534b4", "https://images.unsplash.com/photo-1516035069371-29a1b244cc32"],
    ("Hasselblad", "500C/M"): ["https://images.unsplash.com/photo-1585155770148-7d436f2e2c0a", "https://images.unsplash.com/photo-1606983340126-99ab4feaa64a"],
}

def _backfill_user_camera_gear_urls(db: Session):
    """Set image_urls and primary_image_index on user_cameras that have none, using linked camera or defaults."""
    from sqlalchemy.orm import joinedload
    rows = db.query(models.UserCamera).options(joinedload(models.UserCamera.camera)).all()
    updated = 0
    for uc in rows:
        if uc.image_urls is not None and len(uc.image_urls) > 0:
            continue
        urls = None
        if uc.camera:
            urls = uc.camera.image_urls
            if not urls:
                key = (uc.camera.brand, uc.camera.model)
                urls = GEAR_IMAGE_URLS.get(key)
        if not urls:
            urls = ["https://images.unsplash.com/photo-1516035069371-29a1b244cc32"]
        uc.image_urls = urls
        uc.primary_image_index = 0
        updated += 1
    if updated:
        db.commit()
        print(f"Backfilled image_urls for {updated} user_cameras")

def seed_master_data():
    models.Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        # Seed Film Stocks
        film_stocks = [
            {
                "brand": "Kodak",
                "name": "Portra 400",
                "iso": 400,
                "format": models.FormatEnum.format_135,
                "color_type": models.ColorTypeEnum.color_negative,
                "description": "Professional high-speed daylight-balanced color negative film offering a smooth and natural color palette that is balanced with vivid saturation and low contrast for accurate skin tones and consistent results."
            },
            {
                "brand": "Fujifilm",
                "name": "Superia Premium 400",
                "iso": 400,
                "format": models.FormatEnum.format_135,
                "color_type": models.ColorTypeEnum.color_negative,
                "description": "A daylight-balanced color negative film featuring a neutral color balance and natural skin tones, well-suited for a wide range of shooting conditions."
            },
            {
                "brand": "Ilford",
                "name": "HP5 Plus",
                "iso": 400,
                "format": models.FormatEnum.format_135,
                "color_type": models.ColorTypeEnum.b_w,
                "description": "A high-speed, fine-grain, black-and-white film. It has a slightly lower contrast than Tri-X, and maintains its exposure latitude well."
            }
        ]

        for fs in film_stocks:
            db_fs = db.query(models.FilmStock).filter(
                models.FilmStock.brand == fs["brand"],
                models.FilmStock.name == fs["name"],
                models.FilmStock.format == fs["format"]
            ).first()
            if not db_fs:
                db.add(models.FilmStock(**fs))
                print(f"Adding FilmStock: {fs['brand']} {fs['name']}")
            else:
                print(f"FilmStock exists skipping: {fs['brand']} {fs['name']}")

        # Seed Cameras (with seed images for locker UI)
        cameras = [
            {
                "brand": "Leica",
                "model": "M6",
                "camera_type": models.CameraTypeEnum.rangefinder,
                "description": "The quintessential mechanical rangefinder camera.",
                "image_urls": ["https://images.unsplash.com/photo-1516035069371-29a1b244cc32"],
            },
            {
                "brand": "Canon",
                "model": "AE-1",
                "camera_type": models.CameraTypeEnum.slr,
                "description": "The classic starter SLR of the 70s/80s.",
                "image_urls": ["https://images.unsplash.com/photo-1606983340126-99ab4feaa64a"],
            },
            {
                "brand": "Pentax",
                "model": "67",
                "camera_type": models.CameraTypeEnum.slr,
                "description": "The legendary medium format SLR.",
                "image_urls": ["https://images.unsplash.com/photo-1492691527719-9d1e07e534b4"],
            },
        ]

        for cam in cameras:
            db_cam = db.query(models.Camera).filter(
                models.Camera.brand == cam["brand"],
                models.Camera.model == cam["model"]
            ).first()
            if not db_cam:
                db.add(models.Camera(**cam))
                print(f"Adding Camera: {cam['brand']} {cam['model']}")
            else:
                if not db_cam.image_urls:
                    db_cam.image_urls = cam.get("image_urls")
                print(f"Camera exists skipping: {cam['brand']} {cam['model']}")
        
        db.commit()

        # Seed Test User and Data
        test_user_id = "test_user_123"
        test_user = db.query(models.User).filter(models.User.id == test_user_id).first()
        if not test_user:
            test_user = models.User(
                id=test_user_id,
                email="test@example.com",
                display_name="Test User",
                avatar_url="https://example.com/avatar.jpg"
            )
            db.add(test_user)
            print(f"Adding Test User: {test_user_id}")
            db.commit()
            db.refresh(test_user)
        
        # Link a camera to the test user
        leica_m6 = db.query(models.Camera).filter(models.Camera.model == "M6").first()
        if leica_m6:
            user_cam = db.query(models.UserCamera).filter(
                models.UserCamera.user_id == test_user_id,
                models.UserCamera.camera_id == leica_m6.id
            ).first()
            if not user_cam:
                user_cam = models.UserCamera(
                    user_id=test_user_id,
                    camera_id=leica_m6.id,
                    gear_nickname="Main Shooter",
                    rating_functional=9,
                    rating_view=8,
                    rating_looking=10,
                    image_urls=leica_m6.image_urls or ["https://images.unsplash.com/photo-1516035069371-29a1b244cc32"],
                    primary_image_index=0,
                )
                db.add(user_cam)
                print(f"Linking Leica M6 to Test User")
                db.commit()
                db.refresh(user_cam)
            elif user_cam.image_urls is None or user_cam.image_urls == []:
                user_cam.image_urls = leica_m6.image_urls or ["https://images.unsplash.com/photo-1516035069371-29a1b244cc32"]
                user_cam.primary_image_index = 0
                db.commit()
                print(f"Backfilled image_urls for Test User Leica M6")

        # Backfill image_urls and primary_image_index for all user_cameras that lack them
        _backfill_user_camera_gear_urls(db)

        # Add some test rolls (requires leica_m6 / user_cam from above)
        if leica_m6:
            user_cam = db.query(models.UserCamera).filter(
                models.UserCamera.user_id == test_user_id,
                models.UserCamera.camera_id == leica_m6.id
            ).first()
            if user_cam:
                portra = db.query(models.FilmStock).filter(models.FilmStock.name == "Portra 400").first()
                if portra:
                    for i in range(5):
                        roll = models.Roll(
                            user_id=test_user_id,
                            film_stock_id=portra.id,
                            user_camera_id=user_cam.id,
                            shot_at_iso=400,
                            status=models.RollStatusEnum.shooting
                        )
                        db.add(roll)
                    print(f"Added 5 Portra 400 rolls to Test User")
                    db.commit()

    finally:
        db.close()

if __name__ == "__main__":
    print("Seeding Halide database...")
    seed_master_data()
    print("Seeding complete.")
