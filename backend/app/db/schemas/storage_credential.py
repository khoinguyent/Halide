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

class StorageCredentialOut(BaseModel):
    id: UUID
    provider: StorageProviderEnum
    identifier: Optional[str]
    host: Optional[str]
    username: Optional[str]
    is_archive: bool

    class Config:
        orm_mode = True
