"""Create and resolve shared photo prints (verso note + unlisted URL)."""
from __future__ import annotations

import io
import logging
import os
import secrets
from datetime import datetime, timedelta, timezone
from typing import Optional, Tuple

from fastapi import HTTPException
from sqlalchemy.orm import Session

from ..core.config import settings
from ..db.models.image import Image
from ..db.models.roll import Roll
from ..db.models.shared_print import SharedPrint
from ..db.models.user import User
from ..db.schemas.print import PrintCreate, PrintCreateOut, PrintLayerOut, PrintPublicOut, QrStampCrop
from .email_service import send_print_shared
from .roll_service import _halide_users_key_from_image_url_field
from .storage_service import storage_service

logger = logging.getLogger(__name__)

MAX_EXPIRE_DAYS = 30
_QR_CELL_PX = 12
_QR_BORDER_MODULES = 2


def _layers_payload(body: PrintCreate) -> list[dict]:
    out: list[dict] = []
    for layer in body.layers or []:
        out.append(
            {
                "text": layer.text,
                "font_style": layer.font_style,
                "font_size": float(layer.font_size),
                "text_color": layer.text_color,
                "text_align": layer.text_align,
                "pos_x": float(layer.pos_x),
                "pos_y": float(layer.pos_y),
            }
        )
    return out


def _layers_from_row(row: SharedPrint) -> list[PrintLayerOut]:
    raw = row.layers if isinstance(row.layers, list) else []
    layers: list[PrintLayerOut] = []
    for item in raw:
        if not isinstance(item, dict):
            continue
        text = str(item.get("text") or "").strip()
        if not text:
            continue
        layers.append(
            PrintLayerOut(
                text=text,
                font_style=str(item.get("font_style") or "hand"),
                font_size=float(item.get("font_size") or 22),
                text_color=str(item.get("text_color") or "#2c2416"),
                text_align=str(item.get("text_align") or "center"),
                pos_x=float(item.get("pos_x") if item.get("pos_x") is not None else 0.5),
                pos_y=float(item.get("pos_y") if item.get("pos_y") is not None else 0.4),
            )
        )
    if layers:
        return layers
    # Legacy single-note fallback
    note = (row.note_text or "").strip()
    if not note:
        return []
    return [
        PrintLayerOut(
            text=note,
            font_style=row.font_style or "hand",
            font_size=float(row.font_size or 22),
            text_color=row.text_color or "#2c2416",
            text_align=row.text_align or "left",
            pos_x=float(row.pos_x if row.pos_x is not None else 0.1),
            pos_y=float(row.pos_y if row.pos_y is not None else 0.15),
        )
    ]


def _utcnow() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


def _public_base_url() -> str:
    raw = getattr(settings, "PUBLIC_WEB_BASE_URL", None)
    if raw and str(raw).strip():
        return str(raw).rstrip("/")
    # Fall back to API host used by the mobile app in production/staging.
    return "https://stagging-api.smartconnector.io.vn"


def public_url_for_token(token: str, request_base: Optional[str] = None) -> str:
    base = (request_base or _public_base_url()).rstrip("/")
    return f"{base}/p/{token}"


def _new_token() -> str:
    return secrets.token_urlsafe(18)


def _crop_stamp_from_image(image_bytes: bytes, stamp: QrStampCrop):
    from PIL import Image as PILImage

    img = PILImage.open(io.BytesIO(image_bytes)).convert("RGB")
    w, h = img.size
    side = int(round(min(w, h) * float(stamp.size)))
    side = max(48, min(side, min(w, h)))
    left = int(round(float(stamp.center_x) * w - side / 2))
    top = int(round(float(stamp.center_y) * h - side / 2))
    left = max(0, min(left, w - side))
    top = max(0, min(top, h - side))
    return img.crop((left, top, left + side, top + side))


