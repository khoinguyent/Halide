from datetime import datetime
from typing import List, Optional

from fastapi import HTTPException
from sqlalchemy.orm import Session, joinedload
from sqlalchemy import func
from ..db.models.roll import Roll, RollStatusEnum
from ..db.models.film_stock import FilmStock
from ..db.models.camera import UserCamera, Camera, UserLens, Lens
from ..db.models.image import Image
from ..db.models.user import User
from ..db.schemas.roll import RollCreate, RollOutDashboard, RollMetaUpdate, RollDriveUrlUpdate
from ..db.schemas.image import ImageOut
from ..core.config import settings
from .storage_service import storage_service

# Simple hex colors per brand for dashboard cards
_FILM_COLOR = {
    "Kodak": "#FFCC33",
    "Fujifilm": "#00AA55",
    "Ilford": "#333333",
    "default": "#cccccc",
}

def get_roll(db: Session, roll_id: str, user_id: str):
    return db.query(Roll).filter(Roll.id == roll_id, Roll.user_id == user_id).first()


def _gallery_public_url_base() -> Optional[str]:
    """
    Public (unauthenticated) origin for building Plus/Pro roll image URLs when R2_PUBLIC_BASE_URL is set.
    Optionally appends /{S3_BUCKET_NAME} once for path-style public access.
    """
    raw = getattr(settings, "R2_PUBLIC_BASE_URL", None)
    if not raw or not str(raw).strip():
        return None
    base = str(raw).rstrip("/")
    bucket = (settings.S3_BUCKET_NAME or "").strip()
    if getattr(settings, "R2_PUBLIC_APPEND_BUCKET_PATH", False) and bucket:
        suffix = "/" + bucket
        if not base.endswith(suffix):
            base = f"{base}{suffix}"
    return base


def _tier_uses_public_object_urls(subscription_tier: Optional[str]) -> bool:
    """Pro may use unauthenticated R2 public URLs when the bucket allows it."""
    return (subscription_tier or "free").lower() == "pro"


def public_http_url_for_storage_key(k: str) -> str:
    """
    Build a browser-fetchable URL for an object key (users/...) or return legacy full URLs / paths as-is.
    Used for gear uploads and anywhere we store R2 keys and need to expose HTTPS URLs to clients.
    """
    if not isinstance(k, str) or not k.strip():
        return k
    base_url = (settings.S3_ENDPOINT or "").rstrip("/")
    bucket = (settings.S3_BUCKET_NAME or "").strip()

    public_gallery = _gallery_public_url_base()
    if public_gallery is not None:
        url_base = public_gallery
    else:
        if bucket and base_url.endswith("/" + bucket):
            url_base = base_url.rstrip("/")
        else:
            url_base = (f"{base_url}/{bucket}").rstrip("/") if bucket else base_url.rstrip("/")

    users_key = _halide_users_key_from_image_url_field(k)
    if users_key:
        return f"{url_base}/{users_key}".rstrip("/")
    if k.startswith("/") or k.startswith("http://") or k.startswith("https://"):
        return k.split("?", 1)[0]
    return k


def _halide_users_key_from_image_url_field(raw: Optional[str]) -> Optional[str]:
    """
    DB may store either an object key (users/...) or a legacy full public URL.
    Extract the users/... key so we can build a canonical URL with current R2 settings.
    """
    if not raw or not isinstance(raw, str):
        return None
    s = raw.strip()
    if not s:
        return None
    if s.startswith("users/"):
        return s.split("?", 1)[0].rstrip("/")
    low = s.lower()
    if low.startswith("http://") or low.startswith("https://"):
        idx = s.find("/users/")
        if idx >= 0:
            return s[idx + 1 :].split("?", 1)[0].rstrip("/")
    return None


