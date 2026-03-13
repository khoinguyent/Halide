from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from ...db.session import get_db
from ...core.dependencies import get_current_user
from ...db.models.user import User
from ...services import dashboard_service

router = APIRouter()

@router.get("/dashboard")
def get_dashboard(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    return dashboard_service.get_user_dashboard(db, user_id=current_user.id)
