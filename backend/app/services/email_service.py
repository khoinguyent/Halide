"""
Transactional email via Gmail.

Preferred path: Gmail API over HTTPS (works on DigitalOcean where SMTP is blocked).
Fallback: Gmail SMTP + App Password.

Configure in backend/.env (and .env.staging / .env.prod):
    EMAIL_USER=halide.app.notify@gmail.com
    EMAIL_FROM_ADDRESS=support@halide.io.vn
    EMAIL_FROM_NAME=AgXel Vault
    GOOGLE_CLIENT_ID=...          # existing Web OAuth client
    GOOGLE_CLIENT_SECRET=...
    GMAIL_REFRESH_TOKEN=...       # from: python -m scripts.gmail_oauth_setup
    EMAIL_APP_PASSWORD=...        # optional SMTP fallback
"""
from __future__ import annotations

import base64
import logging
import smtplib
from email.mime.image import MIMEImage
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from typing import List, Optional, Tuple

logger = logging.getLogger(__name__)
from .email_template_service import email_templates

GMAIL_SEND_SCOPE = "https://www.googleapis.com/auth/gmail.send"
APP_STORE_URL = "https://apps.apple.com/vn/app/agxel-vault/id6761399152"

# (content_id without brackets, png/jpeg bytes, subtype, filename)
InlineImage = Tuple[str, bytes, str, str]


def _settings():
    from ..core.config import settings
    return settings


def is_gmail_api_configured() -> bool:
    s = _settings()
    return bool(
        s.GOOGLE_CLIENT_ID
        and s.GOOGLE_CLIENT_SECRET
        and s.GMAIL_REFRESH_TOKEN
        and s.EMAIL_USER
    )


def is_smtp_configured() -> bool:
    s = _settings()
    return bool(s.EMAIL_USER and s.EMAIL_APP_PASSWORD)


def is_email_configured() -> bool:
    return is_gmail_api_configured() or is_smtp_configured()


def _from_header() -> str:
    s = _settings()
    addr = s.EMAIL_FROM_ADDRESS or s.EMAIL_USER or ""
    name = s.EMAIL_FROM_NAME or "AgXel Vault"
    return f"{name} <{addr}>"


def _build_message(
    to: str,
    subject: str,
    html: str,
    text: Optional[str] = None,
    inline_images: Optional[List[InlineImage]] = None,
) -> MIMEMultipart:
    if inline_images:
        # multipart/related so clients can render cid: attachments inline
        msg = MIMEMultipart("related")
        msg["Subject"] = subject
        msg["From"] = _from_header()
        msg["To"] = to
        alt = MIMEMultipart("alternative")
        if text:
            alt.attach(MIMEText(text, "plain", "utf-8"))
        alt.attach(MIMEText(html, "html", "utf-8"))
        msg.attach(alt)
        for cid, data, subtype, filename in inline_images:
            part = MIMEImage(data, _subtype=subtype)
            part.add_header("Content-ID", f"<{cid}>")
            part.add_header("Content-Disposition", "inline", filename=filename)
            msg.attach(part)
        return msg

    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"] = _from_header()
    msg["To"] = to
    if text:
        msg.attach(MIMEText(text, "plain", "utf-8"))
    msg.attach(MIMEText(html, "html", "utf-8"))
    return msg


def _send_via_gmail_api(msg: MIMEMultipart, to: str, subject: str) -> bool:
    """Send using Gmail API (HTTPS). Auth as EMAIL_USER via refresh token."""
    from google.auth.transport.requests import Request
    from google.oauth2.credentials import Credentials
    from googleapiclient.discovery import build

    s = _settings()
    creds = Credentials(
        token=None,
        refresh_token=s.GMAIL_REFRESH_TOKEN,
        token_uri="https://oauth2.googleapis.com/token",
        client_id=s.GOOGLE_CLIENT_ID,
        client_secret=s.GOOGLE_CLIENT_SECRET,
        scopes=[GMAIL_SEND_SCOPE],
    )
    creds.refresh(Request())
    service = build("gmail", "v1", credentials=creds, cache_discovery=False)
    raw = base64.urlsafe_b64encode(msg.as_bytes()).decode("utf-8")
    service.users().messages().send(userId="me", body={"raw": raw}).execute()
    logger.info("[Email] Gmail API sent '%s' to %s", subject, to)
    return True