def _single_gallery_http_url(
    k: str,
    owner_tier: Optional[str],
    url_base: str,
    gallery_public_opt: Optional[str],
) -> Optional[str]:
    """Turn a stored object key or legacy URL into a browser-loadable HTTPS (or path) URL."""
    if not isinstance(k, str) or not str(k).strip():
        return None
    users_key = _halide_users_key_from_image_url_field(k)
    if users_key:
        if gallery_public_opt is not None:
            return f"{url_base}/{users_key}".rstrip("/")
        if _tier_uses_public_object_urls(owner_tier):
            return f"{url_base}/{users_key}".rstrip("/")
        signed = storage_service.presigned_get_object_url(users_key)
        if signed:
            return signed
        return f"{url_base}/{users_key}".rstrip("/")
    if k.startswith("/") or k.startswith("http://") or k.startswith("https://"):
        return k.split("?", 1)[0]
    return None


def _build_roll_dashboard(r: Roll, db: Session) -> RollOutDashboard:
    """Build RollOutDashboard for a single Roll."""
    owner = db.query(User).filter(User.id == r.user_id).first()
    owner_tier = owner.subscription_tier if owner else None

    film = db.query(FilmStock).filter(FilmStock.id == r.film_stock_id).first()
    brand = film.brand if film else ""
    name = film.name if film else ""
    film_format = film.format.name if film and film.format else None
    color = _FILM_COLOR.get(brand, _FILM_COLOR["default"])
    camera_name = None
    if r.user_camera_id:
        uc = db.query(UserCamera).filter(UserCamera.id == r.user_camera_id).first()
        if uc and uc.camera_id:
            cam = db.query(Camera).filter(Camera.id == uc.camera_id).first()
            if cam:
                camera_name = f"{cam.brand} {cam.model}"
    lens_name = None
    if r.user_lens_id:
        ul = db.query(UserLens).filter(UserLens.id == r.user_lens_id).first()
        if ul and ul.lens_id:
            lens = db.query(Lens).filter(Lens.id == ul.lens_id).first()
            if lens:
                lens_name = f"{lens.brand} {lens.model}"
    images = (
        db.query(Image)
        .filter(Image.roll_id == r.id)
        .order_by(Image.frame_number)
        .all()
    )
    # Gallery URLs: only rows with a stored image key/URL (scanned uploads).
    image_rows = [row for row in images if row.image_url]
    keys = [row.image_url for row in image_rows]

    # Image.image_url is stored as a storage key (not a full URL). Convert it
    # to an HTTP URL so the Flutter gallery can render via Image.network.
    base_url = (settings.S3_ENDPOINT or "").rstrip("/")
    bucket = (settings.S3_BUCKET_NAME or "").strip()

    public_gallery = _gallery_public_url_base()
    if public_gallery is not None:
        url_base = public_gallery
    else:
        # If the endpoint already includes the bucket path (common for some R2 configs),
        # don't append bucket again.
        if bucket and base_url.endswith("/" + bucket):
            url_base = base_url.rstrip("/")
        else:
            url_base = (f"{base_url}/{bucket}").rstrip("/") if bucket else base_url.rstrip("/")

    # `k` may be an object key (users/...) or a legacy full URL from older uploads.
    # Rebuild from users/... + current public base so bucket/host always match R2 (see fix_r2_urls.py).
    gallery_public_opt = _gallery_public_url_base()
    image_urls = []
    for k in keys:
        u = _single_gallery_http_url(k, owner_tier, url_base, gallery_public_opt)
        if u:
            image_urls.append(u)

    # Apply shot_offset shift for alignment calibration
    # Moves the first N frames to the end of the list.
    if r.shot_offset and r.shot_offset > 0 and len(image_urls) > 0:
        offset = r.shot_offset % len(image_urls)
        image_urls = image_urls[offset:] + image_urls[:offset]
        image_rows = image_rows[offset:] + image_rows[:offset]

    total_frames = (r.max_frames if r.max_frames is not None else 36)
    actual_frames = len(image_urls)

    # Shot log / EXIF: include log-only rows (meter + EXIF from app) where image_url is null.
    # Order: same as gallery for URL rows (after rotation), then log-only rows by frame number.
    log_rows = [
        row
        for row in images
        if row.image_url is None or (isinstance(row.image_url, str) and not str(row.image_url).strip())
    ]
    log_rows_sorted = sorted(log_rows, key=lambda x: (x.frame_number is None, x.frame_number or 0))
    # Expose resolved https URLs on each shot so clients can fall back to [Shot.imageUrl] when
    # [image_urls] is empty or filtered differently (e.g. after offset).
    shots_gallery: List[ImageOut] = []
    for row in image_rows:
        out = ImageOut.model_validate(row)
        raw = row.image_url
        if raw and isinstance(raw, str) and raw.strip():
            resolved = _single_gallery_http_url(raw, owner_tier, url_base, gallery_public_opt)
            if resolved:
                out = out.model_copy(update={"image_url": resolved})
        shots_gallery.append(out)
    shots_out: List[ImageOut] = shots_gallery + [ImageOut.model_validate(r) for r in log_rows_sorted]

    return RollOutDashboard(
        id=str(r.id),
        brand=brand,
        name=name,
        color=color,
        film_format=film_format,
        status=r.status.value,
        image_urls=image_urls,
        shots=shots_out,
        drive_url=getattr(r, "drive_url", None),
        title=r.title,
        description=r.description,
        # Keep existing frontend contract: use title as the "nickname" shown on cards.
        nickname=r.title,
        camera_name=camera_name,
        lens_name=lens_name,
        frame_count=actual_frames,
        max_frames=total_frames,
        shot_offset=r.shot_offset,
        created_at=r.created_at,
    )


