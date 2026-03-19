from fastapi import APIRouter, Depends, UploadFile, File, HTTPException, status
from typing import List
from sqlalchemy.orm import Session
import uuid
from pydantic import BaseModel
import logging
import io
import zipfile
import hashlib
import os
import re

import requests

from ...db.models.user import User
from ...db.models.roll import Roll
from ...db.models.image import Image
from ...db.session import get_db
from ...db.schemas.image import ImageOut
from ...core.dependencies import get_current_user
from ...services.storage_service import storage_service

from ...db.schemas.storage import StorageProviderMetadata
from ...db.models.storage_credential import StorageCredential, StorageProviderEnum
from ...db.schemas.storage_credential import StorageCredentialOut
from ...core.encryption import decrypt_credential
from ...core.config import settings
from ...services.google_drive_service import (
    extract_drive_folder_id,
    list_folder_leaf_files,
    tokens_to_credentials,
    download_file_bytes,
)
from google.auth.exceptions import RefreshError
from googleapiclient.errors import HttpError

router = APIRouter()
logger = logging.getLogger(__name__)

@router.get("/storage/providers", response_model=List[StorageProviderMetadata])
async def get_storage_providers():
    """Returns metadata for supported storage providers."""
    return [
        StorageProviderMetadata(
            id="icloud",
            name="iCloud",
            icon="icloud-icon",
            auth_type="none",
            description="Apple iCloud Storage (Native Integration)"
        ),
        StorageProviderMetadata(
            id="gdrive",
            name="Google Drive",
            icon="google-drive-icon",
            auth_type="oauth",
            description="Google Drive Cloud Storage"
        ),
        StorageProviderMetadata(
            id="onedrive",
            name="OneDrive",
            icon="onedrive-icon",
            auth_type="oauth",
            description="Microsoft OneDrive Cloud Storage"
        ),
        StorageProviderMetadata(
            id="nas",
            name="NAS",
            icon="nas-icon",
            auth_type="credentials",
            description="Network Attached Storage (Generic)"
        ),
        StorageProviderMetadata(
            id="smb",
            name="SMB",
            icon="smb-icon",
            auth_type="credentials",
            description="Server Message Block (Windows Share)"
        ),
    ]

@router.post("/rolls/{roll_id}/images", response_model=List[ImageOut])
async def upload_roll_images(
    roll_id: str,
    files: List[UploadFile] = File(...),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # Verify roll ownership
    roll = db.query(Roll).filter(Roll.id == roll_id).first()
    if not roll:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Roll not found"
        )
    
    if roll.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to upload to this roll"
        )
    
    max_bytes = 15 * 1024 * 1024  # 15 MB per file
    uploaded_images = []
    for file in files:
        # Enforce max file size before reading into memory
        file_size = 0
        chunk = await file.read(1024 * 1024)
        chunks: list[bytes] = []
        while chunk:
            file_size += len(chunk)
            if file_size > max_bytes:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"File {file.filename} exceeds the 15 MB limit.",
                )
            chunks.append(chunk)
            chunk = await file.read(1024 * 1024)
        file_content = b"".join(chunks)
        image_id = str(uuid.uuid4())
        
        # Upload to Storage
        key = storage_service.upload_roll_image(
            user_id=current_user.id,
            roll_id=roll_id,
            image_id=image_id,
            file_content=file_content,
            content_type=file.content_type
        )
        
        # Save to DB
        # Note: In a real scenario we might derive URL from key or store key
        # Here we follow the model's image_url field
        db_image = Image(
            roll_id=roll_id,
            image_url=key,  # Storing the key as the URL for now
            # frame_number, aperture, shutter_speed could be extracted from EXIF in later sprints
        )
        db.add(db_image)
        uploaded_images.append(db_image)
    
    db.commit()
    return uploaded_images

import json
from ...db.models.storage_credential import StorageCredential, StorageProviderEnum
from ...db.schemas.storage_credential import StorageCredentialCreate, StorageCredentialOut
from ...core.encryption import encrypt_credential

