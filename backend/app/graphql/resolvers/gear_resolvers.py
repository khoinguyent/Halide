from strawberry.types import Info
from typing import List
from ...services import gear_service
from ...graphql.types import UserCameraType, UserLensType

def resolve_user_gear(root, info: Info) -> List[UserCameraType]:
    db = info.context["db"]
    user = info.context["user"]
    gear = gear_service.get_user_cameras(db, user_id=user.id)
    return [
        UserCameraType(
            id=g.id,
            user_id=g.user_id,
            camera_id=g.camera_id,
            gear_nickname=g.gear_nickname,
            rating_functional=g.rating_functional,
            rating_view=g.rating_view,
            rating_looking=g.rating_looking,
            created_at=g.created_at,
            lenses=[
                UserLensType(
                    id=l.id,
                    user_id=l.user_id,
                    lens_id=l.lens_id,
                    parent_camera_id=l.parent_camera_id,
                    gear_nickname=l.gear_nickname,
                    created_at=l.created_at
                ) for l in g.lenses
            ]
        ) for g in gear
    ]
