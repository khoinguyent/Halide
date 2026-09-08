from datetime import datetime
from typing import List, Literal, Optional
from uuid import UUID

from pydantic import BaseModel, EmailStr, Field, field_validator, model_validator


TextAlign = Literal["left", "center", "right"]
PaperStyle = Literal["cream", "white", "kraft"]


def normalize_font_style(v: str) -> str:
    raw = (v or "hand").strip().lower()
    parts = [p for p in raw.split("_") if p]
    if not parts:
        return "hand"
    family = parts[0] if parts[0] in ("hand", "type") else "hand"
    bold = "b" in parts[1:] or "bold" in parts[1:]
    italic = "i" in parts[1:] or "italic" in parts[1:]
    out = [family]
    if bold:
        out.append("b")
    if italic:
        out.append("i")
    return "_".join(out)


class QrStampCrop(BaseModel):
    """Square crop from the print photo used as the face of an artistic QR.

    center_x / center_y are relative to the full source image (0–1).
    size is the square side relative to min(image_width, image_height).
    Suggested range: 0.18–0.42 (default ~0.28).
    """

    center_x: float = Field(..., ge=0, le=1)
    center_y: float = Field(..., ge=0, le=1)
    size: float = Field(..., ge=0.12, le=0.55)


class PrintLayerIn(BaseModel):
    text: str = Field(..., min_length=1, max_length=2000)
    font_style: str = Field("hand", max_length=32)
    font_size: float = Field(28, ge=12, le=72)
    text_color: str = Field("#2c2416", max_length=32)
    text_align: TextAlign = "center"
    pos_x: float = Field(0.5, ge=0, le=1)
    pos_y: float = Field(0.4, ge=0, le=1)

    @field_validator("text")
    @classmethod
    def strip_text(cls, v: str) -> str:
        t = (v or "").strip()
        if not t:
            raise ValueError("Layer text cannot be empty")
        return t

    @field_validator("font_style")
    @classmethod
    def norm_font(cls, v: str) -> str:
        return normalize_font_style(v)


class PrintCreate(BaseModel):
    image_id: UUID
    # Legacy single-note fields (still accepted; layers preferred).
    note: Optional[str] = Field(None, max_length=2000)
    font_style: str = Field("hand", max_length=32)
    font_size: float = Field(22, ge=12, le=72)
    text_color: str = Field("#2c2416", max_length=32)
    text_align: TextAlign = "left"
    pos_x: float = Field(0.1, ge=0, le=1)
    pos_y: float = Field(0.15, ge=0, le=1)
    paper_style: PaperStyle = "cream"
    recipient_emails: List[EmailStr] = Field(default_factory=list, max_length=10)
    expire_days: int = Field(30, ge=1, le=30)
    send_email: bool = True
    from_name: Optional[str] = Field(None, max_length=80)
    layers: List[PrintLayerIn] = Field(default_factory=list, max_length=12)
    qr_stamp: Optional[QrStampCrop] = None

    @field_validator("from_name")
    @classmethod
    def strip_from_name(cls, v: Optional[str]) -> Optional[str]:
        if v is None:
            return None
        t = v.strip()
        return t or None

    @field_validator("font_style")
    @classmethod
    def norm_font(cls, v: str) -> str:
        return normalize_font_style(v)

    @field_validator("recipient_emails")
    @classmethod
    def normalize_emails(cls, v: List[EmailStr]) -> List[str]:
        seen = set()
        out: List[str] = []
        for e in v or []:
            low = str(e).strip().lower()
            if low and low not in seen:
                seen.add(low)
                out.append(low)
        return out

    @model_validator(mode="after")
    def ensure_content(self) -> "PrintCreate":
        layers = list(self.layers or [])
        note = (self.note or "").strip()
        if not layers and note:
            layers = [
                PrintLayerIn(
                    text=note,
                    font_style=self.font_style,
                    font_size=self.font_size,
                    text_color=self.text_color,
                    text_align=self.text_align,
                    pos_x=self.pos_x,
                    pos_y=self.pos_y,
                )
            ]
            object.__setattr__(self, "layers", layers)
        if not layers:
            raise ValueError("Add at least one text note on the back")
        # Keep note_text populated for email preview / .txt download.
        joined = "\n\n".join(layer.text for layer in layers)
        object.__setattr__(self, "note", joined[:2000])
        # Mirror first layer into legacy columns for older viewers.
        first = layers[0]
        object.__setattr__(self, "font_style", first.font_style)
        object.__setattr__(self, "font_size", first.font_size)
        object.__setattr__(self, "text_color", first.text_color)
        object.__setattr__(self, "text_align", first.text_align)
        object.__setattr__(self, "pos_x", first.pos_x)
        object.__setattr__(self, "pos_y", first.pos_y)
        return self


class PrintCreateOut(BaseModel):
    id: UUID
    public_token: str
    public_url: str
    expires_at: datetime
    emails_sent: int
    email_failed: int = 0


class PrintLayerOut(BaseModel):
    text: str
    font_style: str
    font_size: float
    text_color: str
    text_align: str
    pos_x: float
    pos_y: float


class PrintPublicOut(BaseModel):
    public_token: str
    note: str
    font_style: str
    font_size: float
    text_color: str
    text_align: str
    pos_x: float
    pos_y: float
    paper_style: str
    layers: List[PrintLayerOut] = Field(default_factory=list)
    sender_display_name: Optional[str] = None
    image_url: str
    note_download_url: str
    expires_at: datetime
    created_at: datetime
