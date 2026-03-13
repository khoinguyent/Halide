from strawberry.types import Info
from ...services import dashboard_service
from ...graphql.types import UserDashboardType, UserType, UserCameraType, UserLensType, RollType, RollStatusEnumGQL

def resolve_user_dashboard(root, info: Info) -> UserDashboardType:
    db = info.context["db"]
    user_model = info.context["user"]
    
    dashboard_data = dashboard_service.get_user_dashboard(db, user_id=user_model.id)
    user_model = dashboard_data["user"]
    
    # User Profile
    user_type = UserType(
        id=user_model.id,
        email=user_model.email,
        display_name=user_model.display_name,
        avatar_url=user_model.avatar_url,
        created_at=user_model.created_at
    )

    # User Cameras (Gear)
    cameras = [
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
        ) for g in dashboard_data["cameras"]
    ]

    # Recent Rolls
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
        ) for r in dashboard_data["recent_rolls"]
    ]

    return UserDashboardType(
        user=user_type,
        cameras=cameras,
        recent_rolls=recent_rolls
    )
