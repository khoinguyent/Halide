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
            
            if archive_cred:
                # Simulate upload to user's custom archive (e.g. NAS path)
                # In a real impl, we'd use the specific provider's client
                s3_key = f"{archive_cred.provider}://{archive_cred.host or 'cloud'}/Halide Archive/{roll.id}/{new_image.id}.jpg"
                print(f"Uploading to custom archive: {s3_key}")
            else:
                # Fallback to default S3/R2 upload
                s3_key = storage_service.upload_roll_image(
                    user_id=user_id,
                    roll_id=str(roll.id),
                    image_id=str(new_image.id),
                    file_content=fake_image_content
                )
            
            # Update Image with the actual S3 key/url
            new_image.image_url = s3_key
            
            # Update Roll status to scanned
            roll.status = RollStatusEnum.scanned
            
            db.commit()

transfer_service = TransferService()
