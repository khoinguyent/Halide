import io
import re
from sqlalchemy.orm import Session
from ..db.session import SessionLocal
from ..db.models.user import User
from ..db.models.storage_credential import StorageCredential, StorageProviderEnum
from ..db.models.roll import Roll, RollStatusEnum
from ..db.models.image import Image
from .storage_service import storage_service
from .roll_service import get_roll, update_roll_status
from ..core.encryption import decrypt_credential
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
        """Routes transfer based on strategy with exponential backoff.
        For PRO users, also auto-uploads to SYSTEM_CLOUD as a backup."""
        max_retries = 3
        base_delay = 1
        
        user = db.query(User).filter(User.id == user_id).first()
        is_pro = user and user.subscription_tier == "pro"
        
        results = []
        for attempt in range(max_retries):
            try:
                # If user is PRO, we ALWAYS try to upload to SYSTEM_CLOUD first (or as well)
                # according to req: "Synced images ... will auto upload to cloud storage"
                system_key = None
                if is_pro and strategy != "SYSTEM_CLOUD":
                    try:
                        system_key = self._handle_system_cloud(db, user_id, roll_id, image_id, file_content)
                    except Exception as e:
                        print(f"Auto-upload to system cloud failed for pro user: {e}")

                main_key = None
                if strategy == "SYSTEM_CLOUD":
                    main_key = self._handle_system_cloud(db, user_id, roll_id, image_id, file_content)
                elif strategy == "PERSONAL_CLOUD":
                    main_key = self._handle_personal_cloud(db, user_id, roll_id, image_id, file_content)
                else: # LOCAL
                    main_key = self._handle_local_transfer(db, user_id, roll_id, image_id, file_content)
                
                # For Pro users, we prefer the system (R2) URL over personal cloud.
                # Use a case-insensitive check for 'gdrive://' anywhere in the primary key.
                if is_pro and system_key and main_key and "gdrive://" in main_key.lower():
                    return system_key

                return main_key or system_key
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
        if user.storage_used_bytes + file_size > user.total_storage_limit:
            raise Exception("Storage quota exceeded")
            
        s3_key = storage_service.upload_roll_image(user_id, roll_id, image_id, file_content)
        
        user.storage_used_bytes += file_size
        db.commit()

        # Store object keys (users/...) in Image.image_url. Public URLs are built in roll_service
        # Public gallery URLs are built in roll_service: R2_PUBLIC_BASE_URL + object key (no /bucket/ in path).
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
        
        # self._mock_sync_pending_rolls(db, cred.user_id) # REMOVED: Prematurely updates status to SCANNED
        pass

transfer_service = TransferService()
