import sys
import os
from pathlib import Path

# Add backend to sys.path
backend_path = Path(__file__).resolve().parent.parent
sys.path.append(str(backend_path))

from app.db.session import SessionLocal
from app.db.models.image import Image
from app.db.models.roll import Roll
from app.db.models.user import User
from app.core.config import settings

def run_migration():
    if not settings.R2_PUBLIC_BASE_URL:
        print("Error: R2_PUBLIC_BASE_URL not configured. Cannot generate URLs.")
        return

    db = SessionLocal()
    base_url = settings.R2_PUBLIC_BASE_URL.rstrip("/")
    
    try:
        # Focus on roll 66dade53-7330-449e-a429-6ae1efe1c727 first
        roll_id = "66dade53-7330-449e-a429-6ae1efe1c727"
        images = db.query(Image).filter(Image.roll_id == roll_id).all()
        
        print(f"Migrating {len(images)} images for roll {roll_id}...")
        
        updated_count = 0
        for img in images:
            # Current URL might be None or gdrive://...
            # We assume for this roll, if it was successful, the R2 key exists.
            # The key format is users/{user_id}/rolls/{roll_id}/{image_id}.jpg
            # For GDrive sync, image_id was the Drive file ID.
            
            current_url = img.image_url
            if current_url is None or current_url.startswith("gdrive://"):
                # Extract image ID from GDrive URL if possible
                # e.g. gdrive://cloud/Halide Archive/66dade53.../ID.jpg
                if current_url and "/" in current_url:
                    image_id = current_url.split("/")[-1].replace(".jpg", "")
                else:
                    # If URL was None, we might need to find the image ID from elsewhere?
                    # Wait, if frame_number 0-4 were NULL, we don't have the image_id!
                    # BUT, the user said images ARE on R2.
                    # Let's check if we can find the image ID from the frame number or if we need to skip.
                    print(f"Skipping image {img.id} as it has no URL and we cannot derive the R2 key.")
                    continue
                
                roll = db.query(Roll).filter(Roll.id == roll_id).first()
                if not roll: continue
                
                new_key = f"users/{roll.user_id}/rolls/{roll_id}/{image_id}.jpg"
                img.image_url = f"{base_url}/{new_key}"
                updated_count += 1
        
        db.commit()
        print(f"Successfully updated {updated_count} records for roll {roll_id}.")

        # Optional: scan all Pro users for gdrive:// URLs and fix them
        # (Only if we can derive the key)
        pass

    except Exception as e:
        print(f"Error during migration: {e}")
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    run_migration()