@router.post("/connect", response_model=StorageCredentialOut)
def connect_storage(
    data: StorageCredentialCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    auth_data_to_store = data.auth_data
    if data.provider == StorageProviderEnum.gdrive:
        try:
            from ...services.google_drive_service import exchange_server_auth_code, DRIVE_SCOPES
            payload = json.loads(data.auth_data)

            # Preferred: mobile sends a one-time server_auth_code; exchange it for
            # a full token dict that includes refresh_token, token_uri, client_id, etc.
            if payload.get("server_auth_code"):
                tokens = exchange_server_auth_code(payload["server_auth_code"])
            else:
                # Fallback: mobile sends a token response directly. Normalise it so
                # that all required fields are present for silent refresh.
                tokens = {
                    "access_token": payload.get("access_token"),
                    "refresh_token": payload.get("refresh_token"),
                    "token_uri": payload.get("token_uri") or "https://oauth2.googleapis.com/token",
                    "client_id": payload.get("client_id") or settings.GOOGLE_CLIENT_ID,
                    "client_secret": payload.get("client_secret") or settings.GOOGLE_CLIENT_SECRET,
                    "scopes": payload.get("scopes") or DRIVE_SCOPES,
                }

            auth_data_to_store = json.dumps(tokens)
            print(
                f"[GDrive] connect_storage: stored scopes={tokens.get('scopes')} "
                f"has_refresh={bool(tokens.get('refresh_token'))} "
                f"has_token_uri={bool(tokens.get('token_uri'))}"
            )
        except Exception as e:
            # Log full traceback on the server and surface a clear error to the client
            logger.exception("Failed to normalise Google Drive auth data: %s", e)
            raise HTTPException(
                status_code=400,
                detail=f"Google Drive connect failed: {e}",
            )
    encrypted_data = encrypt_credential(auth_data_to_store)
    cred = StorageCredential(
        user_id=current_user.id,
        provider=data.provider,
        identifier=data.identifier,
        host=data.host,
        username=data.username,
        encrypted_auth_data=encrypted_data,
        is_archive=data.is_archive,
        display_label=data.display_label,
        is_primary=data.is_primary,
    )
    db.add(cred)
    db.commit()
    db.refresh(cred)
    return cred

@router.get("/connections", response_model=List[StorageCredentialOut])
def list_connections(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    return db.query(StorageCredential).filter(StorageCredential.user_id == current_user.id).all()


@router.delete("/connections/{connection_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_connection(
    connection_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    cred = (
        db.query(StorageCredential)
        .filter(StorageCredential.id == connection_id, StorageCredential.user_id == current_user.id)
        .first()
    )
    if not cred:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Connection not found")
    db.delete(cred)
    db.commit()
    return None


class GDriveListLeafFilesRequest(BaseModel):
    folder_url_or_id: str


@router.post("/storage/gdrive/list_leaf_files")
def list_gdrive_leaf_files(
    payload: GDriveListLeafFilesRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Given a shared lab folder URL (or a raw folder id), return all leaf files
    inside it, recursively traversing sub-folders.
    """
    # Pick the primary gdrive connection if available, else first connection.
    cred = (
        db.query(StorageCredential)
        .filter(
            StorageCredential.user_id == current_user.id,
            StorageCredential.provider == StorageProviderEnum.gdrive,
        )
        .order_by(StorageCredential.is_primary.desc())
        .first()
    )
    if not cred:
        raise HTTPException(status_code=400, detail="Google Drive is not connected for this user")

    tokens_json = decrypt_credential(cred.encrypted_auth_data)
    if not tokens_json:
        raise HTTPException(status_code=400, detail="Failed to decrypt Google Drive credentials")

    try:
        tokens = json.loads(tokens_json)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid Google Drive credentials payload")

    # Debug: confirm we have the expected scopes / credential shape.
    # Use print so it always shows in uvicorn logs during development.
    print(
        f"[GDrive] list_leaf_files: scopes={tokens.get('scopes')} has_refresh={bool(tokens.get('refresh_token'))}"
    )

    credentials = tokens_to_credentials(tokens)

    try:
        folder_id = extract_drive_folder_id(payload.folder_url_or_id)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    print(f"[GDrive] list_leaf_files: folder_id={folder_id}")

    try:
        files = list_folder_leaf_files(credentials, folder_id)
    except RefreshError:
        # Drive connection was created with an access_token-only payload and can no
        # longer be refreshed. Surface a clear 400 so the client can ask the user
        # to reconnect Google Drive.
        raise HTTPException(
            status_code=400,
            detail="Google Drive access has expired. Please disconnect and reconnect Google Drive in storage settings.",
        )

    print(f"[GDrive] list_leaf_files: returned={len(files)} first={(files[:3]) if files else None}")
    return files


class GDriveSyncRequest(BaseModel):
    roll_id: str
    folder_url_or_id: str


@router.post("/storage/gdrive/sync_leaf_files")
def sync_gdrive_leaf_files(
    payload: GDriveSyncRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Premium sync: given a Drive folder, download all leaf image files, upload
    them to our R2/S3 storage (full + thumbnail), and create Image records
    for the given roll. Safe to call multiple times; it skips files that were
    already ingested for this roll.
    """
    # Verify roll belongs to current user.
    roll = (
        db.query(Roll)
        .filter(Roll.id == payload.roll_id, Roll.user_id == current_user.id)
        .first()
    )
    if not roll:
        raise HTTPException(status_code=404, detail="Roll not found")

    # Pick the primary gdrive connection if available, else first connection.
    cred = (
        db.query(StorageCredential)
        .filter(
            StorageCredential.user_id == current_user.id,
            StorageCredential.provider == StorageProviderEnum.gdrive,
        )
        .order_by(StorageCredential.is_primary.desc())
        .first()
    )
    if not cred:
        raise HTTPException(status_code=400, detail="Google Drive is not connected for this user")

    tokens_json = decrypt_credential(cred.encrypted_auth_data)
    if not tokens_json:
        raise HTTPException(status_code=400, detail="Failed to decrypt Google Drive credentials")

    try:
        tokens = json.loads(tokens_json)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid Google Drive credentials payload")

    credentials = tokens_to_credentials(tokens)

    try:
        folder_id = extract_drive_folder_id(payload.folder_url_or_id)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    try:
        files = list_folder_leaf_files(credentials, folder_id)
    except RefreshError:
        raise HTTPException(
            status_code=400,
            detail="Google Drive access has expired. Please disconnect and reconnect Google Drive in storage settings.",
        )

    synced_count = 0
    skipped_existing = 0
    total_candidates = 0

    for idx, f in enumerate(files):
        mime_type = (f.get("mimeType") or "").lower()
        name = (f.get("name") or "").lower()
        file_id = f.get("id")
        if not file_id:
            continue

        # Only ingest images (JPEG/PNG, etc.)
        if not (
            mime_type.startswith("image/")
            or name.endswith(".jpg")
            or name.endswith(".jpeg")
            or name.endswith(".png")
        ):
            continue

        total_candidates += 1

        # Deterministic key: use Drive file id as image_id so re-syncing is idempotent.
        base_key = f"users/{current_user.id}/rolls/{roll.id}/{file_id}"
        full_key = f"{base_key}.jpg"

        existing = (
            db.query(Image)
            .filter(Image.roll_id == roll.id, Image.image_url == full_key)
            .first()
        )
        if existing:
            skipped_existing += 1
            continue

        logger.info("GDrive sync: ingest file_id=%s name=%s mime=%s", file_id, name, mime_type)

        try:
            content, mime = download_file_bytes(credentials, file_id)
        except HttpError as e:
            logger.exception("Failed to download Drive file %s: %s", file_id, e)
            continue

        logger.info("GDrive sync: downloaded bytes=%s for file_id=%s", len(content), file_id)

        # Upload to our storage (full + thumbnail).
        storage_service.upload_roll_image(
            user_id=str(current_user.id),
            roll_id=str(roll.id),
            image_id=file_id,
            file_content=content,
            content_type=mime or "image/jpeg",
        )

        db_image = Image(
            roll_id=roll.id,
            image_url=full_key,
            frame_number=idx,
        )
        db.add(db_image)
        synced_count += 1

    db.commit()

    return {
        "synced_count": synced_count,
        "skipped_existing": skipped_existing,
        "total_drive_files": len(files),
        "total_image_candidates": total_candidates,
    }


class GDriveZipSyncRequest(BaseModel):
    roll_id: str
    zip_url_or_id: str


def _is_image_entry(filename: str) -> bool:
    """Return True for common image extensions found inside lab ZIPs."""
    lower = (filename or "").lower()
    return (
        lower.endswith(".jpg")
        or lower.endswith(".jpeg")
        or lower.endswith(".png")
        or lower.endswith(".webp")
    )


def _is_safe_zip_member_path(member_filename: str) -> bool:
    """
    Basic protection against Zip Slip-like traversal attempts.
    We do not write extracted files to disk, but we still validate paths.
    """
    # zipfile uses forward slashes internally.
    norm = os.path.normpath(member_filename)
    if norm.startswith(".."):
        return False
    if os.path.isabs(norm):
        return False
    return True


def _download_drive_zip_public(zip_id: str) -> bytes:
    """
    Download a publicly shared Drive file as bytes.

    Google Drive often returns an HTML page requiring a confirm token
    for large files; this function handles that by retrying with
    the confirm=... token.
    """
    session = requests.Session()
    base_url = "https://drive.google.com/uc?export=download&id={zip_id}"
    url = base_url.format(zip_id=zip_id)

    def _try_download(download_url: str) -> tuple[bytes, str]:
        resp = session.get(download_url, timeout=300, allow_redirects=True)
        resp.raise_for_status()
        content_type = resp.headers.get("Content-Type", "")
        return resp.content, content_type

    data, content_type = _try_download(url)
    if zipfile.is_zipfile(io.BytesIO(data)):
        return data

    # Not a zip => likely an HTML "confirm download" page. Extract confirm token.
    try:
        html_text = data.decode("utf-8", errors="ignore")
    except Exception:
        html_text = ""

    m = re.search(r"confirm=([0-9A-Za-z_]+)", html_text)
    if not m:
        # Some Drive pages render the token via a different variable name.
        m = re.search(r"confirm_token[\"']?\s*[:=]\s*[\"']([0-9A-Za-z_]+)", html_text, re.IGNORECASE)

    if not m:
        raise HTTPException(
            status_code=400,
            detail=f"Google Drive public download did not return a ZIP (content_type={content_type}).",
        )

    confirm_token = m.group(1)
    confirm_url = "https://drive.google.com/uc?export=download&confirm={token}&id={zip_id}".format(
        token=confirm_token, zip_id=zip_id
    )
    data2, content_type2 = _try_download(confirm_url)
    if not zipfile.is_zipfile(io.BytesIO(data2)):
        raise HTTPException(
            status_code=400,
            detail=f"Google Drive confirm-download did not return a ZIP (content_type={content_type2}).",
        )
    return data2


@router.post("/storage/gdrive/sync_zip_images")
def sync_gdrive_zip_images(
    payload: GDriveZipSyncRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Download a Drive-shared ZIP on the backend, extract image entries (JPEG),
    and upload each image to R2 using the same key format as other ingesters.

    - Sort by ZIP entry filename.
    - If the roll already has an image with the same computed R2 key, skip it.
    - Keeps all extracted frames (does not clamp to max_frames).
    """
    roll = (
        db.query(Roll)
        .filter(Roll.id == payload.roll_id, Roll.user_id == current_user.id)
        .first()
    )
    if not roll:
        raise HTTPException(status_code=404, detail="Roll not found")

    zip_id = extract_drive_folder_id(payload.zip_url_or_id)

    # Optional: use connected OAuth credentials when available (more reliable than public download).
    cred = (
        db.query(StorageCredential)
        .filter(
            StorageCredential.user_id == current_user.id,
            StorageCredential.provider == StorageProviderEnum.gdrive,
        )
        .order_by(StorageCredential.is_primary.desc())
        .first()
    )

    zip_bytes: bytes
    used_auth = False
    if cred:
        tokens_json = decrypt_credential(cred.encrypted_auth_data)
        if not tokens_json:
            raise HTTPException(status_code=400, detail="Failed to decrypt Google Drive credentials")
        tokens = json.loads(tokens_json)
        credentials = tokens_to_credentials(tokens)
        try:
            zip_bytes, _mime = download_file_bytes(credentials, zip_id)
            used_auth = True
        except RefreshError:
            # Token cannot be refreshed (e.g., access-token-only payload or missing
            # client_id/client_secret). Fall back to public ZIP download if allowed.
            logger.exception(
                "GDrive ZIP download auth failed (refresh not possible) for zip_id=%s; falling back to public download",
                zip_id,
            )
            used_auth = False
            try:
                zip_bytes = _download_drive_zip_public(zip_id)
            except HTTPException:
                raise
            except Exception:
                raise HTTPException(
                    status_code=400,
                    detail="Google Drive OAuth credentials are not refreshable and ZIP download failed.",
                )
        except HttpError as e:
            logger.exception("Failed to download Drive ZIP file %s: %s", zip_id, e)
            raise HTTPException(status_code=400, detail="Failed to download the ZIP from Google Drive")
    else:
        # Public download fallback. Assumes the ZIP is accessible without login.
        try:
            zip_bytes = _download_drive_zip_public(zip_id)
        except HTTPException:
            raise
        except Exception:
            raise HTTPException(
                status_code=400,
                detail="Google Drive is not connected and ZIP public download failed (maybe not public).",
            )

    try:
        with zipfile.ZipFile(io.BytesIO(zip_bytes)) as zf:
            image_entries = []
            for info in zf.infolist():
                if info.is_dir():
                    continue
                if not _is_image_entry(info.filename):
                    continue
                if not _is_safe_zip_member_path(info.filename):
                    continue
                image_entries.append(info)

            image_entries.sort(key=lambda i: (i.filename or "").lower())

            synced_count = 0
            skipped_existing = 0
            total_candidates = len(image_entries)

            for idx, info in enumerate(image_entries):
                # Make the R2 object key deterministic so re-syncing doesn't duplicate.
                crc_part = str(getattr(info, "CRC", ""))
                stable_material = f"{zip_id}:{info.filename}:{crc_part}".encode("utf-8")
                image_id = hashlib.sha1(stable_material).hexdigest()

                base_key = f"users/{current_user.id}/rolls/{roll.id}/{image_id}"
                full_key = f"{base_key}.jpg"

                existing = (
                    db.query(Image)
                    .filter(Image.roll_id == roll.id, Image.image_url == full_key)
                    .first()
                )
                if existing:
                    skipped_existing += 1
                    continue

                try:
                    with zf.open(info) as member_fp:
                        file_content = member_fp.read()
                except Exception:
                    # Skip broken/unreadable entries.
                    continue

                # R2 key convention (and frontend thumbnail logic) assumes JPEG bytes under *.jpg.
                # If the ZIP entry is PNG/WebP/etc, convert to JPEG when Pillow is available.
                entry_lower = (info.filename or "").lower()
                if not (entry_lower.endswith(".jpg") or entry_lower.endswith(".jpeg")):
                    try:
                        from PIL import Image as PILImage  # type: ignore

                        img = PILImage.open(io.BytesIO(file_content))
                        img = img.convert("RGB")
                        buf = io.BytesIO()
                        img.save(buf, format="JPEG", quality=85)
                        buf.seek(0)
                        file_content = buf.getvalue()
                    except ModuleNotFoundError:
                        # If Pillow isn't installed, skip non-JPEG entries to avoid corrupting *.jpg objects.
                        continue

                storage_service.upload_roll_image(
                    user_id=str(current_user.id),
                    roll_id=str(roll.id),
                    image_id=image_id,
                    file_content=file_content,
                    content_type="image/jpeg",
                )

                db_image = Image(
                    roll_id=roll.id,
                    image_url=full_key,
                    frame_number=idx,
                )
                db.add(db_image)
                synced_count += 1

            db.commit()

            return {
                "synced_count": synced_count,
                "skipped_existing": skipped_existing,
                "total_image_candidates": total_candidates,
                "used_drive_auth": used_auth,
            }
    except zipfile.BadZipFile:
        # Provide a better signal if Drive returned HTML (sign-in / captcha) instead of ZIP bytes.
        preview = ""
        try:
            preview = zip_bytes[:300].decode("utf-8", errors="ignore").strip()
        except Exception:
            preview = ""

        if preview.lower().startswith("<!doctype") or "<html" in preview.lower() or "google drive" in preview.lower():
            raise HTTPException(
                status_code=400,
                detail="Provided ZIP is not valid. Drive likely returned an HTML sign-in/CAPTCHA page instead of ZIP bytes.",
            )

        raise HTTPException(status_code=400, detail="Provided ZIP is not valid ZIP archive")


class GDriveSyncImagesFromUrlRequest(BaseModel):
    roll_id: str
    gdrive_url_or_id: str


@router.post("/storage/gdrive/sync_images_from_url")
def sync_images_from_url(
    payload: GDriveSyncImagesFromUrlRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Convenience wrapper:
    - If URL looks like a Drive folder: route to `sync_leaf_files`.
    - If URL looks like a Drive file: route to `sync_zip_images`.

    For raw IDs (no /folders/ or /file/d/), the route is ambiguous -> 400.
    """
    raw = (payload.gdrive_url_or_id or "").strip()
    if not raw:
        raise HTTPException(status_code=400, detail="gdrive_url_or_id is required")

    if "/folders/" in raw:
        return sync_gdrive_leaf_files(
            payload=GDriveSyncRequest(roll_id=payload.roll_id, folder_url_or_id=raw),
            current_user=current_user,
            db=db,
        )

    if "/file/d/" in raw:
        return sync_gdrive_zip_images(
            payload=GDriveZipSyncRequest(roll_id=payload.roll_id, zip_url_or_id=raw),
            current_user=current_user,
            db=db,
        )

    # Ambiguous raw IDs: we cannot know whether it's a folder or zip file from the string alone.
    raise HTTPException(
        status_code=400,
        detail="Ambiguous Drive identifier. Please send a shared URL containing either '/folders/' or '/file/d/'.",
    )
