import os
from sqlalchemy.orm import Session
from database import SessionLocal, engine
import models
from uuid import uuid4

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

        # Seed Cameras
        cameras = [
            {
                "brand": "Leica",
                "model": "M6",
                "camera_type": models.CameraTypeEnum.rangefinder,
                "description": "The quintessential mechanical rangefinder camera."
            },
            {
                "brand": "Canon",
                "model": "AE-1",
                "camera_type": models.CameraTypeEnum.slr,
                "description": "The classic starter SLR of the 70s/80s."
            },
            {
                "brand": "Pentax",
                "model": "67",
                "camera_type": models.CameraTypeEnum.slr,
                "description": "The legendary medium format SLR."
            }
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
                print(f"Camera exists skipping: {cam['brand']} {cam['model']}")
        
        db.commit()
    finally:
        db.close()

if __name__ == "__main__":
    print("Seeding Halide database...")
    seed_master_data()
    print("Seeding complete.")
