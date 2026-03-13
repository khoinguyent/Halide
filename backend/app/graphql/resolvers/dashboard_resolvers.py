from strawberry.types import Info
from ...db.models.user import User as UserModel
from ...db.models.camera import UserCamera as UserCameraModel
from ...db.models.roll import Roll as RollModel
from ...graphql.types import UserDashboardType, UserType, UserCameraType, RollType, RollStatusEnumGQL

def resolve_user_dashboard(root, info: Info) -> UserDashboardType:
    db = info.context["db"]
    user_model = info.context["user"]
    
    # User Profile
    user_type = UserType(
        id=user_model.id,
        email=user_model.email,
        display_name=user_model.display_name,
        avatar_url=user_model.avatar_url,
        created_at=user_model.created_at
    )

    # User Cameras (Gear)
    gear_models = db.query(UserCameraModel).filter(UserCameraModel.user_id == user_model.id).all()
    cameras = [
        UserCameraType(
            id=g.id,
            user_id=g.user_id,
            camera_id=g.camera_id,
            rating_functional=g.rating_functional,
            rating_view=g.rating_view,
            rating_looking=g.rating_looking,
            created_at=g.created_at
        ) for g in gear_models
    ]

    # Recent Rolls (last 30)
    roll_models = db.query(RollModel).filter(
        RollModel.user_id == user_model.id
    ).order_by(RollModel.created_at.desc()).limit(30).all()
    
    recent_rolls = [
        RollType(
            id=r.id,
            user_id=r.user_id,
            film_stock_id=r.film_stock_id,
            user_camera_id=r.user_camera_id,
            shot_at_iso=r.shot_at_iso,
            expired_year=r.expired_year,
            status=RollStatusEnumGQL(r.status.value),
            created_at=r.created_at
        ) for r in roll_models
    ]

    return UserDashboardType(
        user=user_type,
        cameras=cameras,
        recent_rolls=recent_rolls
    )
