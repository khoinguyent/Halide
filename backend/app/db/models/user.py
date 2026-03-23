from sqlalchemy import Column, String, DateTime, text, BigInteger, func
from sqlalchemy.orm import validates
from ..base import Base

FREE_STORAGE_LIMIT = 100 * 1024 * 1024  # 100MB
PRO_STORAGE_LIMIT = 5 * 1024 * 1024 * 1024  # 5GB

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
    # The 'storage_limit_bytes' is the base tier limit. 
    # The effective limit is storage_limit_bytes + additional_storage_bytes.
    storage_limit_bytes = Column(BigInteger, default=FREE_STORAGE_LIMIT, server_default=text(str(FREE_STORAGE_LIMIT)))
    additional_storage_bytes = Column(BigInteger, default=0, server_default=text("0"))

    @validates('subscription_tier')
    def validate_subscription_tier(self, key, value):
        if value == 'pro':
            self.storage_limit_bytes = PRO_STORAGE_LIMIT
        elif value == 'plus':
            self.storage_limit_bytes = 1 * 1024 * 1024 * 1024 # 1GB for Plus
        else:
            self.storage_limit_bytes = FREE_STORAGE_LIMIT
        return value

    @property
    def total_storage_limit(self) -> int:
        return (self.storage_limit_bytes or 0) + (self.additional_storage_bytes or 0)

    created_at = Column(DateTime, server_default=func.now() if hasattr(func, 'now') else text('NOW()'))

