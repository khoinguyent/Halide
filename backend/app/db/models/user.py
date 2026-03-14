from sqlalchemy import Column, String, DateTime, text, BigInteger
from ..base import Base

class User(Base):
    __tablename__ = "users"
    id = Column(String(255), primary_key=True)
    email = Column(String(255), unique=True, nullable=True)
    display_name = Column(String(255))
    avatar_url = Column(String)
    professional_nickname = Column(String(255), nullable=True)
    bio = Column(String, nullable=True)
    
    subscription_tier = Column(String(50), default='free', server_default=text("'free'"))
    storage_used_bytes = Column(BigInteger, default=0, server_default=text("0"))
    storage_limit_bytes = Column(BigInteger, default=104857600, server_default=text("104857600")) # 100MB
    
    created_at = Column(DateTime, server_default=text('NOW()'))