def _send_via_smtp(msg: MIMEMultipart, to: str, subject: str) -> bool:
    s = _settings()
    with smtplib.SMTP(s.EMAIL_HOST, s.EMAIL_PORT, timeout=15) as server:
        server.ehlo()
        server.starttls()
        server.ehlo()
        server.login(s.EMAIL_USER, s.EMAIL_APP_PASSWORD)
        server.sendmail(s.EMAIL_USER, to, msg.as_string())
    logger.info("[Email] SMTP sent '%s' to %s", subject, to)
    return True


def send_email(
    to: str,
    subject: str,
    html: str,
    text: Optional[str] = None,
    inline_images: Optional[List[InlineImage]] = None,
) -> bool:
    """
    Send a transactional email. Returns True on success, False on failure.
    When nothing is configured, logs a warning and returns True (no-op) so
    product flows are not blocked in local/dev without mail.
    """
    if not is_email_configured():
        logger.warning("[Email] Not configured — skipping send to %s", to)
        return True

    msg = _build_message(to, subject, html, text=text, inline_images=inline_images)

    if is_gmail_api_configured():
        try:
            return _send_via_gmail_api(msg, to, subject)
        except Exception as e:
            logger.exception("[Email] Gmail API failed '%s' to %s: %s", subject, to, e)
            if not is_smtp_configured():
                return False
            logger.warning("[Email] Falling back to SMTP for '%s'", subject)

    if is_smtp_configured():
        try:
            return _send_via_smtp(msg, to, subject)
        except Exception as e:
            logger.exception("[Email] SMTP failed '%s' to %s: %s", subject, to, e)
            return False

    return False


# --------------------------------------------------------------------------- #
# Pre-built templates
# --------------------------------------------------------------------------- #

def send_downgrade_warning(to: str, display_name: str, deletion_date: str) -> bool:
    subject = f"Your scans are kept until {deletion_date}"
    html = email_templates.render(
        "downgrade_warning.html",
        {
            "user_name": display_name or "there",
            "deletion_date": deletion_date,
        },
    )
    return send_email(to, subject, html)


def send_purge_complete(to: str, display_name: str) -> bool:
    subject = "Your AgXel Vault cloud storage has been cleared"
    html = f"""
    <p>Hi {display_name},</p>
    <p>As your Pro subscription has ended, your scans stored on AgXel Vault's servers
    have been permanently removed.</p>
    <p>Any photos you downloaded to your device are safe and unaffected.</p>
    <p>— AgXel Vault</p>
    <p style="margin-top:24px;font-size:12px;color:#666;">
      Know someone who shoots film?
      <a href="{APP_STORE_URL}">Download AgXel Vault on the App Store</a>
    </p>
    """
    return send_email(to, subject, html)


def send_export_zip_ready(to: str, display_name: str, roll_title: str, download_url: str) -> bool:
    subject = f"Your export is ready — {roll_title}"
    html = email_templates.render(
        "roll_export_ready.html",
        {
            "user_name": display_name or "there",
            "roll_name": roll_title or "your roll",
            "download_url": download_url or "",
            "expiry_days": "7 days",
        },
    )
    return send_email(to, subject, html)


def send_print_shared(
    to: str,
    sender_name: str,
    public_url: str,
    expire_days: int,
    qr_image_url: str,
    qr_png_bytes: Optional[bytes] = None,
) -> bool:
    """Email a shared postcard with a single center-stamp QR (CID inline when bytes given)."""
    subject = f"{sender_name or 'Someone'} sent you a postcard"
    # Prefer CID attachment when we have PNG bytes (shows without remote fetch).
    qr_src = "cid:print-qr" if qr_png_bytes else (qr_image_url or "")
    html = email_templates.render(
        "print_shared.html",
        {
            "sender_name": sender_name or "Someone",
            "public_url": public_url or "",
            "qr_image_url": qr_src,
            "expire_days": str(expire_days),
        },
    )
    text = (
        f"{sender_name or 'Someone'} sent you a postcard from AgXel Vault — "
        f"a photo on the front, a few words of love waiting on the back.\n\n"
        f"Open: {public_url}\n\n"
        f"This postcard link expires in {expire_days} days.\n\n"
        f"With love — AgXel Vault\n\n"
        f"Send your own postcards — get AgXel Vault free on the App Store:\n"
        f"{APP_STORE_URL}"
    )
    inline: Optional[List[InlineImage]] = None
    if qr_png_bytes:
        inline = [("print-qr", qr_png_bytes, "png", "agxel_vault_print_qr.png")]
    return send_email(to, subject, html, text=text, inline_images=inline)
