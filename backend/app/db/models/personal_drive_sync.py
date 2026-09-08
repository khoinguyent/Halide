"""
Persisted state for syncing rolls/images to a user's personal cloud (e.g. Google Drive
"Agxel Vault"). Three concerns, three tables:

- PersonalDriveSyncJob: one row per batch/queue request (one or many rolls). Lets the API
  return immediately and the app poll progress; also the unit of work workers claim.
- PersonalDriveRollSync: durable "is this roll already archived, and where" state per roll.
  Lets us skip re-scanning a roll's images entirely when nothing changed.
- PersonalDriveImageSync: durable per-image upload state (content hash + remote file id).
  Lets us skip re-uploading a frame that hasn't changed, and know which frames failed.
"""
import enum

from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    Enum,
    ForeignKey,
    Integer,
    String,
    Text,
    UniqueConstraint,
    text,
)
from sqlalchemy.dialects.postgresql import JSONB, UUID

from ..base import Base


class PersonalDriveSyncJobStatus(str, enum.Enum):
    queued = "queued"
    running = "running"
    succeeded = "succeeded"
    failed = "failed"
    partial = "partial"


class PersonalDriveSyncStatus(str, enum.Enum):
    pending = "pending"
    syncing = "syncing"
    synced = "synced"
    failed = "failed"


class PersonalDriveSyncJob(Base):
    """One queued unit of work: sync N rolls (or 'all eligible rolls') for a user."""

    __tablename__ = "personal_drive_sync_jobs"

    id = Column(UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    user_id = Column(String(255), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)

    # Null/empty => "all eligible rolls for this user" resolved at claim time.
    roll_ids = Column(JSONB, nullable=True)
    # Re-upload frames/README even if their content hash already matches Drive.
    force = Column(Boolean, nullable=False, server_default=text("FALSE"))

    status = Column(
        Enum(PersonalDriveSyncJobStatus, name="personal_drive_sync_job_status"),
        nullable=False,
        server_default=PersonalDriveSyncJobStatus.queued.value,
    )

    total_rolls = Column(Integer, nullable=False, server_default=text("0"))
    completed_rolls = Column(Integer, nullable=False, server_default=text("0"))
    failed_rolls = Column(Integer, nullable=False, server_default=text("0"))
    skipped_rolls = Column(Integer, nullable=False, server_default=text("0"))

    # Per-roll result summaries once processed, e.g. [{"roll_id": .., "uploaded": 3, ...}]
    result = Column(JSONB, nullable=True)
    error = Column(Text, nullable=True)

    created_at = Column(DateTime, server_default=text("NOW()"))
    started_at = Column(DateTime, nullable=True)
    finished_at = Column(DateTime, nullable=True)


class PersonalDriveRollSync(Base):
    """Durable per-roll archive state so unchanged rolls are skipped on subsequent passes."""

    __tablename__ = "personal_drive_roll_syncs"

    id = Column(UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    roll_id = Column(UUID(as_uuid=True), ForeignKey("rolls.id", ondelete="CASCADE"), nullable=False, unique=True)
    storage_credential_id = Column(
        UUID(as_uuid=True), ForeignKey("storage_credentials.id", ondelete="SET NULL"), nullable=True
    )

    drive_folder_id = Column(String(255), nullable=True)
    readme_hash = Column(String(64), nullable=True)

    status = Column(
        Enum(PersonalDriveSyncStatus, name="personal_drive_sync_status"),
        nullable=False,
        server_default=PersonalDriveSyncStatus.pending.value,
    )

    images_total = Column(Integer, nullable=False, server_default=text("0"))
    images_uploaded = Column(Integer, nullable=False, server_default=text("0"))

    last_synced_at = Column(DateTime, nullable=True)
    last_error = Column(Text, nullable=True)

    created_at = Column(DateTime, server_default=text("NOW()"))
    updated_at = Column(DateTime, server_default=text("NOW()"), onupdate=text("NOW()"))


class PersonalDriveImageSync(Base):
    """Durable per-image upload state; content_hash lets us skip byte-identical re-uploads."""

    __tablename__ = "personal_drive_image_syncs"

    id = Column(UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    image_id = Column(UUID(as_uuid=True), ForeignKey("images.id", ondelete="CASCADE"), nullable=False, unique=True)
    roll_sync_id = Column(
        UUID(as_uuid=True), ForeignKey("personal_drive_roll_syncs.id", ondelete="CASCADE"), nullable=False
    )

    drive_file_id = Column(String(255), nullable=True)
    content_hash = Column(String(64), nullable=True)

    status = Column(
        Enum(PersonalDriveSyncStatus, name="personal_drive_image_sync_status"),
        nullable=False,
        server_default=PersonalDriveSyncStatus.pending.value,
    )

    synced_at = Column(DateTime, nullable=True)
    last_error = Column(Text, nullable=True)

    created_at = Column(DateTime, server_default=text("NOW()"))
    updated_at = Column(DateTime, server_default=text("NOW()"), onupdate=text("NOW()"))

    __table_args__ = (
        UniqueConstraint("image_id", name="uq_personal_drive_image_syncs_image_id"),
    )
