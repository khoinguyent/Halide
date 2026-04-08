from pathlib import Path
from pydantic_settings import BaseSettings, SettingsConfigDict
from typing import Optional

import os
# Resolve .env relative to backend/ so it loads regardless of cwd
_BACKEND_DIR = Path(__file__).resolve().parent.parent.parent
_ENV_FILE = os.getenv("ENV_FILE", str(_BACKEND_DIR / ".env"))

class Settings(BaseSettings):
    # Database
    DATABASE_URL: str = "postgresql://user:password@localhost:5433/halide"

    # Firebase
    FIREBASE_PROJECT_ID: str
    FIREBASE_SERVICE_ACCOUNT_JSON: Optional[str] = None
    # Local dev only: skip Firebase Admin verify_id_token when no credentials (e.g. no service account).
    # Set to "true" or "1" to decode JWT payload without verification. Insecure; never use in production.
    DEV_SKIP_FIREBASE_VERIFY: bool = False

    # Google Drive OAuth (for personal cloud storage)
    GOOGLE_CLIENT_ID: Optional[str] = None
    GOOGLE_CLIENT_SECRET: Optional[str] = None

    # Cloud Storage (R2/S3)
    # S3 API origin only, e.g. https://<account_id>.r2.cloudflarestorage.com — do NOT append /bucket here;
    # use S3_BUCKET_NAME separately (appending /halide here duplicates the bucket in presigned URLs).
    S3_ENDPOINT: str
    # If set, Plus/Pro gallery URLs use this public origin + object key (users/.../file.jpg).
    # Some setups need a path prefix equal to the bucket name, e.g.
    #   https://pub-xxx.r2.dev/halide/users/...
    # Either set R2_PUBLIC_BASE_URL=https://pub-xxx.r2.dev/halide  OR
    # set R2_PUBLIC_BASE_URL=https://pub-xxx.r2.dev and R2_PUBLIC_APPEND_BUCKET_PATH=true.
    # Do not use both /halide in the URL and the flag, or you get /halide/halide/...
    R2_PUBLIC_BASE_URL: Optional[str] = None
    R2_PUBLIC_APPEND_BUCKET_PATH: bool = False
    S3_ACCESS_KEY: str
    S3_SECRET_KEY: str
    S3_BUCKET_NAME: str
    S3_REGION: str = "auto"

    # Email (Gmail SMTP via App Password)
    EMAIL_HOST: str = "smtp.gmail.com"
    EMAIL_PORT: int = 587
    EMAIL_USER: Optional[str] = None          # halide.app.notify@gmail.com
    EMAIL_APP_PASSWORD: Optional[str] = None  # 16-char App Password (no spaces)
    EMAIL_FROM_NAME: str = "Halide"
    EMAIL_FROM_ADDRESS: Optional[str] = None  # hello@halide.io.vn

    # Billing (optional for local dev)
    REVENUE_CAT_WEBHOOK_SECRET: Optional[str] = None
    REVENUE_CAT_SECRET_KEY: Optional[str] = None
    REVENUE_CAT_PROJECT_ID: Optional[str] = None
    IS_REVENUE_CAT_SANDBOX: bool = True
    REVENUE_CAT_PRO_ENTITLEMENT_IDS: str = "pro,plus,halide pro,halide_pro"

    model_config = SettingsConfigDict(env_file=str(_ENV_FILE), extra="ignore")

settings = Settings()
print(f"[Config] Loaded REVENUE_CAT_PROJECT_ID: '{settings.REVENUE_CAT_PROJECT_ID}'")
