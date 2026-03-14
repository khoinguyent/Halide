"""
Google Drive API integration for personal cloud storage.
Uses stored OAuth tokens (from mobile serverAuthCode exchange) to list/upload files.
"""
import json
import logging
from typing import Optional, List, Dict, Any

from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
from googleapiclient.http import MediaIoBaseUpload
from googleapiclient.errors import HttpError

from ..core.config import settings

logger = logging.getLogger(__name__)

DRIVE_SCOPES = ["https://www.googleapis.com/auth/drive.file"]


def _is_configured() -> bool:
    return bool(settings.GOOGLE_CLIENT_ID and settings.GOOGLE_CLIENT_SECRET)


def exchange_server_auth_code(server_auth_code: str) -> Dict[str, Any]:
    """Exchange a one-time server auth code (from mobile) for access and refresh tokens."""
    if not _is_configured():
        raise RuntimeError("GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET must be set to connect Google Drive")
    try:
        from google_auth_oauthlib.flow import Flow
        flow = Flow.from_client_config(
            {
                "web": {
                    "client_id": settings.GOOGLE_CLIENT_ID,
                    "client_secret": settings.GOOGLE_CLIENT_SECRET,
                    "auth_uri": "https://accounts.google.com/o/oauth2/auth",
                    "token_uri": "https://oauth2.googleapis.com/token",
                    "redirect_uris": [],
                }
            },
            scopes=DRIVE_SCOPES,
        )
        flow.redirect_uri = "urn:ietf:wg:oauth:2.0:oob"
        tokens = flow.fetch_token(code=server_auth_code)
        return {
            "access_token": tokens.get("access_token"),
            "refresh_token": tokens.get("refresh_token"),
            "token_uri": tokens.get("token_uri"),
            "client_id": settings.GOOGLE_CLIENT_ID,
            "client_secret": settings.GOOGLE_CLIENT_SECRET,
            "scopes": DRIVE_SCOPES,
        }
    except Exception as e:
        logger.exception("Google Drive token exchange failed: %s", e)
        raise


def tokens_to_credentials(tokens_dict: Dict[str, Any]) -> Credentials:
    """Build Credentials from stored token dict; refresh if expired."""
    creds = Credentials(
        token=tokens_dict.get("access_token"),
        refresh_token=tokens_dict.get("refresh_token"),
        token_uri=tokens_dict.get("token_uri") or "https://oauth2.googleapis.com/token",
        client_id=tokens_dict.get("client_id") or settings.GOOGLE_CLIENT_ID,
        client_secret=tokens_dict.get("client_secret") or settings.GOOGLE_CLIENT_SECRET,
        scopes=tokens_dict.get("scopes") or DRIVE_SCOPES,
    )
    if not creds.valid and creds.expired and creds.refresh_token:
        creds.refresh(Request())
    return creds


def list_root_files(credentials: Credentials, page_size: int = 20) -> List[Dict[str, Any]]:
    """List files in Drive root. Returns list of dicts with id, name, mimeType."""
    service = build("drive", "v3", credentials=credentials)
    results = (
        service.files()
        .list(
            pageSize=page_size,
            fields="files(id, name, mimeType, createdTime)",
            q="'root' in parents and trashed = false",
            orderBy="createdTime desc",
        )
        .execute()
    )
    return results.get("files", [])


def upload_file(
    credentials: Credentials,
    file_content: bytes,
    name: str,
    mime_type: str = "application/octet-stream",
    parent_id: Optional[str] = None,
) -> Dict[str, Any]:
    """Upload a file to Google Drive. Returns file metadata (id, name, webViewLink if available)."""
    service = build("drive", "v3", credentials=credentials)
    body = {"name": name}
    if parent_id:
        body["parents"] = [parent_id]
    import io
    media = MediaIoBaseUpload(io.BytesIO(file_content), mimetype=mime_type, resumable=True)
    file = (
        service.files()
        .create(body=body, media_body=media, fields="id, name, webViewLink")
        .execute()
    )
    return file
