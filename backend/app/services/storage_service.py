from typing import Optional
from urllib.parse import urlparse, urlunparse

import boto3
from botocore.client import Config
from ..core.config import settings
import io

def _is_s3_configured() -> bool:
    """True if S3 endpoint looks like a real URL (not a placeholder)."""
    url = (settings.S3_ENDPOINT or "").strip()
    return bool(url and "<" not in url and "your-" not in url.lower())


def _s3_api_endpoint_for_boto(raw_endpoint: str) -> str:
    """
    R2/S3 API base must be origin only: https://<accountid>.r2.cloudflarestorage.com
    If `.env` mistakenly appends /{bucket} to S3_ENDPOINT, boto3 path-style URLs become
    .../bucket/bucket/key (duplicate bucket segment). Strip any path so Bucket= is the only bucket.
    """
    raw = (raw_endpoint or "").strip()
    if not raw:
        return raw
    parsed = urlparse(raw)
    if not parsed.scheme or not parsed.netloc:
        return raw.rstrip("/")
    return urlunparse((parsed.scheme, parsed.netloc, "", "", "", "")).rstrip("/")


class StorageService:
    def __init__(self):
        self._s3 = None
        self.bucket_name = settings.S3_BUCKET_NAME
        if _is_s3_configured():
            api_origin = _s3_api_endpoint_for_boto(settings.S3_ENDPOINT)
            self._s3 = boto3.client(
                's3',
                endpoint_url=api_origin,
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

        base_key = f"users/{user_id}/rolls/{roll_id}/{image_id}"
        full_key = f"{base_key}.jpg"
        thumb_key = f"{base_key}_thumb.jpg"

        # Upload original / full-size bytes
        self._s3.put_object(
            Bucket=self.bucket_name,
            Key=full_key,
            Body=file_content,
            ContentType=content_type,
        )

        # Best-effort thumbnail generation; failures shouldn't break uploads.
        # Note: Pillow may not be installed in some environments.
        try:
            from PIL import Image as PILImage  # type: ignore

            img = PILImage.open(io.BytesIO(file_content))
            img = img.convert("RGB")
            img.thumbnail((800, 800))  # good for grid / list thumbnails

            buf = io.BytesIO()
            img.save(buf, format="JPEG", quality=80)
            buf.seek(0)

            self._s3.put_object(
                Bucket=self.bucket_name,
                Key=thumb_key,
                Body=buf.getvalue(),
                ContentType="image/jpeg",
            )
        except ModuleNotFoundError:
            # Skip thumbnails if Pillow isn't available.
            pass
        except Exception:
            # In a real app we'd log this; for now we silently fall back to full-size only.
            pass

        return full_key

    def upload_gear_image(
        self,
        user_id: str,
        user_camera_id: str,
        image_id: str,
        file_content: bytes,
        content_type: str = "image/jpeg",
    ) -> str:
        """
        Upload a user gear photo to S3/R2.
        Key format: users/{uid}/gear/{user_camera_id}/{image_id}.jpg
        """
        if self._s3 is None:
            raise RuntimeError("S3/R2 is not configured. Set S3_ENDPOINT and credentials in .env for uploads.")

        base_key = f"users/{user_id}/gear/{user_camera_id}/{image_id}"
        full_key = f"{base_key}.jpg"
        thumb_key = f"{base_key}_thumb.jpg"

        self._s3.put_object(
            Bucket=self.bucket_name,
            Key=full_key,
            Body=file_content,
            ContentType=content_type,
        )

        try:
            from PIL import Image as PILImage  # type: ignore

            img = PILImage.open(io.BytesIO(file_content))
            img = img.convert("RGB")
            img.thumbnail((800, 800))
            buf = io.BytesIO()
            img.save(buf, format="JPEG", quality=80)
            buf.seek(0)
            self._s3.put_object(
                Bucket=self.bucket_name,
                Key=thumb_key,
                Body=buf.getvalue(),
                ContentType="image/jpeg",
            )
        except ModuleNotFoundError:
            pass
        except Exception:
            pass

        return full_key

    def presigned_get_object_url(self, key: str, expires_in: int = 43200) -> Optional[str]:
        """
        Time-limited HTTPS URL on the S3-compatible API host (e.g. *.r2.cloudflarestorage.com).
        Used only when R2_PUBLIC_BASE_URL is not set (private bucket). Not interchangeable with pub.r2.dev.
        """
        if self._s3 is None:
            return None
        try:
            return self._s3.generate_presigned_url(
                "get_object",
                Params={"Bucket": self.bucket_name, "Key": key},
                ExpiresIn=expires_in,
            )
        except Exception:
            return None

    def get_object_bytes(self, key: str) -> Optional[bytes]:
        """Fetch an object by key and return its raw bytes."""
        if self._s3 is None:
            return None
        try:
            r = self._s3.get_object(Bucket=self.bucket_name, Key=key)
            body = r.get("Body")
            if body is None:
                return None
            return body.read()
        except Exception:
            return None

    def put_object_bytes(self, key: str, content: bytes, content_type: str = "application/octet-stream") -> bool:
        """Upload raw bytes to an object key."""
        if self._s3 is None:
            return False
        try:
            self._s3.put_object(
                Bucket=self.bucket_name,
                Key=key,
                Body=content,
                ContentType=content_type,
            )
            return True
        except Exception:
            return False

    def replace_roll_image_at_key(self, storage_key: str, file_content: bytes, content_type: str = "image/jpeg") -> str:
        """
        Overwrite an existing roll image at the same S3/R2 key and regenerate its thumbnail.
        `storage_key` is the object key (e.g. users/<uid>/rolls/<roll_id>/<id>.jpg).
        """
        if self._s3 is None:
            raise RuntimeError("S3/R2 is not configured. Set S3_ENDPOINT and credentials in .env for uploads.")

        self._s3.put_object(
            Bucket=self.bucket_name,
            Key=storage_key,
            Body=file_content,
            ContentType=content_type,
        )

        base_key = storage_key[:-4] if storage_key.endswith(".jpg") else storage_key
        thumb_key = f"{base_key}_thumb.jpg"

        try:
            from PIL import Image as PILImage  # type: ignore

            img = PILImage.open(io.BytesIO(file_content))
            img = img.convert("RGB")
            img.thumbnail((800, 800))
            buf = io.BytesIO()
            img.save(buf, format="JPEG", quality=80)
            buf.seek(0)
            self._s3.put_object(
                Bucket=self.bucket_name,
                Key=thumb_key,
                Body=buf.getvalue(),
                ContentType="image/jpeg",
            )
        except ModuleNotFoundError:
            pass
        except Exception:
            pass

        return storage_key

    def upload_avatar(self, user_id: str, file_content: bytes, content_type: str = "image/jpeg"):
        """
        Uploads a user avatar to S3/R2 when configured.
        When S3 is not configured (local storage mode), returns "local" so the app
        uses the image stored on the device; no cloud upload is performed.
        Key format when S3 used: users/{uid}/profile/avatar.jpg
        """
        if self._s3 is None:
            return "local"
        key = f"users/{user_id}/profile/avatar.jpg"
        self._s3.put_object(
            Bucket=self.bucket_name,
            Key=key,
            Body=file_content,
            ContentType=content_type,
        )
        return key


storage_service = StorageService()
