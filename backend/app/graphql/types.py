import strawberry
import enum
from typing import List, Optional
from uuid import UUID
from datetime import datetime
from strawberry.types import Info
from ..db.models.camera import Camera, CameraTypeEnum

@strawberry.enum
class FormatEnum(enum.Enum):
    format_135 = '135/35mm'
    format_120 = '120/Medium Format'
    format_large = 'Large Format'

@strawberry.enum
class ColorTypeEnum(enum.Enum):
    color_negative = 'Color Negative'
    b_w = 'B&W'
    slide = 'Slide'

@strawberry.enum
class CameraTypeEnumGQL(enum.Enum):
    slr = 'SLR'
    tlr = 'TLR'
    rangefinder = 'Rangefinder'
    point_shoot = 'Point & Shoot'
    view_camera = 'View Camera'

@strawberry.enum
class RollStatusEnumGQL(enum.Enum):
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
    camera_type: CameraTypeEnumGQL
    description: Optional[str]
    best_practice: Optional[str]
    image_urls: Optional[List[str]]

@strawberry.type
class UserCameraType:
    id: UUID
    user_id: str
    camera_id: UUID
    rating_functional: Optional[int]
    rating_view: Optional[int]
    rating_looking: Optional[int]
    created_at: datetime

    @strawberry.field
    def camera(self, info: Info) -> CameraType:
        db = info.context["db"]
        camera_model = db.query(Camera).filter(Camera.id == self.camera_id).first()
        return CameraType(
            id=camera_model.id,
            brand=camera_model.brand,
            model=camera_model.model,
            camera_type=CameraTypeEnumGQL(camera_model.camera_type.value),
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
    status: RollStatusEnumGQL
    created_at: datetime

@strawberry.type
class UserDashboardType:
    user: UserType
    cameras: List[UserCameraType]
    recent_rolls: List[RollType]
