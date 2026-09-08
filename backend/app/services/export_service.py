from __future__ import annotations

import io
import re
import zipfile
from datetime import datetime, timezone
from typing import Optional

from fastapi import HTTPException
from sqlalchemy.orm import Session

from ..db.models.roll import Roll
from ..db.models.image import Image
from ..db.models.user import User
from .storage_service import storage_service


def _safe_slug(s: str) -> str:
    s = (s or "").strip()
    if not s:
        return "halide-roll"
    s = s.lower()
    s = re.sub(r"[^a-z0-9]+", "-", s).strip("-")
    return s or "halide-roll"


def _users_key_from_image_url(raw: Optional[str]) -> Optional[str]:
    if not raw or not isinstance(raw, str):
        return None
    s = raw.strip()
    if not s:
        return None
    if s.startswith("users/"):
        return s.split("?", 1)[0].rstrip("/")
    if s.startswith("http://") or s.startswith("https://"):
        idx = s.find("/users/")
        if idx >= 0:
            return s[idx + 1 :].split("?", 1)[0].rstrip("/")
    return None


def export_roll_as_zip(db: Session, *, roll_id: str, user: User) -> str:
    """
    Build a ZIP containing all scanned images for a roll, upload it to R2/S3,
    and return the storage key for the ZIP.
    """
    roll = db.query(Roll).filter(Roll.id == roll_id, Roll.user_id == user.id).first()
    if not roll:
        raise HTTPException(status_code=404, detail="Roll not found")

    images = (
        db.query(Image)
        .filter(Image.roll_id == roll.id)
        .order_by(Image.frame_number)
        .all()
    )
    keys: list[str] = []
    for img in images:
        k = _users_key_from_image_url(img.image_url)
        if k and not k.endswith("_thumb.jpg"):
            keys.append(k)

    if not keys:
        raise HTTPException(status_code=400, detail="No gallery images available to export")

    buf = io.BytesIO()
    with zipfile.ZipFile(buf, mode="w", compression=zipfile.ZIP_DEFLATED) as zf:
        for i, key in enumerate(keys, start=1):
            b = storage_service.get_object_bytes(key)
            if not b:
                continue
            # Keep naming stable and human-friendly.
            frame = str(i).zfill(3)
            zf.writestr(f"frames/{frame}.jpg", b)

        meta = {
            "roll_id": str(roll.id),
            "title": roll.title,
            "exported_at": datetime.now(timezone.utc).isoformat(),
            "frame_count": len(keys),
        }
        zf.writestr("README.txt", _readme_text(meta))

    buf.seek(0)

    title = roll.title or "Roll"
    ts = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
    zip_key = f"exports/users/{user.id}/rolls/{roll.id}/{_safe_slug(title)}-{ts}.zip"

    ok = storage_service.put_object_bytes(zip_key, buf.getvalue(), content_type="application/zip")
    if not ok:
        raise HTTPException(status_code=503, detail="Export storage is not configured")

    return zip_key


def _readme_text(meta: dict) -> str:
    title = meta.get("title") or "Untitled Roll"
    return "\n".join(
        [
            "AgXel — Gallery Export",
            "",
            f"Roll: {title}",
            f"Roll ID: {meta.get('roll_id')}",
            f"Frames: {meta.get('frame_count')}",
            f"Exported: {meta.get('exported_at')}",
            "",
            "Tip: keep a backup copy somewhere safe.",
            "",
        ]
    )

