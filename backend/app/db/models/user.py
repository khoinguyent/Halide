from sqlalchemy import Column, String, DateTime, Boolean, text, BigInteger, func
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
    has_seen_onboarding = Column(Boolean, default=False, server_default=text("false"), nullable=False)
    has_seen_roll_guide = Column(Boolean, default=False, server_default=text("false"), nullable=False)
    has_seen_lab_guide = Column(Boolean, default=False, server_default=text("false"), nullable=False)

    @validates('subscription_tier')
    def validate_subscription_tier(self, key, value):
        if value == 'pro':
            self.storage_limit_bytes = PRO_STORAGE_LIMIT
        else:
            # Plus and Free both use the base limit (100MB) for metadata/thumbs
            self.storage_limit_bytes = FREE_STORAGE_LIMIT
        return value

    @property
    def total_storage_limit(self) -> int:
        return (self.storage_limit_bytes or 0) + (self.additional_storage_bytes or 0)

    created_at = Column(DateTime, server_default=func.now() if hasattr(func, 'now') else text('NOW()'))

class PurchaseHistory(Base):
    __tablename__ = "purchase_history"
    id = Column(BigInteger, primary_key=True, autoincrement=True)
    user_id = Column(String(255), index=True)
    event_type = Column(String(100))
    product_id = Column(String(255), nullable=True)
    transaction_id = Column(String(255), nullable=True)
    # From RevenueCat webhook `event` (Apple / RC identifiers for dedupe and audits).
    original_transaction_id = Column(String(255), nullable=True)
    rc_event_id = Column(String(255), nullable=True)
    payload = Column(String)  # Store raw JSON string
    created_at = Column(DateTime, server_default=func.now() if hasattr(func, 'now') else text('NOW()'))

