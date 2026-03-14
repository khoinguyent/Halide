from pydantic_settings import BaseSettings, SettingsConfigDict
from typing import Optional

class Settings(BaseSettings):
    # Database
    DATABASE_URL: str = "postgresql://user:password@localhost:5433/halide"

    # Firebase
    FIREBASE_PROJECT_ID: str
    FIREBASE_SERVICE_ACCOUNT_JSON: Optional[str] = None
    # Local dev only: skip Firebase Admin verify_id_token when no credentials (e.g. no service account).
    # Set to "true" or "1" to decode JWT payload without verification. Insecure; never use in production.
    DEV_SKIP_FIREBASE_VERIFY: bool = False

    # Cloud Storage (R2/S3)
    S3_ENDPOINT: str
    S3_ACCESS_KEY: str
    S3_SECRET_KEY: str
    S3_BUCKET_NAME: str
    S3_REGION: str = "auto"

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

settings = Settings()
