from fastapi import HTTPException
from sqlalchemy.orm import Session, joinedload
from sqlalchemy import func
from ..db.models.roll import Roll, RollStatusEnum
from ..db.models.film_stock import FilmStock
from ..db.models.camera import UserCamera, Camera, UserLens, Lens
from ..db.models.image import Image
from ..db.schemas.roll import RollCreate, RollOutDashboard

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
    images = db.query(Image.image_url).filter(Image.roll_id == r.id).order_by(Image.frame_number).all()
    image_urls = [row[0] for row in images]
    total_frames = (r.max_frames if r.max_frames is not None else 36)
    actual_frames = len(image_urls)
    return RollOutDashboard(
        id=str(r.id),
        brand=brand,
        name=name,
        color=color,
        status=r.status.value,
        image_urls=image_urls,
        nickname=None,
        camera_name=camera_name,
        lens_name=lens_name,
        frame_count=actual_frames,
        max_frames=total_frames,
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
