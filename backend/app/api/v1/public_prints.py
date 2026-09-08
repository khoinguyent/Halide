"""Unauthenticated public print viewer + media proxy (mounted at /p)."""
from pathlib import Path

from fastapi import APIRouter, Depends, Request
from fastapi.responses import HTMLResponse, PlainTextResponse, Response
from jinja2 import Environment, FileSystemLoader, select_autoescape
from sqlalchemy.orm import Session

from ...db.session import get_db
from ...services import print_service

router = APIRouter()

_WEB_DIR = Path(__file__).resolve().parent.parent.parent / "web_templates"
_jinja = Environment(
    loader=FileSystemLoader(str(_WEB_DIR)),
    autoescape=select_autoescape(enabled_extensions=("html", "xml")),
    auto_reload=True,
)


def _request_base(request: Request) -> str:
    from ...core.config import settings

    configured = getattr(settings, "PUBLIC_WEB_BASE_URL", None)
    if configured and str(configured).strip():
        return str(configured).rstrip("/")
    return str(request.base_url).rstrip("/")


@router.get("/{token}", response_class=HTMLResponse)
def view_print(token: str, request: Request, db: Session = Depends(get_db)):
    row = print_service.get_active_print(db, token)
    data = print_service.to_public_out(row, request_base=_request_base(request))
    papers = {
        "cream": "#f3ebd8",
        "white": "#f7f7f5",
        "kraft": "#c4a574",
    }
    tpl = _jinja.get_template("print_viewer.html")
    html = tpl.render(
        note=data.note,
        font_style=data.font_style,
        font_size=data.font_size,
        text_color=data.text_color,
        text_align=data.text_align,
        pos_x=data.pos_x,
        pos_y=data.pos_y,
        layers=[layer.model_dump() for layer in data.layers],
        paper_bg=papers.get(data.paper_style, papers["cream"]),
        sender_name=data.sender_display_name or "Someone",
        image_url=data.image_url,
        note_download_url=data.note_download_url,
        expires_at=data.expires_at.strftime("%Y-%m-%d") if data.expires_at else "",
        public_token=data.public_token,
    )
    return HTMLResponse(content=html)


@router.get("/{token}/image")
def print_image(token: str, db: Session = Depends(get_db)):
    row = print_service.get_active_print(db, token)
    data, ctype = print_service.load_print_image_bytes(row)
    return Response(
        content=data,
        media_type=ctype,
        headers={
            "Cache-Control": "public, max-age=86400",
            "Content-Disposition": f'inline; filename="halide_print_{token[:8]}.jpg"',
        },
    )


@router.get("/{token}/qr.png")
def print_qr_png(token: str, request: Request, db: Session = Depends(get_db)):
    row = print_service.get_active_print(db, token)
    public_url = print_service.public_url_for_token(token, request_base=_request_base(request))
    png = print_service.load_print_qr_png(row, public_url)
    return Response(
        content=png,
        media_type="image/png",
        headers={
            "Cache-Control": "public, max-age=86400",
            "Content-Disposition": f'inline; filename="halide_print_{token[:8]}_qr.png"',
        },
    )


@router.get("/{token}/note.txt")
def print_note_txt(token: str, db: Session = Depends(get_db)):
    row = print_service.get_active_print(db, token)
    data = print_service.to_public_out(row)
    if data.layers:
        body = "\n\n".join(layer.text for layer in data.layers).strip() + "\n"
    else:
        body = (row.note_text or "").strip() + "\n"
    return PlainTextResponse(
        content=body,
        media_type="text/plain; charset=utf-8",
        headers={
            "Content-Disposition": f'attachment; filename="halide_note_{token[:8]}.txt"',
        },
    )
