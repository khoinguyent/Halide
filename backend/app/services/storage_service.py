import boto3
from botocore.client import Config
from ..core.config import settings

class StorageService:
    def __init__(self):
        self.s3 = boto3.client(
            's3',
            endpoint_url=settings.S3_ENDPOINT,
            aws_access_key_id=settings.S3_ACCESS_KEY,
            aws_secret_access_key=settings.S3_SECRET_KEY,
            config=Config(signature_version='s3v4'),
            region_name=settings.S3_REGION
        )
        self.bucket_name = settings.S3_BUCKET_NAME

    def upload_roll_image(self, user_id: str, roll_id: str, image_id: str, file_content: bytes, content_type: str = "image/jpeg"):
        """
        Uploads a roll image to S3/R2.
        Key format: users/{uid}/rolls/{roll_id}/{image_id}.jpg
        """
        key = f"users/{user_id}/rolls/{roll_id}/{image_id}.jpg"
        
        self.s3.put_object(
            Bucket=self.bucket_name,
            Key=key,
            Body=file_content,
            ContentType=content_type
        )
        
        return key

    def upload_avatar(self, user_id: str, file_content: bytes, content_type: str = "image/jpeg"):
        """
        Uploads a user avatar to S3/R2.
        Key format: users/{uid}/profile/avatar.jpg
        """
        key = f"users/{user_id}/profile/avatar.jpg"
        
        self.s3.put_object(
            Bucket=self.bucket_name,
            Key=key,
            Body=file_content,
            ContentType=content_type
        )
        
        return key


storage_service = StorageService()
