from strawberry.types import Info
from typing import List
from ...services import film_stock_service
from ...graphql.types import FilmStockType, FormatEnum, ColorTypeEnum

def resolve_film_stocks(root, info: Info) -> List[FilmStockType]:
    db = info.context["db"]
    stocks = film_stock_service.get_film_stocks(db)
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
