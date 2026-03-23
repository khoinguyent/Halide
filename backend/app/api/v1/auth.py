import logging
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from datetime import timedelta
from ...db.session import get_db
from ...db.schemas.user import UserCreate, UserOut
from ...db.schemas.auth import Token
from ...services import auth_service
from ...core import security
from ...core.dependencies import get_current_user
from ...db.models.user import User

logger = logging.getLogger(__name__)
router = APIRouter()

@router.post("/register", response_model=UserOut)
def register_user(user: UserCreate, db: Session = Depends(get_db)):
    db_user = auth_service.get_user(db, user_id=user.id)
    if db_user:
        return db_user
    return auth_service.create_user(db=db, user=user)

@router.post("/login", response_model=Token)
def login_for_access_token(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    user = auth_service.get_user(db, user_id=form_data.username)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect user ID",
            headers={"WWW-Authenticate": "Bearer"},
        )
    access_token = security.create_access_token(data={"sub": user.id})
    return {"access_token": access_token, "token_type": "bearer"}

@router.get("/me", response_model=UserOut)
def read_user_me(current_user: User = Depends(get_current_user)):
    """
    Returns the current authenticated user profile.
    Creation is handled in get_current_user dependency.
    """
    logger.info("FETCH /me: user_id=%s, subscription_tier=%s", current_user.id, current_user.subscription_tier)
    return current_user
