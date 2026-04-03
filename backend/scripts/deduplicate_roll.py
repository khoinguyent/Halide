import os
import sys

# Add the app directory to sys.path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from app.db.session import SessionLocal
from app.db.models.image import Image
from sqlalchemy import func

def deduplicate_roll(roll_id: str):
    db = SessionLocal()
    try:
        # Find all frame numbers for this roll
        frames = db.query(Image.frame_number).filter(Image.roll_id == roll_id).distinct().all()
        frames = [f[0] for f in frames if f[0] is not None]
        
        for f_num in frames:
            # Get all images for this frame
            images = db.query(Image).filter(Image.roll_id == roll_id, Image.frame_number == f_num).order_by(Image.created_at.asc()).all()
            if len(images) > 1:
                print(f"Frame {f_num} has {len(images)} records. Merging...")
                
                # Keep the one with EXIF data if possible, or the first one
                primary = images[0]
                # Check if any other has image_url while primary doesn't
                for other in images[1:]:
                    if not primary.image_url and other.image_url:
                        primary.image_url = other.image_url
                    if primary.aperture is None and other.aperture is not None:
                        primary.aperture = other.aperture
                        primary.shutter_speed = other.shutter_speed
                        primary.location_lat = other.location_lat
                        primary.location_lng = other.location_lng
                    
                    # Delete the duplicate
                    db.delete(other)
        
        db.commit()
        print(f"Deduplication complete for roll {roll_id}")
    finally:
        db.close()

if __name__ == "__main__":
    roll_id = "9f5d66bb-6f54-4743-b774-873c14b6e4b9"
    deduplicate_roll(roll_id)
