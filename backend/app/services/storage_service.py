import boto3
from botocore.client import Config
from ..core.config import settings

def _is_s3_configured() -> bool:
    """True if S3 endpoint looks like a real URL (not a placeholder)."""
    url = (settings.S3_ENDPOINT or "").strip()
    return bool(url and "<" not in url and "your-" not in url.lower())

class StorageService:
    def __init__(self):
        self._s3 = None
        self.bucket_name = settings.S3_BUCKET_NAME
        if _is_s3_configured():
            self._s3 = boto3.client(
                's3',
                endpoint_url=settings.S3_ENDPOINT,
                aws_access_key_id=settings.S3_ACCESS_KEY,
                aws_secret_access_key=settings.S3_SECRET_KEY,
                config=Config(signature_version='s3v4'),
                region_name=settings.S3_REGION
            )

    @property
    def s3(self):
        return self._s3

    def upload_roll_image(self, user_id: str, roll_id: str, image_id: str, file_content: bytes, content_type: str = "image/jpeg"):
        """
        Uploads a roll image to S3/R2.
        Key format: users/{uid}/rolls/{roll_id}/{image_id}.jpg
        """
        if self._s3 is None:
            raise RuntimeError("S3/R2 is not configured. Set S3_ENDPOINT and credentials in .env for uploads.")
        key = f"users/{user_id}/rolls/{roll_id}/{image_id}.jpg"
        self._s3.put_object(
            Bucket=self.bucket_name,
            Key=key,
            Body=file_content,
            ContentType=content_type
        )
        return key

storage_service = StorageService()
