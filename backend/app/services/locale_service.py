from __future__ import annotations

from fastapi import HTTPException
from sqlalchemy.orm import Session

from ..db.models.user import User

SUPPORTED_LOCALES = frozenset({"en", "vi", "ja", "ko", "zh", "es", "fr"})
SYSTEM_LOCALE = "system"


def normalize_locale(value: str) -> str:
    normalized = (value or "").strip().lower()
    if normalized == SYSTEM_LOCALE:
        return SYSTEM_LOCALE
    if normalized in SUPPORTED_LOCALES:
        return normalized
    raise HTTPException(
        status_code=400,
        detail=f"Invalid locale '{value}'. Use 'system', 'en', 'vi', 'ja', 'ko', 'zh', 'es', or 'fr'.",
    )


def persist_user_locale(db: Session, user: User, locale: str) -> str:
    stored = normalize_locale(locale)
    if user.preferred_locale != stored:
        user.preferred_locale = stored
        db.commit()
        db.refresh(user)
    return stored
