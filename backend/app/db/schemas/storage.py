from pydantic import BaseModel
from typing import Optional

class StorageProviderMetadata(BaseModel):
    id: str
    name: str
    icon: str
    auth_type: str
    description: Optional[str] = None
