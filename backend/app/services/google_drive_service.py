"""
Google Drive API integration for personal cloud storage.
Uses stored OAuth tokens (from mobile serverAuthCode exchange) to list/upload files.
"""
import logging
from datetime import datetime, timedelta, timezone
from typing import Optional, List, Dict, Any, Tuple
import re

from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request
from google.auth.exceptions import RefreshError
from googleapiclient.discovery import build
from googleapiclient.http import MediaIoBaseUpload, MediaIoBaseDownload
from googleapiclient.errors import HttpError
import io

from ..core.config import settings

logger = logging.getLogger(__name__)

DRIVE_SCOPES = [
    "https://www.googleapis.com/auth/drive.readonly",
    "https://www.googleapis.com/auth/drive.metadata.readonly",
    "https://www.googleapis.com/auth/userinfo.email",
    "https://www.googleapis.com/auth/userinfo.profile",
    "openid",
]

# Naive UTC — google-auth compares expiry with naive UTC (see google.auth._helpers.utcnow).
_LEGACY_FORCE_REFRESH_EXPIRY = datetime(1970, 1, 1, 0, 0, 0)


def _is_configured() -> bool:
    return bool(settings.GOOGLE_CLIENT_ID and settings.GOOGLE_CLIENT_SECRET)


def is_gdrive_oauth_configured() -> bool:
    """True when backend .env has Web OAuth client id + secret (required for token refresh)."""
    return _is_configured()


def _effective_refresh_token(tokens_dict: Dict[str, Any]) -> Optional[str]:
    rt = tokens_dict.get("refresh_token")
    if rt is None:
        return None
    rt = str(rt).strip()
    return rt if rt else None


def has_stored_refresh_token(tokens_dict: Dict[str, Any]) -> bool:
    """True if the stored OAuth payload includes a non-empty refresh token."""
    return _effective_refresh_token(tokens_dict) is not None


def _credentials_from_stored_tokens(tokens_dict: Dict[str, Any]) -> Credentials:
    rt = _effective_refresh_token(tokens_dict)
    return Credentials(
        token=tokens_dict.get("access_token"),
        refresh_token=rt,
        token_uri=tokens_dict.get("token_uri") or "https://oauth2.googleapis.com/token",
        client_id=tokens_dict.get("client_id") or settings.GOOGLE_CLIENT_ID,
        client_secret=tokens_dict.get("client_secret") or settings.GOOGLE_CLIENT_SECRET,
        scopes=tokens_dict.get("scopes") or DRIVE_SCOPES,
        expiry=_expiry_for_stored_tokens(tokens_dict),
    )


def _parse_expiry_iso_to_naive_utc(raw: str) -> Optional[datetime]:
    """Parse stored ISO expiry into naive UTC for google.oauth2.credentials.Credentials."""
    s = raw.strip().replace("Z", "+00:00")
    try:
        dt = datetime.fromisoformat(s)
    except ValueError:
        return None
    if dt.tzinfo is not None:
        dt = dt.astimezone(timezone.utc).replace(tzinfo=None)
    return dt


def _expiry_for_stored_tokens(tokens_dict: Dict[str, Any]) -> Optional[datetime]:
    """
    google-auth treats expiry=None as "never expires", so we never refresh and send
    stale access tokens. We always persist expiry on connect; legacy rows without it
    use a sentinel so refresh runs once, then we persist real expiry.
    """
    raw = tokens_dict.get("expiry")
    if isinstance(raw, str) and raw.strip():
        parsed = _parse_expiry_iso_to_naive_utc(raw)
        if parsed is not None:
            return parsed
    if _effective_refresh_token(tokens_dict):
        return _LEGACY_FORCE_REFRESH_EXPIRY
    return None


