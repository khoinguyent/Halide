import os
import boto3
from botocore.client import Config
from app.core.config import settings

def test_r2_upload():
    print(f"Testing R2 upload to bucket: {settings.S3_BUCKET_NAME}")
    print(f"Endpoint: {settings.S3_ENDPOINT}")
    
    s3 = boto3.client(
        's3',
        endpoint_url=settings.S3_ENDPOINT,
        aws_access_key_id=settings.S3_ACCESS_KEY,
        aws_secret_access_key=settings.S3_SECRET_KEY,
        config=Config(signature_version='s3v4'),
        region_name=settings.S3_REGION
    )
    
    test_key = "test_upload_manual.txt"
    test_content = b"This is a test upload for production verification."
    
    try:
        s3.put_object(
            Bucket=settings.S3_BUCKET_NAME,
            Key=test_key,
            Body=test_content,
            ContentType="text/plain"
        )
        print(f"SUCCESS: Uploaded to {test_key}")
        
        # Verify it exists
        response = s3.head_object(Bucket=settings.S3_BUCKET_NAME, Key=test_key)
        print(f"SUCCESS: Verified object exists (Size: {response['ContentLength']} bytes)")
        
        # Cleanup
        s3.delete_object(Bucket=settings.S3_BUCKET_NAME, Key=test_key)
        print("SUCCESS: Cleaned up test object.")
        
    except Exception as e:
        print(f"FAILED: R2 upload error: {e}")

if __name__ == "__main__":
    # Ensure environment is loaded (FastAPI settings should handle this if run inside container)
    test_r2_upload()
