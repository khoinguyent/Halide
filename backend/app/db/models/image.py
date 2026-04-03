from sqlalchemy import Column, Integer, String, Float, ForeignKey, text, DateTime
from sqlalchemy.dialects.postgresql import UUID
from ..base import Base

class Image(Base):
    __tablename__ = "images"
    id = Column(UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    roll_id = Column(UUID(as_uuid=True), ForeignKey("rolls.id"))
    frame_number = Column(Integer)
    image_url = Column(String, nullable=True)
    aperture = Column(Float)
    shutter_speed = Column(String(20))
    notes = Column(String)
    location_lat = Column(Float)
    location_lng = Column(Float)
    created_at = Column(DateTime, server_default=text('NOW()'))
