import io
import re
from sqlalchemy.orm import Session
from ..db.session import SessionLocal
from ..db.models.storage_credential import StorageCredential, StorageProviderEnum
from ..db.models.roll import Roll, RollStatusEnum
from ..db.models.image import Image
from .storage_service import storage_service
from .roll_service import get_roll, update_roll_status
from ..core.encryption import decrypt_credential
from ..db.models.user import User
import time
import random

class TransferService:
    def process_credentials(self):
        """Iterates over all storage credentials and syncs their inboxes."""
        db: Session = SessionLocal()
        try:
            credentials = db.query(StorageCredential).all()
            for cred in credentials:
                try:
                    self.sync_storage(db, cred)
                except Exception as e:
                    print(f"Error syncing credential {cred.id}: {e}")
        finally:
            db.close()

    def route_transfer(self, db: Session, user_id: str, roll_id: str, image_id: str, file_content: bytes, strategy: str):
        """Routes transfer based on strategy with exponential backoff."""
        max_retries = 3
        base_delay = 1
        
        for attempt in range(max_retries):
            try:
                if strategy == "SYSTEM_CLOUD":
                    return self._handle_system_cloud(db, user_id, roll_id, image_id, file_content)
                elif strategy == "PERSONAL_CLOUD":
                    return self._handle_personal_cloud(db, user_id, roll_id, image_id, file_content)
                else: # LOCAL
                    return self._handle_local_transfer(db, user_id, roll_id, image_id, file_content)
            except Exception as e:
                if attempt == max_retries - 1:
                    raise e
                delay = base_delay * (2 ** attempt) + random.uniform(0, 1)
                print(f"Transfer attempt {attempt + 1} failed: {e}. Retrying in {delay:.2f}s...")
                time.sleep(delay)

    def _handle_system_cloud(self, db: Session, user_id: str, roll_id: str, image_id: str, file_content: bytes):
        user = db.query(User).filter(User.id == user_id).first()
        if not user:
            raise Exception("User not found")
        
        file_size = len(file_content)
        if user.storage_used_bytes + file_size > user.storage_limit_bytes:
            raise Exception("Storage quota exceeded")
            
        s3_key = storage_service.upload_roll_image(user_id, roll_id, image_id, file_content)
        
        user.storage_used_bytes += file_size
        db.commit()
        return s3_key

    def _handle_personal_cloud(self, db: Session, user_id: str, roll_id: str, image_id: str, file_content: bytes):
        primary_cred = db.query(StorageCredential).filter(
            StorageCredential.user_id == user_id,
            StorageCredential.is_primary == True
        ).first()
        
        if not primary_cred:
            # Fallback to any archive credential if no primary exists
            primary_cred = db.query(StorageCredential).filter(
                StorageCredential.user_id == user_id,
                StorageCredential.is_archive == True
            ).first()

        if not primary_cred:
            raise Exception("No personal cloud configuration found")
            
        # Simulate upload to personal cloud
        s3_key = f"{primary_cred.provider}://{primary_cred.host or 'cloud'}/Halide Archive/{roll_id}/{image_id}.jpg"
        print(f"Uploading to personal cloud ({primary_cred.provider}): {s3_key}")
        return s3_key

    def _handle_local_transfer(self, db: Session, user_id: str, roll_id: str, image_id: str, file_content: bytes):
        # MOCK: In a real world setting, this might move to a local NAS mount point
        return f"local://nas/Halide Archive/{roll_id}/{image_id}.jpg"

    def sync_storage(self, db: Session, cred: StorageCredential):
        """Dispatches to the correct protocol handler."""
        password = decrypt_credential(cred.encrypted_auth_data)
        
        # MOCK IMPLEMENTATION: In a real system we would connect using
        # google-api-python-client, O365, smbprotocol, ftplib etc.
        # But for sprint 4 background worker testing...
        
        # Let's say we retrieved a list of files matching `Inbox/{roll_id}/image_x.jpg`
        # We will simulate finding a file if we can query pending rolls for this user
        self._mock_sync_pending_rolls(db, cred.user_id)

    def _mock_sync_pending_rolls(self, db: Session, user_id: str):
        # Find rolls for this user that are 'lab' or 'shooting'
        pending_rolls = db.query(Roll).filter(
            Roll.user_id == user_id, 
            Roll.status.in_([RollStatusEnum.lab, RollStatusEnum.shooting])
        ).all()
        
        # Check if user has a designated archive storage
        archive_cred = db.query(StorageCredential).filter(
            StorageCredential.user_id == user_id,
            StorageCredential.is_archive == True
        ).first()

        for roll in pending_rolls:
            # Simulate downloading an image and organizing it
            fake_image_content = b"fake jpeg content"
            
            # Create an Image record
            new_image = Image(
                roll_id=roll.id,
                frame_number=1,
                image_url="", # Will be updated
            )
            db.add(new_image)
            db.commit()
            db.refresh(new_image)
            
            # Determine strategy (Simplified: for now we check if they have a primary personal cloud)
            primary_cred = db.query(StorageCredential).filter(
                StorageCredential.user_id == user_id,
                StorageCredential.is_primary == True
            ).first()
            
            strategy = "PERSONAL_CLOUD" if primary_cred else "SYSTEM_CLOUD"
            
            try:
                s3_key = self.route_transfer(
                    db=db,
                    user_id=user_id,
                    roll_id=str(roll.id),
                    image_id=str(new_image.id),
                    file_content=fake_image_content,
                    strategy=strategy
                )
                
                # Update Image with the actual S3 key/url
                new_image.image_url = s3_key
                
                # Update Roll status to scanned
                roll.status = RollStatusEnum.scanned
                
                db.commit()
            except Exception as e:
                print(f"Failed to route transfer for roll {roll.id}: {e}")
                db.rollback()

transfer_service = TransferService()