def _merge_creds_into_tokens_dict(creds: Credentials, tokens_dict: Dict[str, Any]) -> None:
    """After refresh, mirror new tokens back into the dict we persist."""
    if creds.token:
        tokens_dict["access_token"] = creds.token
    if creds.refresh_token:
        tokens_dict["refresh_token"] = creds.refresh_token
    if creds.expiry:
        e = creds.expiry
        if e.tzinfo is not None:
            e = e.astimezone(timezone.utc).replace(tzinfo=None)
        tokens_dict["expiry"] = e.isoformat()


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
        flow.fetch_token(code=server_auth_code)
        credentials = flow.credentials
        
        # DEBUG PRINT (ensure visibility in terminal)
        print(f"DEBUG: [GDrive] Credentials after exchange: has_refresh={credentials.refresh_token is not None}")
        print(f"DEBUG: [GDrive] Scopes: {credentials.scopes}")
        
        return {
            "access_token": credentials.token,
            "refresh_token": credentials.refresh_token,
            "token_uri": credentials.token_uri,
            "client_id": credentials.client_id,
            "client_secret": credentials.client_secret,
            "scopes": credentials.scopes,
            "expiry": credentials.expiry.isoformat() if credentials.expiry else None,
        }
    except Exception as e:
        logger.exception("Google Drive token exchange failed: %s", e)
        raise


def refresh_google_credentials(
    tokens_dict: Dict[str, Any],
    *,
    force: bool = False,
) -> Tuple[Credentials, bool]:
    """
    Build Credentials from stored JSON and refresh when the access token is invalid or stale.
    Mutates tokens_dict when a refresh succeeds so callers can persist the updated payload.

    If ``force`` is True and a refresh_token exists, expiry is set to a sentinel so we always
    attempt ``refresh()`` — use when the library still considers the access token valid but
    Google rejects it (e.g. after a forced revoke).

    Returns (credentials, did_refresh).
    """
    if force and _effective_refresh_token(tokens_dict):
        tokens_dict["expiry"] = _LEGACY_FORCE_REFRESH_EXPIRY.isoformat()
    creds = _credentials_from_stored_tokens(tokens_dict)
    if creds.refresh_token and not creds.valid:
        creds.refresh(Request())
        _merge_creds_into_tokens_dict(creds, tokens_dict)
        return creds, True
    return creds, False


def tokens_to_credentials(tokens_dict: Dict[str, Any], *, force: bool = False) -> Credentials:
    """Build Credentials from stored token dict; refresh if invalid/stale. Mutates dict on refresh."""
    creds, _ = refresh_google_credentials(tokens_dict, force=force)
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


def get_drive_entry_mime_type(credentials: Credentials, file_id: str, _depth: int = 0) -> Optional[str]:
    """
    Return the effective mimeType for a Drive id (folder, zip, shortcut target, etc.).
    Used to choose folder-ingest vs ZIP-ingest when the share URL is ambiguous
    (e.g. https://drive.google.com/open?id=...).
    """
    if _depth > 5:
        return None
    try:
        service = build("drive", "v3", credentials=credentials, cache_discovery=False)
        meta = (
            service.files()
            .get(fileId=file_id, fields="mimeType,shortcutDetails", supportsAllDrives=True)
            .execute()
        )
        mime = meta.get("mimeType")
        if mime == "application/vnd.google-apps.shortcut":
            sd = meta.get("shortcutDetails") or {}
            target_mime = sd.get("targetMimeType")
            if target_mime:
                return str(target_mime)
            target_id = sd.get("targetId")
            if target_id:
                return get_drive_entry_mime_type(credentials, str(target_id), _depth + 1)
        return mime
    except HttpError as e:
        logger.warning("Drive files.get mimeType failed for id=%s: %s", file_id, e)
        return None


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
    # Ensure credentials are valid before creating service.
    # If invalid and no refresh token, discovery will fail internally with a RefreshError that's hard to catch.
    if not credentials.valid:
        if credentials.refresh_token:
            try:
                credentials.refresh(Request())
            except Exception as e:
                raise RefreshError(f"Failed to refresh credentials: {e}")
        else:
            raise RefreshError("Credentials are expired and no refresh token is available.")

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
