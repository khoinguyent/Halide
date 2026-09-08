import json
import time
import random
from sqlalchemy.orm import Session
from ..db.session import SessionLocal
from ..db.models.user import User
from ..db.models.storage_credential import StorageCredential, StorageProviderEnum
from ..db.models.image import Image
from ..db.models.personal_drive_sync import PersonalDriveSyncJob, PersonalDriveSyncJobStatus
from .storage_service import storage_service
from .personal_drive_sync_service import upload_image_bytes_to_roll_folder
from .personal_drive_sync_queue import enqueue_personal_drive_sync_job
from ..core.encryption import decrypt_credential

class TransferService:
    def process_credentials(self):
        """
        Queue outbound Agxel Vault sync for every user with an archive-capable Google
        Drive connection. Enqueues one "sync everything that changed" job per user
        (roll/frame-level idempotency is handled when the job runs, see
        ``personal_drive_sync_service.roll_needs_personal_drive_sync``); actual
        processing happens on the async queue (``transfer_worker`` drains it).
        """
        db: Session = SessionLocal()
        try:
            seen_users = set()
            credentials = (
                db.query(StorageCredential)
                .filter(StorageCredential.provider == StorageProviderEnum.gdrive)
                .filter(
                    (StorageCredential.is_primary == True)  # noqa: E712
                    | (StorageCredential.is_archive == True)  # noqa: E712
                )
                .all()
            )
            for cred in credentials:
                if cred.user_id in seen_users:
                    continue
                seen_users.add(cred.user_id)
                try:
                    self.sync_storage(db, cred)
                except Exception as e:
                    print(f"Error queuing personal Drive sync for credential {cred.id}: {e}")
        finally:
            db.close()

    def route_transfer(self, db: Session, user_id: str, roll_id: str, image_id: str, file_content: bytes, strategy: str):
        """Routes transfer based on strategy with exponential backoff.
        For PRO users, also auto-uploads to SYSTEM_CLOUD as a backup."""
        max_retries = 3
        base_delay = 1
        
        user = db.query(User).filter(User.id == user_id).first()
        is_pro = user and user.subscription_tier == "pro"
        
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
                
                # Prefer system (R2) URL for gallery when personal path returns a Drive stub.
                # Pro dual-write keeps R2 as the display source of truth.
                if is_pro and system_key and main_key and str(main_key).lower().startswith("gdrive://"):
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
            StorageCredential.is_primary == True  # noqa: E712
        ).first()
        
        if not primary_cred:
            primary_cred = db.query(StorageCredential).filter(
                StorageCredential.user_id == user_id,
                StorageCredential.is_archive == True  # noqa: E712
            ).first()

        if not primary_cred:
            raise Exception("No personal cloud configuration found")

        provider = primary_cred.provider
        if provider == StorageProviderEnum.gdrive or str(provider) == "gdrive":
            # Resolve frame number when the Image row already exists (re-uploads).
            frame_number = None
            existing = db.query(Image).filter(Image.id == image_id).first()
            if existing is not None:
                frame_number = existing.frame_number
            return upload_image_bytes_to_roll_folder(
                db,
                user_id=user_id,
                roll_id=roll_id,
                image_id=image_id,
                file_content=file_content,
                frame_number=frame_number,
            )

        # Non-Drive providers (NAS / FTP / …) — not implemented yet.
        s3_key = f"{primary_cred.provider}://{primary_cred.host or 'cloud'}/Agxel Vault/{roll_id}/{image_id}.jpg"
        print(f"Uploading to personal cloud ({primary_cred.provider}): {s3_key} [stub]")
        return s3_key

    def _handle_local_transfer(self, db: Session, user_id: str, roll_id: str, image_id: str, file_content: bytes):
        return f"local://nas/Agxel Vault/{roll_id}/{image_id}.jpg"

    def sync_storage(self, db: Session, cred: StorageCredential):
        """
        Enqueue an outbound archive job for this Google Drive personal-cloud credential
        (does not run the sync inline — the async queue processes it, see
        ``personal_drive_sync_queue`` and ``tasks/transfer_worker.py``).
        """
        if cred.provider != StorageProviderEnum.gdrive and str(cred.provider) != "gdrive":
            return
        # Validate we can decrypt tokens before queuing a full user sync.
        password = decrypt_credential(cred.encrypted_auth_data)
        if not password:
            raise RuntimeError(f"Could not decrypt credential {cred.id}")
        try:
            json.loads(password)
        except Exception:
            raise RuntimeError(f"Invalid credential payload for {cred.id}")

        # Avoid piling up duplicate jobs for the same user while one is still queued/running.
        has_pending_job = (
            db.query(PersonalDriveSyncJob)
            .filter(
                PersonalDriveSyncJob.user_id == cred.user_id,
                PersonalDriveSyncJob.status.in_(
                    [PersonalDriveSyncJobStatus.queued, PersonalDriveSyncJobStatus.running]
                ),
            )
            .first()
        )
        if has_pending_job:
            return

        job = enqueue_personal_drive_sync_job(db, user_id=cred.user_id, roll_ids=None)
        print(f"Queued personal Drive sync job {job.id} for user {cred.user_id}")


transfer_service = TransferService()
