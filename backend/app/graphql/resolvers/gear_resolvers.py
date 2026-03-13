from strawberry.types import Info
from typing import List
from ...db.models.camera import UserCamera
from ...graphql.types import UserCameraType

def resolve_user_gear(root, info: Info) -> List[UserCameraType]:
    db = info.context["db"]
    user = info.context["user"]
    gear = db.query(UserCamera).filter(UserCamera.user_id == user.id).all()
    return [
        UserCameraType(
            id=g.id,
            user_id=g.user_id,
            camera_id=g.camera_id,
            rating_functional=g.rating_functional,
            rating_view=g.rating_view,
            rating_looking=g.rating_looking,
            created_at=g.created_at
        ) for g in gear
    ]
