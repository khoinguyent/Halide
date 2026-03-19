"""
Google Drive API integration for personal cloud storage.
Uses stored OAuth tokens (from mobile serverAuthCode exchange) to list/upload files.
"""
import json
import logging
from typing import Optional, List, Dict, Any
import re

from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
from googleapiclient.http import MediaIoBaseUpload, MediaIoBaseDownload
from googleapiclient.errors import HttpError
import io

from ..core.config import settings

logger = logging.getLogger(__name__)

DRIVE_SCOPES = ["https://www.googleapis.com/auth/drive.readonly"]


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


_FOLDER_MIME_TYPE = "application/vnd.google-apps.folder"


def extract_drive_folder_id(folder_url_or_id: str) -> str:
    """Extract Drive folder id from a shared URL or accept an id directly."""
    value = (folder_url_or_id or "").strip()
    if not value:
        raise ValueError("folder_url_or_id is required")

    # Accept raw ids (Drive folder/file ids are usually URL-safe base64-like)
    if re.fullmatch(r"[a-zA-Z0-9_-]{10,}", value):
        return value

    # Common URL formats:
    # - folders: https://drive.google.com/drive/folders/<id>
    # - files:   https://drive.google.com/file/d/<id>/view
    m = re.search(r"/file/d/([a-zA-Z0-9_-]+)", value)
    if m:
        return m.group(1)

    m = re.search(r"/folders/([a-zA-Z0-9_-]+)", value)
    if m:
        return m.group(1)

    # Fallback for other variants: look for id=<id>
    m = re.search(r"[?&]id=([a-zA-Z0-9_-]+)", value)
    if m:
        return m.group(1)

    raise ValueError(f"Could not extract folder id from: {folder_url_or_id}")


def _list_folder_children(
    service,
    *,
    folder_id: str,
    page_size: int = 1000,
) -> List[Dict[str, Any]]:
    results: List[Dict[str, Any]] = []
    page_token: Optional[str] = None

    while True:
        resp = (
            service.files()
            .list(
                pageSize=page_size,
                fields="nextPageToken, files(id, name, mimeType, createdTime, size)",
                q=f"'{folder_id}' in parents and trashed = false",
                pageToken=page_token,
                supportsAllDrives=True,
                includeItemsFromAllDrives=True,
                # Keep stable ordering; callers can do final sort as needed.
                orderBy="createdTime desc",
            )
            .execute()
        )

        results.extend(resp.get("files", []))
        page_token = resp.get("nextPageToken")
        if not page_token:
            break

    return results


def list_folder_leaf_files(
    credentials: Credentials,
    folder_id: str,
    *,
    max_depth: int = 20,
) -> List[Dict[str, Any]]:
    """
    Recursively traverse a Drive folder and return all non-folder (leaf) files
    inside it, including files inside any nested sub-folders.
    """
    service = build("drive", "v3", credentials=credentials)

    leaf_files: List[Dict[str, Any]] = []

    def walk(current_folder_id: str, depth: int) -> None:
        if depth > max_depth:
            return

        children = _list_folder_children(service, folder_id=current_folder_id)
        for child in children:
            mime_type = child.get("mimeType")
            if mime_type == _FOLDER_MIME_TYPE:
                walk(child["id"], depth + 1)
            else:
                leaf_files.append(child)

    walk(folder_id, 0)

    # Deterministic order for UI mapping (e.g. frame assignment).
    leaf_files.sort(key=lambda f: (f.get("name") or "").lower())
    return leaf_files


def download_file_bytes(
    credentials: Credentials,
    file_id: str,
) -> tuple[bytes, str]:
    """
    Download a single Drive file's bytes plus its mimeType.
    Used for premium sync where we ingest lab scans into our own storage.
    """
    service = build("drive", "v3", credentials=credentials)

    # Fetch minimal metadata for mimeType.
    meta = (
        service.files()
        .get(fileId=file_id, fields="mimeType, name")
        .execute()
    )
    mime_type = meta.get("mimeType") or "application/octet-stream"

    request = service.files().get_media(fileId=file_id)
    buf = io.BytesIO()
    downloader = MediaIoBaseDownload(buf, request)
    done = False
    while not done:
        _, done = downloader.next_chunk()

    buf.seek(0)
    return buf.getvalue(), mime_type
