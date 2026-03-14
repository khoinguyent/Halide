from sqlalchemy import Column, String, DateTime, text
from ..base import Base

class User(Base):
    __tablename__ = "users"
    id = Column(String(255), primary_key=True)
    email = Column(String(255), unique=True, nullable=True)
    display_name = Column(String(255))
    avatar_url = Column(String)
    professional_nickname = Column(String(255), nullable=True)
    bio = Column(String, nullable=True)
    created_at = Column(DateTime, server_default=text('NOW()'))
