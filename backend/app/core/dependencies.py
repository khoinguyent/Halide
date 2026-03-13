from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session
from firebase_admin import auth as firebase_auth
from ..db.session import get_db
from ..db.models.user import User

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="login")

def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        decoded_token = firebase_auth.verify_id_token(token)
        uid = decoded_token.get("uid")
        if not uid:
            raise credentials_exception
    except Exception:
        raise credentials_exception
    
    user = db.query(User).filter(User.id == uid).first()
    if not user:
        email = decoded_token.get("email")
        display_name = decoded_token.get("name") or (email.split("@")[0] if email else "New User")
        user = User(id=uid, email=email, display_name=display_name)
        db.add(user)
        db.commit()
        db.refresh(user)
    
    return user
