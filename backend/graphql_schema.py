import strawberry
from typing import List, Optional
from uuid import UUID
from datetime import datetime
from sqlalchemy.orm import Session
from fastapi import Depends
import models
from database import get_db
from strawberry.fastapi import BaseContext
from auth import get_current_user

class Context(BaseContext):
    def __init__(self, db: Session, user: models.User):
        self.db = db
        self.user = user

async def get_context(
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user)
) -> Context:
    return Context(db=db, user=user)

@strawberry.enum
class FormatEnum(strawberry.Enum):
    format_135 = '135/35mm'
    format_120 = '120/Medium Format'
    format_large = 'Large Format'

@strawberry.enum
class ColorTypeEnum(strawberry.Enum):
    color_negative = 'Color Negative'
    b_w = 'B&W'
    slide = 'Slide'

@strawberry.enum
class CameraTypeEnum(strawberry.Enum):
    slr = 'SLR'
    tlr = 'TLR'
    rangefinder = 'Rangefinder'
    point_shoot = 'Point & Shoot'
    view_camera = 'View Camera'

@strawberry.enum
class RollStatusEnum(strawberry.Enum):
    shooting = 'Shooting'
    finished = 'Finished Shooting'
    at_lab = 'At Lab'
    result_received = 'Result Received'

@strawberry.type
class UserType:
    id: str
    email: str
    display_name: Optional[str]
    avatar_url: Optional[str]
    created_at: datetime

@strawberry.type
class FilmStockType:
    id: UUID
    brand: str
    name: str
    iso: int
    format: FormatEnum
    color_type: ColorTypeEnum
    description: Optional[str]
    best_practice: Optional[str]
    image_urls: Optional[List[str]]

@strawberry.type
class CameraType:
    id: UUID
    brand: str
    model: str
    camera_type: CameraTypeEnum
    description: Optional[str]
    best_practice: Optional[str]
    image_urls: Optional[List[str]]

@strawberry.type
class UserCameraType:
    id: UUID
    user_id: str
    camera_id: UUID
    camera: CameraType
    rating_functional: Optional[int]
    rating_view: Optional[int]
    rating_looking: Optional[int]
    created_at: datetime

    @strawberry.field
    def camera(self, info: strawberry.Info) -> CameraType:
        db = info.context.db
        camera_model = db.query(models.Camera).filter(models.Camera.id == self.camera_id).first()
        return CameraType(
            id=camera_model.id,
            brand=camera_model.brand,
            model=camera_model.model,
            camera_type=CameraTypeEnum(camera_model.camera_type.value),
            description=camera_model.description,
            best_practice=camera_model.best_practice,
            image_urls=camera_model.image_urls
        )

@strawberry.type
class RollType:
    id: UUID
    user_id: str
    film_stock_id: UUID
    user_camera_id: UUID
    shot_at_iso: Optional[int]
    expired_year: Optional[int]
    status: RollStatusEnum
    created_at: datetime

@strawberry.type
class Query:
    @strawberry.field
    def film_stocks(self, info: strawberry.Info) -> List[FilmStockType]:
        db = info.context.db
        stocks = db.query(models.FilmStock).all()
        return [
            FilmStockType(
                id=s.id,
                brand=s.brand,
                name=s.name,
                iso=s.iso,
                format=FormatEnum(s.format.value),
                color_type=ColorTypeEnum(s.color_type.value),
                description=s.description,
                best_practice=s.best_practice,
                image_urls=s.image_urls
            ) for s in stocks
        ]

    @strawberry.field
    def user_gear(self, info: strawberry.Info) -> List[UserCameraType]:
        db = info.context.db
        user = info.context.user
        gear = db.query(models.UserCamera).filter(models.UserCamera.user_id == user.id).all()
        return [
            UserCameraType(
                id=g.id,
                user_id=g.user_id,
                camera_id=g.camera_id,
                rating_functional=g.rating_functional,
                rating_view=g.rating_view,
                rating_looking=g.rating_looking,
                created_at=g.created_at,
                camera=None # Resolved by the field resolver
            ) for g in gear
        ]

schema = strawberry.Schema(query=Query)
