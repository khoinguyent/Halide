from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session

from ...core.dependencies import get_current_user
from ...db.models.user import User
from ...db.schemas.print import PrintCreate, PrintCreateOut, PrintPublicOut
from ...db.session import get_db
from ...services import print_service

router = APIRouter()


def _request_base(request: Request) -> str:
    # Prefer configured public origin; else derive from the incoming request.
    from ...core.config import settings

    configured = getattr(settings, "PUBLIC_WEB_BASE_URL", None)
    if configured and str(configured).strip():
        return str(configured).rstrip("/")
    return str(request.base_url).rstrip("/")


@router.post("/prints", response_model=PrintCreateOut)
def create_print(
    body: PrintCreate,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Create an unlisted print (photo + verso note), email recipients, return public URL.
    Expiry is clamped to 1–30 days. Pro only — unlimited sends for paid users.
    """
    from ...services.gear_tier_limits import tier_is_pro

    if not tier_is_pro(current_user.subscription_tier):
        raise HTTPException(
            status_code=402,
            detail="Prints require AgXel Pro. Free photos stay on device until you upgrade.",
        )
    if body.send_email and not body.recipient_emails:
        raise HTTPException(status_code=400, detail="Add at least one recipient email to send.")
    return print_service.create_shared_print(
        db,
        user=current_user,
        body=body,
        request_base=_request_base(request),
    )


@router.get("/prints/public/{token}", response_model=PrintPublicOut)
def get_public_print_json(token: str, request: Request, db: Session = Depends(get_db)):
    row = print_service.get_active_print(db, token)
    return print_service.to_public_out(row, request_base=_request_base(request))