def _postage_stamp_polygon(size: int, teeth: int = 14, depth: Optional[float] = None) -> list:
    """Perforated postage-stamp outline (matches Flutter stamp template)."""
    if depth is None:
        depth = max(2.5, size * 0.04)
    step = size / float(teeth)
    pts: list[tuple[float, float]] = []

    # Top edge L→R
    pts.append((0.0, depth))
    for i in range(teeth):
        x = i * step
        pts.append((x + step * 0.35, 0.0))
        pts.append((x + step * 0.65, depth))
        pts.append((x + step, depth))
    # Right edge T→B
    for i in range(teeth):
        y = i * step
        pts.append((size - depth, y + step * 0.35))
        pts.append((size, y + step * 0.65))
        pts.append((size - depth, y + step))
    # Bottom edge R→L
    for i in range(teeth, 0, -1):
        x = i * step
        pts.append((x - step * 0.35, size))
        pts.append((x - step * 0.65, size - depth))
        pts.append((x - step, size - depth))
    # Left edge B→T
    for i in range(teeth, 0, -1):
        y = i * step
        pts.append((depth, y - step * 0.35))
        pts.append((0.0, y - step * 0.65))
        pts.append((depth, y - step))
    return pts


def _postage_stamp_rgba(stamp_img, side: int, ring: int = 10):
    """Postage-stamp shaped crop with a white padding ring (logo-in-QR style)."""
    from PIL import Image as PILImage
    from PIL import ImageDraw

    outer = side + ring * 2
    canvas = PILImage.new("RGBA", (outer, outer), (0, 0, 0, 0))

    # White stamp pad slightly larger so modules don't collide with photo edge
    white = PILImage.new("RGBA", (outer, outer), (0, 0, 0, 0))
    ImageDraw.Draw(white).polygon(
        _postage_stamp_polygon(outer),
        fill=(255, 255, 255, 255),
    )
    canvas = PILImage.alpha_composite(canvas, white)

    photo = stamp_img.convert("RGB").resize((side, side), PILImage.Resampling.LANCZOS)
    photo_rgba = photo.convert("RGBA")
    mask = PILImage.new("L", (side, side), 0)
    ImageDraw.Draw(mask).polygon(_postage_stamp_polygon(side), fill=255)
    photo_rgba.putalpha(mask)
    canvas.paste(photo_rgba, (ring, ring), photo_rgba)
    return canvas


def _logo_frac_for_stamp_size(stamp_size: Optional[float]) -> float:
    """Map stamp crop size → QR center badge size (keeps EC-H scannable)."""
    # Frontend min/max: 0.28 – 0.40 → QR logo ~30% – 38% (larger center stamp in email).
    # EC level H tolerates ~30% occlusion; stay under ~40% for reliable phone scans.
    lo, hi = 0.28, 0.40
    logo_lo, logo_hi = 0.30, 0.38
    if stamp_size is None:
        return 0.34
    t = (float(stamp_size) - lo) / max(0.01, hi - lo)
    t = max(0.0, min(1.0, t))
    return logo_lo + (logo_hi - logo_lo) * t


def _is_staging_env() -> bool:
    """True for staging so print emails can include both QR styles for A/B testing."""
    base = (getattr(settings, "PUBLIC_WEB_BASE_URL", None) or _public_base_url() or "").lower()
    env_file = (os.getenv("ENV_FILE") or "").lower()
    return (
        "stagging" in base
        or "staging" in base
        or env_file.endswith("env.staging")
        or "env.staging" in env_file
    )


def _blend_channel(src: int, toward: int, amount: float) -> int:
    return int(round(src * (1.0 - amount) + toward * amount))


def _is_finder_zone(row: int, col: int, n: int) -> bool:
    zones = ((0, 0), (0, n - 7), (n - 7, 0))
    for r0, c0 in zones:
        if r0 - 1 <= row <= r0 + 7 and c0 - 1 <= col <= c0 + 7:
            if 0 <= row < n and 0 <= col < n:
                return True
    return False