def get_roll_for_dashboard_by_id(db: Session, roll_id: str, user_id: str):
    """Return a single roll in dashboard shape or None if not found."""
    r = get_roll(db, roll_id, user_id)
    if not r:
        return None
    return _build_roll_dashboard(r, db)

def get_rolls(db: Session, user_id: str, skip: int = 0, limit: int = 100):
    return db.query(Roll).filter(Roll.user_id == user_id).order_by(Roll.created_at.desc()).offset(skip).limit(limit).all()

def get_rolls_for_dashboard(db: Session, user_id: str, skip: int = 0, limit: int = 100) -> list[RollOutDashboard]:
    """Returns rolls with film stock, camera/lens names, and image_urls for list/dashboard."""
    rolls = (
        db.query(Roll)
        .filter(Roll.user_id == user_id)
        .order_by(Roll.created_at.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )
    return [_build_roll_dashboard(r, db) for r in rolls]

def create_roll(db: Session, roll: RollCreate, user_id: str):
    db_roll = Roll(**roll.dict(), user_id=user_id)
    db.add(db_roll)
    db.commit()
    db.refresh(db_roll)
    return db_roll

def update_roll_status(db: Session, roll_id: str, new_status: RollStatusEnum, user_id: str):
    db_roll = get_roll(db, roll_id, user_id)
    if not db_roll:
        raise HTTPException(status_code=404, detail="Roll not found")
    
    # Simple transition validation logic
    # loaded -> shooting -> lab -> scanned -> archived
    # We allow skipping but not going backwards (except maybe from archived? No, spec says no illegal jumps)
    
    order = {
        RollStatusEnum.loaded: 0,
        RollStatusEnum.shooting: 1,
        RollStatusEnum.lab: 2,
        RollStatusEnum.scanned: 3,
        RollStatusEnum.archived: 4
    }
    
    current_idx = order.get(db_roll.status)
    new_idx = order.get(new_status)
    
    if current_idx is None or new_idx is None:
        # Handle unknown status or just log and proceed if order doesn't apply
        db_roll.status = new_status
        db.add(db_roll)
        db.commit()
        db.refresh(db_roll)
        return db_roll
        
    if new_idx < current_idx:
        raise HTTPException(
            status_code=400, 
            detail={
                "code": "invalid_status_transition",
                "message": f"Cannot transition from {db_roll.status.value} to {new_status.value}"
            }
        )
        
    db_roll.status = new_status
    db.add(db_roll)
    db.commit()
    db.refresh(db_roll)
    return db_roll


def pause_gyro_scan_session(db: Session, roll_id: str, user_id: str):
    """Keep roll at lab while gyro scan is in progress or paused mid-roll."""
    db_roll = get_roll(db, roll_id, user_id)
    if not db_roll:
        raise HTTPException(status_code=404, detail="Roll not found")

    if db_roll.status == RollStatusEnum.scanned:
        db_roll.status = RollStatusEnum.lab
        db.add(db_roll)
        db.commit()
        db.refresh(db_roll)
    return db_roll


def update_roll_meta(db: Session, roll_id: str, meta: RollMetaUpdate, user_id: str):
    db_roll = get_roll(db, roll_id, user_id)
    if not db_roll:
        raise HTTPException(status_code=404, detail="Roll not found")

    # Patch semantics: missing fields are treated as no-op at the DB layer by setting directly.
    # Frontend always sends title/description (possibly null) for editing.
    if meta.title is not None:
        db_roll.title = meta.title
    if meta.description is not None:
        db_roll.description = meta.description
    if meta.shot_offset is not None:
        db_roll.shot_offset = meta.shot_offset

    db.add(db_roll)
    db.commit()
    db.refresh(db_roll)
    return _build_roll_dashboard(db_roll, db)


def update_roll_drive_url(db: Session, roll_id: str, drive_url_update: RollDriveUrlUpdate, user_id: str):
    db_roll = get_roll(db, roll_id, user_id)
    if not db_roll:
        raise HTTPException(status_code=404, detail="Roll not found")

    raw = (drive_url_update.drive_url or "").strip()
    db_roll.drive_url = raw if raw else None

    db.add(db_roll)
    db.commit()
    db.refresh(db_roll)
    return _build_roll_dashboard(db_roll, db)


def add_local_images(db: Session, roll_id: str, local_paths: list[str], user_id: str):
    db_roll = get_roll(db, roll_id, user_id)
    if not db_roll:
        raise HTTPException(status_code=404, detail="Roll not found")

    # Get current max frame number
    max_frame = db.query(func.max(Image.frame_number)).filter(Image.roll_id == str(roll_id)).scalar()
    start_frame = (max_frame + 1) if max_frame is not None else 0

    new_images = []
    for i, path in enumerate(local_paths):
        db_image = Image(
            roll_id=str(roll_id),
            image_url=path,
            frame_number=start_frame + i
        )
        db.add(db_image)
        new_images.append(db_image)

    db.commit()
    return new_images


def log_shot(
    db: Session,
    roll_id: str,
    aperture: float,
    shutter_speed: str,
    user_id: str,
    lat: Optional[float] = None,
    lng: Optional[float] = None,
    notes: Optional[str] = None,
    logged_at: Optional[datetime] = None,
):
    db_roll = get_roll(db, roll_id, user_id)
    if not db_roll:
        raise HTTPException(status_code=404, detail="Roll not found")

    # Get current max frame number
    max_frame = db.query(func.max(Image.frame_number)).filter(Image.roll_id == str(roll_id)).scalar()
    start_frame = (max_frame + 1) if max_frame is not None else 0

    img_kwargs = dict(
        roll_id=str(roll_id),
        frame_number=start_frame,
        image_url=None,  # This is a log-only entry
        aperture=aperture,
        shutter_speed=shutter_speed,
        notes=notes,
        location_lat=lat,
        location_lng=lng,
    )
    if logged_at is not None:
        img_kwargs["created_at"] = logged_at

    db_image = Image(**img_kwargs)
    db.add(db_image)
    db.commit()
    db.refresh(db_image)
    return db_image
