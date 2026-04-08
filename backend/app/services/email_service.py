"""
Transactional email via Gmail SMTP (App Password).
Configure in backend/.env:
    EMAIL_USER=halide.app.notify@gmail.com
    EMAIL_APP_PASSWORD=your16charapppassword
    EMAIL_FROM_ADDRESS=hello@halide.io.vn
    EMAIL_FROM_NAME=Halide
"""
from __future__ import annotations

import logging
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from typing import Optional

logger = logging.getLogger(__name__)
from .email_template_service import email_templates


def _settings():
    from ..core.config import settings
    return settings


def is_email_configured() -> bool:
    s = _settings()
    return bool(s.EMAIL_USER and s.EMAIL_APP_PASSWORD)


def _from_header() -> str:
    s = _settings()
    addr = s.EMAIL_FROM_ADDRESS or s.EMAIL_USER or ""
    name = s.EMAIL_FROM_NAME or "Halide"
    return f"{name} <{addr}>"


def send_email(
    to: str,
    subject: str,
    html: str,
    text: Optional[str] = None,
) -> bool:
    """
    Send a transactional email. Returns True on success, False on failure.
    Does nothing (returns True) when EMAIL_USER / EMAIL_APP_PASSWORD are not set.
    """
    if not is_email_configured():
        logger.warning("[Email] Not configured — skipping send to %s", to)
        return True

    s = _settings()
    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"] = _from_header()
    msg["To"] = to

    if text:
        msg.attach(MIMEText(text, "plain"))
    msg.attach(MIMEText(html, "html"))

    try:
        with smtplib.SMTP(s.EMAIL_HOST, s.EMAIL_PORT, timeout=15) as server:
            server.ehlo()
            server.starttls()
            server.ehlo()
            server.login(s.EMAIL_USER, s.EMAIL_APP_PASSWORD)
            server.sendmail(s.EMAIL_USER, to, msg.as_string())
        logger.info("[Email] Sent '%s' to %s", subject, to)
        return True
    except Exception as e:
        logger.exception("[Email] Failed to send '%s' to %s: %s", subject, to, e)
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
    subject = "Your Halide cloud storage has been cleared"
    html = f"""
    <p>Hi {display_name},</p>
    <p>As your Pro subscription has ended, your scans stored on Halide's servers
    have been permanently removed.</p>
    <p>Any photos you downloaded to your device are safe and unaffected.</p>
    <p>— The Halide Team</p>
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
