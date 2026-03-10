from sqlalchemy import Column, Integer, String, Float, ForeignKey, DateTime, Enum, text, CheckConstraint
from sqlalchemy.orm import relationship
from sqlalchemy.dialects.postgresql import UUID, JSONB
import enum
from database import Base

class FormatEnum(str, enum.Enum):
    format_135 = '135/35mm'
    format_120 = '120/Medium Format'
    format_large = 'Large Format'

class ColorTypeEnum(str, enum.Enum):
    color_negative = 'Color Negative'
    b_w = 'B&W'
    slide = 'Slide'

class CameraTypeEnum(str, enum.Enum):
    slr = 'SLR'
    tlr = 'TLR'
    rangefinder = 'Rangefinder'
    point_shoot = 'Point & Shoot'
    view_camera = 'View Camera'

class RollStatusEnum(str, enum.Enum):
    shooting = 'Shooting'
    finished = 'Finished Shooting'
    at_lab = 'At Lab'
    result_received = 'Result Received'

class User(Base):
    __tablename__ = "users"
    id = Column(String(255), primary_key=True)
    email = Column(String(255), unique=True, nullable=False)
    display_name = Column(String(255))
    avatar_url = Column(String)
    created_at = Column(DateTime, server_default=text('NOW()'))

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

class Camera(Base):
    __tablename__ = "cameras"
    id = Column(UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    brand = Column(String(100), nullable=False)
    model = Column(String(100), nullable=False)
    camera_type = Column(Enum(CameraTypeEnum), nullable=False)
    description = Column(String)
    best_practice = Column(String)
    image_urls = Column(JSONB)

class UserCamera(Base):
    __tablename__ = "user_cameras"
    id = Column(UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    user_id = Column(String(255), ForeignKey("users.id"))
    camera_id = Column(UUID(as_uuid=True), ForeignKey("cameras.id"))
    rating_functional = Column(Integer, CheckConstraint('rating_functional BETWEEN 1 AND 10'))
    rating_view = Column(Integer, CheckConstraint('rating_view BETWEEN 1 AND 10'))
    rating_looking = Column(Integer, CheckConstraint('rating_looking BETWEEN 1 AND 10'))
    created_at = Column(DateTime, server_default=text('NOW()'))

class Roll(Base):
    __tablename__ = "rolls"
    id = Column(UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    user_id = Column(String(255), ForeignKey("users.id"))
    film_stock_id = Column(UUID(as_uuid=True), ForeignKey("film_stocks.id"))
    user_camera_id = Column(UUID(as_uuid=True), ForeignKey("user_cameras.id"))
    shot_at_iso = Column(Integer)
    expired_year = Column(Integer)
    status = Column(Enum(RollStatusEnum), server_default='shooting')
    created_at = Column(DateTime, server_default=text('NOW()'))

class Image(Base):
    __tablename__ = "images"
    id = Column(UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    roll_id = Column(UUID(as_uuid=True), ForeignKey("rolls.id"))
    frame_number = Column(Integer)
    image_url = Column(String, nullable=False)
    aperture = Column(Float)
    shutter_speed = Column(String(20))
    notes = Column(String)
