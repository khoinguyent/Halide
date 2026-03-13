import sys
import os

# Set mock environment variables for initialization
os.environ.setdefault("FIREBASE_PROJECT_ID", "test-project")
os.environ.setdefault("S3_ENDPOINT", "http://localhost:9000")
os.environ.setdefault("S3_ACCESS_KEY", "test_key")
os.environ.setdefault("S3_SECRET_KEY", "test_secret")
os.environ.setdefault("S3_BUCKET_NAME", "test_bucket")
os.environ.setdefault("SECRET_KEY", "test_secret")

from sqlalchemy.orm import Session
from app.db.session import SessionLocal, engine
from app.db.base import Base
from app.services.seed_service import SeedService

def run_seed(user_id: str = "test_user_123"):
    print(f"Starting seed process for user: {user_id}...")
    
    # Create tables if they don't exist
    Base.metadata.create_all(bind=engine)
    
    db = SessionLocal()
    try:
        service = SeedService()
        print("Seeding master data...")
        service.seed_master_data(db)
        print("Master data seeded.")
        
        print(f"Populating developer data for user {user_id}...")
        service.populate_dev_data(db, user_id)
        print("Developer data populated.")
        
    except Exception as e:
        print(f"Error during seeding: {e}")
        db.rollback()
        raise e
    finally:
        db.close()
    
    print("Seed complete successfully.")

if __name__ == "__main__":
    uid = sys.argv[1] if len(sys.argv) > 1 else "test_user_123"
    run_seed(uid)
