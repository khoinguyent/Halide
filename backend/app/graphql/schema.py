from datetime import datetime
from typing import List, Optional
from uuid import UUID
import strawberry
from .types import UserType, UserCameraType, RollType, UserDashboardType, FilmStockType
from .resolvers.film_stock_resolvers import resolve_film_stocks
from .resolvers.gear_resolvers import resolve_user_gear
from .resolvers.dashboard_resolvers import resolve_user_dashboard
from fastapi import Depends
from ..core.dependencies import get_current_user
from ..db.session import get_db

@strawberry.type
class Query:
    film_stocks: List[FilmStockType] = strawberry.field(resolver=resolve_film_stocks)
    user_gear: List[UserCameraType] = strawberry.field(resolver=resolve_user_gear)
    user_dashboard: UserDashboardType = strawberry.field(resolver=resolve_user_dashboard)

schema = strawberry.Schema(query=Query)

async def get_context(
    db=Depends(get_db),
    user=Depends(get_current_user)
):
    return {"db": db, "user": user}
