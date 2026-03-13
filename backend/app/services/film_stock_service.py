from sqlalchemy.orm import Session
from ..db.models.film_stock import FilmStock

def get_film_stocks(db: Session, skip: int = 0, limit: int = 100):
    return db.query(FilmStock).offset(skip).limit(limit).all()