def make_artistic_qr_png(public_url: str, stamp_img) -> bytes:
    """QR painted with the stamp photo (modules keep photo texture)."""
    import qrcode
    from PIL import Image as PILImage
    from PIL import ImageEnhance
    from qrcode.constants import ERROR_CORRECT_H

    qr = qrcode.QRCode(
        version=None,
        error_correction=ERROR_CORRECT_H,
        box_size=1,
        border=_QR_BORDER_MODULES,
    )
    qr.add_data(public_url)
    qr.make(fit=True)
    matrix = qr.get_matrix()
    n = len(matrix)
    cell = _QR_CELL_PX
    out_size = n * cell

    stamp = stamp_img.convert("RGB").resize((out_size, out_size), PILImage.Resampling.LANCZOS)
    stamp = ImageEnhance.Contrast(stamp).enhance(1.15)
    stamp = ImageEnhance.Color(stamp).enhance(1.05)
    out = PILImage.new("RGB", (out_size, out_size), (255, 255, 255))
    sp = stamp.load()
    op = out.load()
    data_n = n - 2 * _QR_BORDER_MODULES

    for r in range(n):
        for c in range(n):
            dark = bool(matrix[r][c])
            y0, x0 = r * cell, c * cell
            if (
                r < _QR_BORDER_MODULES
                or c < _QR_BORDER_MODULES
                or r >= n - _QR_BORDER_MODULES
                or c >= n - _QR_BORDER_MODULES
            ):
                color = (20, 20, 20) if dark else (255, 255, 255)
                for y in range(y0, y0 + cell):
                    for x in range(x0, x0 + cell):
                        op[x, y] = color
                continue

            dr = r - _QR_BORDER_MODULES
            dc = c - _QR_BORDER_MODULES
            function = (
                _is_finder_zone(dr, dc, data_n)
                or dr == 6
                or dc == 6
                or dr == 8
                or dc == 8
            )

            rs = gs = bs = 0
            count = cell * cell
            for y in range(y0, y0 + cell):
                for x in range(x0, x0 + cell):
                    pr, pg, pb = sp[x, y]
                    rs += pr
                    gs += pg
                    bs += pb
            avg = (rs // count, gs // count, bs // count)

            if function:
                fill = (18, 18, 18) if dark else (250, 250, 250)
                for y in range(y0, y0 + cell):
                    for x in range(x0, x0 + cell):
                        op[x, y] = fill
                continue

            inset = 1
            for y in range(y0, y0 + cell):
                for x in range(x0, x0 + cell):
                    if x < x0 + inset or y < y0 + inset or x >= x0 + cell - inset or y >= y0 + cell - inset:
                        op[x, y] = (255, 255, 255)
                        continue
                    pr, pg, pb = sp[x, y]
                    if dark:
                        op[x, y] = (
                            _blend_channel(pr, 10, 0.72),
                            _blend_channel(pg, 10, 0.72),
                            _blend_channel(pb, 10, 0.72),
                        )
                    else:
                        op[x, y] = (
                            _blend_channel(pr, 255, 0.55),
                            _blend_channel(pg, 255, 0.55),
                            _blend_channel(pb, 255, 0.55),
                        )

            cx0 = x0 + cell // 2 - 1
            cy0 = y0 + cell // 2 - 1
            if dark:
                center_fill = (
                    _blend_channel(avg[0], 0, 0.85),
                    _blend_channel(avg[1], 0, 0.85),
                    _blend_channel(avg[2], 0, 0.85),
                )
            else:
                center_fill = (
                    _blend_channel(avg[0], 255, 0.7),
                    _blend_channel(avg[1], 255, 0.7),
                    _blend_channel(avg[2], 255, 0.7),
                )
            for y in range(cy0, cy0 + 3):
                for x in range(cx0, cx0 + 3):
                    if x0 <= x < x0 + cell and y0 <= y < y0 + cell:
                        op[x, y] = center_fill

    buf = io.BytesIO()
    out.save(buf, format="PNG", optimize=True)
    return buf.getvalue()


def make_stamp_center_qr_png(
    public_url: str,
    stamp_img,
    stamp_size: Optional[float] = None,
) -> bytes:
    """Standard scannable QR with the postage-stamp photo centered like a logo.

    Uses high error correction so the center overlay stays readable when scanned.
    Badge size scales with [stamp_size] within a scannable band.
    """
    import qrcode
    from qrcode.constants import ERROR_CORRECT_H

    qr = qrcode.QRCode(
        version=None,
        error_correction=ERROR_CORRECT_H,
        box_size=_QR_CELL_PX,
        border=_QR_BORDER_MODULES,
    )
    qr.add_data(public_url)
    qr.make(fit=True)
    qr_img = qr.make_image(fill_color="black", back_color="white").convert("RGBA")

    qr_w, qr_h = qr_img.size
    logo_frac = _logo_frac_for_stamp_size(stamp_size)
    logo_side = max(48, int(min(qr_w, qr_h) * logo_frac))
    ring = max(6, logo_side // 10)
    badge = _postage_stamp_rgba(stamp_img, logo_side, ring=ring)

    bx, by = badge.size
    pos = ((qr_w - bx) // 2, (qr_h - by) // 2)
    qr_img.paste(badge, pos, badge)

    out = qr_img.convert("RGB")
    buf = io.BytesIO()
    out.save(buf, format="PNG", optimize=True)
    return buf.getvalue()


def make_print_qr_png(
    public_url: str,
    stamp_img=None,
    stamp_size: Optional[float] = None,
) -> bytes:
    """PNG QR that encodes the public print page URL (for email / scan)."""
    if stamp_img is not None:
        try:
            return make_stamp_center_qr_png(public_url, stamp_img, stamp_size=stamp_size)
        except Exception:
            logger.exception("[Print] stamp-center QR failed — falling back to plain QR")

    import qrcode
    from qrcode.constants import ERROR_CORRECT_H

    # High EC even without stamp so a future logo overlay could be added.
    qr = qrcode.QRCode(
        version=None,
        error_correction=ERROR_CORRECT_H,
        box_size=8,
        border=2,
    )
    qr.add_data(public_url)
    qr.make(fit=True)
    img = qr.make_image(fill_color="black", back_color="white")
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()


def _build_and_store_qr(
    *,
    user_id: str,
    token: str,
    public_url: str,
    image_bytes: bytes,
    stamp: Optional[QrStampCrop],
) -> Tuple[bytes, Optional[str]]:
    """Build center-stamp QR (postage photo in center) and store as qr.png.

    Returns (qr_png, storage_key).
    """
    stamp_img = None
    stamp_size: Optional[float] = None
    if stamp is not None:
        try:
            stamp_img = _crop_stamp_from_image(image_bytes, stamp)
            stamp_size = float(stamp.size)
        except Exception:
            logger.exception("[Print] stamp crop failed — using plain QR")
            stamp_img = None

    png = make_print_qr_png(public_url, stamp_img=stamp_img, stamp_size=stamp_size)
    key = f"users/{user_id}/prints/{token}/qr.png"
    stored = storage_service.put_object_bytes(key, png, content_type="image/png")
    return png, (key if stored else None)


def load_print_image_bytes(row: SharedPrint) -> tuple[bytes, str]:
    key = row.image_storage_key
    users_key = _halide_users_key_from_image_url_field(key) or key
    data = storage_service.get_object_bytes(users_key)
    if not data and key.startswith("http"):
        raise HTTPException(status_code=404, detail="Image unavailable")
    if not data:
        raise HTTPException(status_code=404, detail="Image unavailable")
    ctype = "image/jpeg"
    low = users_key.lower()
    if low.endswith(".png"):
        ctype = "image/png"
    elif low.endswith(".webp"):
        ctype = "image/webp"
    return data, ctype


def load_print_qr_png(row: SharedPrint, public_url: str) -> bytes:
    """Serve cached center-stamp QR, regenerating when needed."""
    key = (row.qr_storage_key or "").strip()
    if key:
        cached = storage_service.get_object_bytes(key)
        if cached:
            return cached

    stamp_img = None
    stamp_size = None
    if row.qr_stamp_x is not None and row.qr_stamp_y is not None and row.qr_stamp_size is not None:
        try:
            image_bytes, _ = load_print_image_bytes(row)
            stamp_size = float(row.qr_stamp_size)
            stamp_img = _crop_stamp_from_image(
                image_bytes,
                QrStampCrop(
                    center_x=float(row.qr_stamp_x),
                    center_y=float(row.qr_stamp_y),
                    size=stamp_size,
                ),
            )
        except Exception:
            logger.exception("[Print] regenerate stamp QR crop failed")
            stamp_img = None
    return make_print_qr_png(public_url, stamp_img=stamp_img, stamp_size=stamp_size)


def create_shared_print(
    db: Session,
    *,
    user: User,
    body: PrintCreate,
    request_base: Optional[str] = None,
) -> PrintCreateOut:
    image = db.query(Image).filter(Image.id == body.image_id).first()
    if not image:
        raise HTTPException(status_code=404, detail="Image not found")

    roll = db.query(Roll).filter(Roll.id == image.roll_id, Roll.user_id == user.id).first()
    if not roll:
        raise HTTPException(status_code=404, detail="Image not found")

    if not image.image_url or not str(image.image_url).strip():
        raise HTTPException(
            status_code=400,
            detail="This frame has no cloud scan yet. Sync the roll before sending a print.",
        )

    storage_key = _halide_users_key_from_image_url_field(image.image_url) or str(image.image_url).strip()
    expire_days = max(1, min(int(body.expire_days), MAX_EXPIRE_DAYS))
    now = _utcnow()
    expires_at = now + timedelta(days=expire_days)

    token = _new_token()
    sender_name = (body.from_name or "").strip() or (
        user.display_name or user.professional_nickname or user.email or "A friend"
    )

    stamp = body.qr_stamp
    row = SharedPrint(
        public_token=token,
        user_id=user.id,
        image_id=image.id,
        roll_id=roll.id,
        image_storage_key=storage_key,
        note_text=body.note or "",
        font_style=body.font_style,
        font_size=body.font_size,
        text_color=body.text_color,
        text_align=body.text_align,
        pos_x=body.pos_x,
        pos_y=body.pos_y,
        paper_style=body.paper_style,
        layers=_layers_payload(body),
        qr_stamp_x=float(stamp.center_x) if stamp else None,
        qr_stamp_y=float(stamp.center_y) if stamp else None,
        qr_stamp_size=float(stamp.size) if stamp else None,
        recipient_emails=list(body.recipient_emails or []),
        sender_display_name=sender_name,
        expires_at=expires_at,
    )
    db.add(row)
    db.commit()
    db.refresh(row)

    public_url = public_url_for_token(token, request_base=request_base)
    emails_sent = 0
    email_failed = 0

    qr_png: Optional[bytes] = None
    try:
        image_bytes, _ = load_print_image_bytes(row)
        qr_png, qr_key = _build_and_store_qr(
            user_id=user.id,
            token=token,
            public_url=public_url,
            image_bytes=image_bytes,
            stamp=stamp,
        )
        if qr_key:
            row.qr_storage_key = qr_key
            db.add(row)
            db.commit()
            db.refresh(row)
    except Exception:
        logger.exception("[Print] QR build failed for token=%s", token)
        qr_png = make_print_qr_png(public_url)

    if body.send_email and body.recipient_emails:
        sender = row.sender_display_name or "A friend"
        qr_image_url = f"{public_url.rstrip('/')}/qr.png"
        for to in body.recipient_emails:
            ok = send_print_shared(
                to=to,
                sender_name=sender,
                public_url=public_url,
                qr_image_url=qr_image_url,
                qr_png_bytes=qr_png,
                expire_days=expire_days,
            )
            if ok:
                emails_sent += 1
            else:
                email_failed += 1

    return PrintCreateOut(
        id=row.id,
        public_token=token,
        public_url=public_url,
        expires_at=expires_at,
        emails_sent=emails_sent,
        email_failed=email_failed,
    )


def get_active_print(db: Session, token: str) -> SharedPrint:
    row = db.query(SharedPrint).filter(SharedPrint.public_token == token).first()
    if not row:
        raise HTTPException(status_code=404, detail="Print not found")
    if row.revoked_at is not None:
        raise HTTPException(status_code=410, detail="This print was revoked")
    exp = row.expires_at
    if exp.tzinfo is not None:
        exp = exp.replace(tzinfo=None)
    if exp < _utcnow():
        raise HTTPException(status_code=410, detail="This print has expired")
    return row


def to_public_out(row: SharedPrint, request_base: Optional[str] = None) -> PrintPublicOut:
    base = (request_base or _public_base_url()).rstrip("/")
    layers = _layers_from_row(row)
    return PrintPublicOut(
        public_token=row.public_token,
        note=row.note_text or "",
        font_style=row.font_style or "hand",
        font_size=float(row.font_size or 22),
        text_color=row.text_color or "#2c2416",
        text_align=row.text_align or "left",
        pos_x=float(row.pos_x if row.pos_x is not None else 0.1),
        pos_y=float(row.pos_y if row.pos_y is not None else 0.15),
        paper_style=row.paper_style or "cream",
        layers=layers,
        sender_display_name=row.sender_display_name,
        image_url=f"{base}/p/{row.public_token}/image",
        note_download_url=f"{base}/p/{row.public_token}/note.txt",
        expires_at=row.expires_at,
        created_at=row.created_at,
    )
