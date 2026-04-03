import os
import sys

# Add the app directory to sys.path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from app.db.session import SessionLocal
from app.db.models.image import Image
from app.core.config import settings

def migrate_urls():
    db = SessionLocal()
    try:
        roll_id = "66dade53-7330-449e-a429-6ae1efe1c727"
        images = db.query(Image).filter(Image.roll_id == roll_id).all()
        
        base_url = settings.R2_PUBLIC_BASE_URL.rstrip("/")
        bucket = settings.S3_BUCKET_NAME.strip()
        correct_base = f"{base_url}/{bucket}"
        
        updated_count = 0
        for img in images:
            if img.image_url and img.image_url.startswith(base_url) and not img.image_url.startswith(correct_base):
                # Replace the base_url with correct_base
                new_url = img.image_url.replace(base_url, correct_base, 1)
                img.image_url = new_url
                updated_count += 1
        
        db.commit()
        print(f"Updated {updated_count} image URLs for roll {roll_id}")
    finally:
        db.close()

if __name__ == "__main__":
    migrate_urls()
