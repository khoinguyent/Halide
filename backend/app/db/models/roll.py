import enum
from sqlalchemy import Column, Integer, String, Enum, ForeignKey, DateTime, text
from sqlalchemy.dialects.postgresql import UUID
from ..base import Base

class RollStatusEnum(str, enum.Enum):
    shooting = 'Shooting'
    finished = 'Finished Shooting'
    at_lab = 'At Lab'
    result_received = 'Result Received'

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
