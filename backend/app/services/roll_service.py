from fastapi import HTTPException
from sqlalchemy.orm import Session, joinedload
from sqlalchemy import func
from ..db.models.roll import Roll, RollStatusEnum
from ..db.models.film_stock import FilmStock
from ..db.models.camera import UserCamera, Camera, UserLens, Lens
from ..db.models.image import Image
from ..db.schemas.roll import RollCreate, RollOutDashboard, RollMetaUpdate, RollDriveUrlUpdate
from ..core.config import settings

# Simple hex colors per brand for dashboard cards
_FILM_COLOR = {
    "Kodak": "#FFCC33",
    "Fujifilm": "#00AA55",
    "Ilford": "#333333",
    "default": "#cccccc",
}

def get_roll(db: Session, roll_id: str, user_id: str):
    return db.query(Roll).filter(Roll.id == roll_id, Roll.user_id == user_id).first()


def _build_roll_dashboard(r: Roll, db: Session) -> RollOutDashboard:
    """Build RollOutDashboard for a single Roll."""
    film = db.query(FilmStock).filter(FilmStock.id == r.film_stock_id).first()
    brand = film.brand if film else ""
    name = film.name if film else ""
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
    keys = [row.image_url for row in images if row.image_url]

    # Image.image_url is stored as a storage key (not a full URL). Convert it
    # to an HTTP URL so the Flutter gallery can render via Image.network.
    base_url = (settings.S3_ENDPOINT or "").rstrip("/")
    bucket = (settings.S3_BUCKET_NAME or "").strip()

    # Prefer public, no-auth URL (R2 dev) when configured.
    if getattr(settings, "R2_PUBLIC_BASE_URL", None):
        # R2 public base usually does NOT include the bucket name.
        # Our object keys are stored under `users/...`, so we must include the
        # bucket segment between the public base and the object key.
        public_base = settings.R2_PUBLIC_BASE_URL.rstrip("/")
        if bucket and not public_base.endswith("/" + bucket):
            url_base = f"{public_base}/{bucket}"
        else:
            url_base = public_base
    else:
        # If the endpoint already includes the bucket path (common for some R2 configs),
        # don't append bucket again.
        if bucket and base_url.endswith("/" + bucket):
            url_base = base_url.rstrip("/")
        else:
            url_base = (f"{base_url}/{bucket}").rstrip("/") if bucket else base_url.rstrip("/")

    # `k` is stored as a key like: users/<uid>/rolls/<roll_id>/<image_id>.jpg (no leading slash).
    # Avoid naive `replace("//","/")` because it breaks the `https://` scheme.
    # Only render images stored via our storage uploader:
    # keys look like `users/<uid>/rolls/<roll_id>/<image_id>.jpg`.
    image_urls = []
    for k in keys:
        if not isinstance(k, str):
            continue
        if k.startswith("users/"):
            image_urls.append(f"{url_base}/{k}".rstrip("/"))
        elif k.startswith("/") or k.startswith("http://") or k.startswith("https://"):
            # Local path reference or full public URL
            image_urls.append(k)

    # Apply shot_offset shift for alignment calibration
    # Moves the first N frames to the end of the list.
    if r.shot_offset and r.shot_offset > 0 and len(image_urls) > 0:
        offset = r.shot_offset % len(image_urls)
        image_urls = image_urls[offset:] + image_urls[:offset]

    total_frames = (r.max_frames if r.max_frames is not None else 36)
    actual_frames = len(image_urls)
    return RollOutDashboard(
        id=str(r.id),
        brand=brand,
        name=name,
        color=color,
        status=r.status.value,
        image_urls=image_urls,
        shots=images,
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


def log_shot(db: Session, roll_id: str, aperture: float, shutter_speed: str, lat: float, lng: float, user_id: str):
    db_roll = get_roll(db, roll_id, user_id)
    if not db_roll:
        raise HTTPException(status_code=404, detail="Roll not found")

    # Get current max frame number
    max_frame = db.query(func.max(Image.frame_number)).filter(Image.roll_id == str(roll_id)).scalar()
    start_frame = (max_frame + 1) if max_frame is not None else 0

    db_image = Image(
        roll_id=str(roll_id),
        frame_number=start_frame,
        image_url=None,  # This is a log-only entry
        aperture=aperture,
        shutter_speed=shutter_speed,
        location_lat=lat,
        location_lng=lng
    )
    db.add(db_image)
    db.commit()
    db.refresh(db_image)
    return db_image
