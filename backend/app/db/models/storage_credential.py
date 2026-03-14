import enum
from sqlalchemy import Column, Integer, String, Enum, ForeignKey, DateTime, text, Boolean, Index, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID, JSONB
from ..base import Base

class StorageProviderEnum(str, enum.Enum):
    gdrive = 'gdrive'
    onedrive = 'onedrive'
    ftp = 'ftp'
    smb = 'smb'

class StorageCredential(Base):
    __tablename__ = "storage_credentials"
    id = Column(UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    user_id = Column(String(255), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    provider = Column(Enum(StorageProviderEnum), nullable=False)
    
    # Store arbitrary host info or identifier (e.g. user email for OAuth, or host IP for NAS)
    identifier = Column(String(255)) 
    
    # NAS info
    host = Column(String(255), nullable=True)
    username = Column(String(255), nullable=True)
    
    # Used for OAuth (Google/OneDrive) or NAS (password). Encrypted at rest.
    encrypted_auth_data = Column(String, nullable=False)
    
    display_label = Column(String(255), nullable=True)
    is_primary = Column(Boolean, default=False, server_default=text('FALSE'))
    
    # Flag to designate this storage as the archive destination
    is_archive = Column(Boolean, default=False, server_default=text('FALSE'))
    
    created_at = Column(DateTime, server_default=text('NOW()'))
    updated_at = Column(DateTime, server_default=text('NOW()'), onupdate=text('NOW()'))

    __table_args__ = (
        Index(
            "ix_storage_credentials_primary_user",
            "user_id",
            "is_primary",
            unique=True,
            postgresql_where=text("is_primary = True")
        ),
    )
