import sys
import os
import random
from unittest.mock import MagicMock, patch
import uuid
import boto3
from sqlalchemy.orm import Session
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

# Add backend/app to path
sys.path.append(os.path.join(os.getcwd(), 'backend'))

from app.db.session import SessionLocal
from app.db.models.user import User
from app.db.models.storage_credential import StorageCredential, StorageProviderEnum
from app.db.models.roll import Roll, RollStatusEnum
from app.db.models.image import Image
from app.services.transfer_service import transfer_service
from app.services.storage_service import storage_service
from app.core.config import settings

def setup_test_data(db: Session):
    # Create a test user
    test_user_id = str(uuid.uuid4())
    test_user = User(
        id=test_user_id,
        email=f"test_{test_user_id[:8]}@example.com",
        display_name="Test User",
        subscription_tier="free",
        storage_used_bytes=0,
        storage_limit_bytes=1000 # 1000 bytes for easy testing
    )
    db.add(test_user)
    db.commit()
    return test_user

def test_multi_primary_constraint(db: Session, user_id: str):
    print("Testing multi-primary constraint...")
    cred1 = StorageCredential(
        user_id=user_id,
        provider=StorageProviderEnum.gdrive,
        encrypted_auth_data="fake_data",
        is_primary=True,
        display_label="Primary Google"
    )
    db.add(cred1)
    db.commit()
    print("  - First primary added.")

    cred2 = StorageCredential(
        user_id=user_id,
        provider=StorageProviderEnum.onedrive,
        encrypted_auth_data="fake_data",
        is_primary=True,
        display_label="Second Primary (Should fail)"
    )
    db.add(cred2)
    try:
        db.commit()
        print("  - ERROR: Added second primary successfully (Index failed!)")
    except Exception as e:
        db.rollback()
        print(f"  - SUCCESS: Failed to add second primary as expected: {e}")

def test_routing_and_quota(db: Session, user_id: str):
    print("\nTesting routing and quota tracking...")
    
    # Create a roll
    roll = Roll(
        user_id=user_id,
        status=RollStatusEnum.lab
    )
    db.add(roll)
    db.commit()
    db.refresh(roll)

    # 1. Test System Cloud (Default when no primary personal cloud)
    print("  - Testing SYSTEM_CLOUD...")
    fake_content = b"fake content" * 10 # 120 bytes
    
    try:
        s3_key = transfer_service.route_transfer(
            db=db,
            user_id=user_id,
            roll_id=str(roll.id),
            image_id="img1",
            file_content=fake_content,
            strategy="SYSTEM_CLOUD"
        )
        print(f"    - Uploaded to system cloud: {s3_key}")
        
        db.refresh(db.query(User).get(user_id))
        user = db.query(User).get(user_id)
        print(f"    - Storage used: {user.storage_used_bytes} bytes")
        
        if user.storage_used_bytes == len(fake_content):
            print("    - SUCCESS: Quota tracked correctly.")
        else:
            print(f"    - FAILURE: Quota mismatch. Expected {len(fake_content)}, got {user.storage_used_bytes}")
            
    except Exception as e:
        print(f"    - FAILURE: System cloud transfer failed: {e}")

    # 2. Test Quota Exceeded
    print("  - Testing Quota Exceeded...")
    large_content = b"x" * 2000 # Larger than 1000 limit
    try:
        transfer_service.route_transfer(
            db=db,
            user_id=user_id,
            roll_id=str(roll.id),
            image_id="img2",
            file_content=large_content,
            strategy="SYSTEM_CLOUD"
        )
        print("    - FAILURE: Uploaded successfully despite exceeding quota!")
    except Exception as e:
        print(f"    - SUCCESS: Quota check failed as expected: {e}")

    # 3. Test Personal Cloud Routing
    print("  - Testing PERSONAL_CLOUD...")
    # Add a primary personal cloud
    db.query(StorageCredential).filter(StorageCredential.user_id == user_id).delete()
    db.commit()
    
    primary_cred = StorageCredential(
        user_id=user_id,
        provider=StorageProviderEnum.ftp,
        host="nas.local",
        encrypted_auth_data="fake_data",
        is_primary=True,
        display_label="My Home NAS"
    )
    db.add(primary_cred)
    db.commit()
    
    try:
        s3_key = transfer_service.route_transfer(
            db=db,
            user_id=user_id,
            roll_id=str(roll.id),
            image_id="img3",
            file_content=fake_content,
            strategy="PERSONAL_CLOUD"
        )
        print(f"    - Uploaded to personal cloud: {s3_key}")
        if "ftp://nas.local" in s3_key:
            print("    - SUCCESS: Routed to personal cloud correctly.")
        else:
            print(f"    - FAILURE: Routing incorrect. Key: {s3_key}")
    except Exception as e:
        print(f"    - FAILURE: Personal cloud transfer failed: {e}")

def main():
    db = SessionLocal()
    try:
        user = setup_test_data(db)
        test_multi_primary_constraint(db, user.id)
        test_routing_and_quota(db, user.id)
    finally:
        db.close()

if __name__ == "__main__":
    # Mock storage_service.s3 directly
    storage_service.s3 = MagicMock()
    main()
