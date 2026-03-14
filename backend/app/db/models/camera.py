import enum
from sqlalchemy import Column, Integer, String, Enum, ForeignKey, DateTime, text, CheckConstraint, Float
from sqlalchemy.dialects.postgresql import UUID, JSONB
from ..base import Base

class CameraTypeEnum(str, enum.Enum):
    slr = 'SLR'
    tlr = 'TLR'
    rangefinder = 'Rangefinder'
    point_shoot = 'Point & Shoot'
    view_camera = 'View Camera'

from sqlalchemy.orm import relationship

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
    gear_nickname = Column(String(255))
    rating_functional = Column(Integer, CheckConstraint('rating_functional BETWEEN 1 AND 10'))
    rating_view = Column(Integer, CheckConstraint('rating_view BETWEEN 1 AND 10'))
    rating_looking = Column(Integer, CheckConstraint('rating_looking BETWEEN 1 AND 10'))
    created_at = Column(DateTime, server_default=text('NOW()'))

    # Relationships
    camera = relationship("Camera", foreign_keys=[camera_id])
    lenses = relationship("UserLens", back_populates="parent_camera", cascade="all, delete-orphan")

class Lens(Base):
    __tablename__ = "lenses"
    id = Column(UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    brand = Column(String(100), nullable=False)
    model = Column(String(100), nullable=False)
    # DB column focal_length may be varchar in some DBs
    focal_length_mm = Column("focal_length", String(20), nullable=True)
    max_aperture = Column("max_aperture", String(20), nullable=True)  # DB may be varchar
    description = Column(String)
    image_urls = Column(JSONB)

class UserLens(Base):
    __tablename__ = "user_lenses"
    id = Column(UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    user_id = Column(String(255), ForeignKey("users.id"))
    lens_id = Column(UUID(as_uuid=True), ForeignKey("lenses.id"))
    parent_camera_id = Column(UUID(as_uuid=True), ForeignKey("user_cameras.id"), nullable=True)
    gear_nickname = Column(String(255))
    serial_number = Column(String(100))
    notes = Column(String)
    created_at = Column(DateTime, server_default=text('NOW()'))

    # Relationships
    parent_camera = relationship("UserCamera", back_populates="lenses")
