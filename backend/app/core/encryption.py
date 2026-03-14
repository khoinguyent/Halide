import os
from cryptography.fernet import Fernet
import base64

def get_encryption_key() -> bytes:
    key = os.getenv("ENCRYPTION_KEY")
    if not key:
        # Fallback for development if not provided, though it's unsafe for prod
        return base64.urlsafe_b64encode(b'halide_dev_secret_key_1234567890')
    
    # Ensure key is valid base64
    if len(key) == 44: # standard Fernet key length
        return key.encode('utf-8')
    elif len(key) == 32:
        return base64.urlsafe_b64encode(key.encode('utf-8'))
    else:
        # pad or truncate, then b64 encode to make it 32 bytes (which b64 encodes to 44)
        padded = key.ljust(32, '0')[:32]
        return base64.urlsafe_b64encode(padded.encode('utf-8'))

def get_fernet() -> Fernet:
    return Fernet(get_encryption_key())

def encrypt_credential(data: str) -> str:
    if not data:
        return data
    f = get_fernet()
    return f.encrypt(data.encode('utf-8')).decode('utf-8')

def decrypt_credential(data: str) -> str:
    if not data:
        return data
    f = get_fernet()
    try:
        return f.decrypt(data.encode('utf-8')).decode('utf-8')
    except Exception:
        # Return none or raise, depending on how strict we want to be
        return None
