from pydantic import BaseModel
from typing import Optional
from uuid import UUID
from ..models.storage_credential import StorageProviderEnum

class StorageCredentialCreate(BaseModel):
    provider: StorageProviderEnum
    identifier: Optional[str] = None
    host: Optional[str] = None
    username: Optional[str] = None
    auth_data: str
    is_archive: bool = False
    is_scan_sync: bool = True
    display_label: Optional[str] = None
    is_primary: bool = False

class StorageCredentialOut(BaseModel):
    id: UUID
    provider: StorageProviderEnum
    identifier: Optional[str]
    host: Optional[str]
    username: Optional[str]
    is_archive: bool
    is_scan_sync: bool
    display_label: Optional[str]
    is_primary: bool
    storage_used: Optional[int] = None
    storage_limit: Optional[int] = None

    model_config = {"from_attributes": True}
