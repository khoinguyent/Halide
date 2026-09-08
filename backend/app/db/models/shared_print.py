from sqlalchemy import Column, String, Float, ForeignKey, DateTime, Text, text
from sqlalchemy.dialects.postgresql import UUID, JSONB
from ..base import Base


class SharedPrint(Base):
    """
    A one-sided photo + verso note shared via unlisted public URL (and optional email).
    Max lifetime is enforced in the service layer (30 days).
    """

    __tablename__ = "shared_prints"

    id = Column(UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    public_token = Column(String(64), unique=True, nullable=False, index=True)
    user_id = Column(String(255), ForeignKey("users.id"), nullable=False, index=True)
    image_id = Column(UUID(as_uuid=True), ForeignKey("images.id"), nullable=False)
    roll_id = Column(UUID(as_uuid=True), ForeignKey("rolls.id"), nullable=False)

    # R2/S3 object key (or legacy URL) so the public page can proxy for the full TTL.
    image_storage_key = Column(String, nullable=False)

    note_text = Column(Text, nullable=False, server_default=text("''"))
    font_style = Column(String(32), nullable=False, server_default=text("'hand'"))  # hand | type + optional _b / _i
    font_size = Column(Float, nullable=False, server_default=text("22"))
    text_color = Column(String(32), nullable=False, server_default=text("'#2c2416'"))
    text_align = Column(String(16), nullable=False, server_default=text("'left'"))  # left | center | right
    pos_x = Column(Float, nullable=False, server_default=text("0.1"))  # 0–1 relative
    pos_y = Column(Float, nullable=False, server_default=text("0.15"))
    paper_style = Column(String(16), nullable=False, server_default=text("'cream'"))  # cream | white | kraft

    # Multi-text verso stickers: [{text, font_style, font_size, text_color, text_align, pos_x, pos_y}, ...]
    layers = Column(JSONB, nullable=False, server_default=text("'[]'::jsonb"))

    # Optional square stamp crop used to render an image-style QR (center + size vs min side).
    qr_stamp_x = Column(Float, nullable=True)
    qr_stamp_y = Column(Float, nullable=True)
    qr_stamp_size = Column(Float, nullable=True)
    # Cached artistic (or plain) QR PNG in object storage.
    qr_storage_key = Column(String, nullable=True)

    recipient_emails = Column(JSONB, nullable=False, server_default=text("'[]'::jsonb"))
    sender_display_name = Column(String(255), nullable=True)

    created_at = Column(DateTime, server_default=text("NOW()"), nullable=False)
    expires_at = Column(DateTime, nullable=False)
    revoked_at = Column(DateTime, nullable=True)
