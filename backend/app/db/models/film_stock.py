import enum
from sqlalchemy import Column, Integer, String, Enum, text
from sqlalchemy.dialects.postgresql import UUID, JSONB
from ..base import Base

class FormatEnum(str, enum.Enum):
    format_135 = '135/35mm'
    format_120 = '120/Medium Format'
    format_large = 'Large Format'

class ColorTypeEnum(str, enum.Enum):
    color_negative = 'Color Negative'
    b_w = 'B&W'
    slide = 'Slide'

class FilmStock(Base):
    __tablename__ = "film_stocks"
    id = Column(UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    brand = Column(String(100), nullable=False)
    name = Column(String(100), nullable=False)
    iso = Column(Integer, nullable=False)
    format = Column(Enum(FormatEnum), nullable=False)
    color_type = Column(Enum(ColorTypeEnum), nullable=False)
    description = Column(String)
    best_practice = Column(String)
    image_urls = Column(JSONB)
