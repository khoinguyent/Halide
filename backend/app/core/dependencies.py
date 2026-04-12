import base64
import json
import logging
from typing import Optional
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer, HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from firebase_admin import auth as firebase_auth
from ..core.config import settings
from ..db.session import get_db
from ..db.models.user import User

logger = logging.getLogger(__name__)

# Use HTTPBearer so we accept "Authorization: Bearer <token>" (e.g. Firebase ID token)
http_bearer = HTTPBearer(auto_error=True)
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="login")


def _decode_firebase_token_unverified(token: str) -> Optional[dict]:
    """Decode Firebase ID token payload without verification. DEV ONLY - insecure."""
    try:
        parts = token.split(".")
        if len(parts) != 3:
            return None
        payload_b64 = parts[1]
        padding = 4 - len(payload_b64) % 4
        if padding != 4:
            payload_b64 += "=" * padding
        payload_bytes = base64.urlsafe_b64decode(payload_b64)
        return json.loads(payload_bytes)
    except Exception:
        return None


def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(http_bearer), db: Session = Depends(get_db)):
    token = credentials.credentials
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    if not token or not token.strip():
        logger.warning("get_current_user: empty Bearer token")
        raise credentials_exception

    decoded_token = None
    try:
        decoded_token = firebase_auth.verify_id_token(token)
    except Exception as e:
        logger.warning("get_current_user: verify_id_token failed: %s", e)
        if settings.DEV_SKIP_FIREBASE_VERIFY:
            decoded_token = _decode_firebase_token_unverified(token)
            if decoded_token:
                logger.info("get_current_user: using unverified token (DEV_SKIP_FIREBASE_VERIFY)")
        if not decoded_token:
            raise credentials_exception

    uid = decoded_token.get("uid")
    if not uid:
        logger.warning("get_current_user: token has no uid")
        raise credentials_exception

    user = db.query(User).filter(User.id == uid).first()
    if not user:
        email = decoded_token.get("email")
        display_name = decoded_token.get("name") or (email.split("@")[0] if email else "New User")
        user = User(id=uid, email=email, display_name=display_name)
        try:
            db.add(user)
            db.commit()
            db.refresh(user)
        except Exception as e:
            db.rollback()
            # If it was an IntegrityError (race condition), the user should exist now
            user = db.query(User).filter(User.id == uid).first()
            if not user:
                logger.error("get_current_user: Failed to create/retrieve user %s: %s", uid, e)
                raise HTTPException(
                    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                    detail="Error during user initialization"
                )
    
    return user
