from fastapi import APIRouter, Depends, UploadFile, File, HTTPException, status, BackgroundTasks
from fastapi.responses import Response
from typing import List, Optional, Tuple
from datetime import datetime, timedelta, timezone
from sqlalchemy.orm import Session
import uuid
from pydantic import BaseModel
import logging
import io
import zipfile
import hashlib
import os
import re
import json

import requests
from concurrent.futures import ThreadPoolExecutor, as_completed

from ...db.models.user import User
from ...db.models.roll import Roll, RollStatusEnum
from ...db.models.image import Image
from ...db.session import get_db
from ...db.schemas.image import ImageOut
from ...core.dependencies import get_current_user
from ...services.storage_service import storage_service

from ...db.schemas.storage import StorageProviderMetadata
from ...db.models.storage_credential import StorageCredential, StorageProviderEnum
from ...db.schemas.storage_credential import StorageCredentialOut
from ...core.encryption import decrypt_credential, encrypt_credential
from ...core.config import settings
from ...services.google_drive_service import (
    extract_drive_folder_id,
    get_drive_entry_mime_type,
    list_folder_leaf_files,
    refresh_google_credentials,
    download_file_bytes,
    is_gdrive_oauth_configured,
    has_stored_refresh_token,
)
from google.auth.exceptions import RefreshError
from googleapiclient.errors import HttpError

router = APIRouter()
logger = logging.getLogger(__name__)

_GOOGLE_DRIVE_FOLDER_MIME = "application/vnd.google-apps.folder"


def _tier_uses_cloud_drive_r2_sync(tier: Optional[str]) -> bool:
    """Plus/Pro: server downloads Drive and persists to R2. Free: on-device import only."""
    return (tier or "free").lower() in ("plus", "pro")


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
    
    # Check total storage limit
    total_new_size = 0
    for file in files:
        # We don't know the size yet without reading, 
        # but we can check the current usage first
        pass

    if current_user.storage_used_bytes >= current_user.storage_limit_bytes:
        raise HTTPException(
            status_code=status.HTTP_402_PAYMENT_REQUIRED,
            detail="Storage limit reached. Please upgrade your plan."
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
        
        # Check if this file exceeds the remaining storage
        if current_user.storage_used_bytes + len(file_content) > current_user.storage_limit_bytes:
            raise HTTPException(
                status_code=status.HTTP_402_PAYMENT_REQUIRED,
                detail=f"Uploading {file.filename} would exceed your storage limit. Please upgrade your plan."
            )
        
        image_id = str(uuid.uuid4())
        
        # Determine Strategy
        primary_cred = db.query(StorageCredential).filter(
            StorageCredential.user_id == current_user.id,
            StorageCredential.is_primary == True
        ).first()
        strategy = "PERSONAL_CLOUD" if primary_cred else "SYSTEM_CLOUD"

        # Upload to Storage via TransferService
        from ...services.transfer_service import transfer_service
        key = transfer_service.route_transfer(
            db=db,
            user_id=current_user.id,
            roll_id=roll_id,
            image_id=image_id,
            file_content=file_content,
            strategy=strategy
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
        
        # Update storage usage
        current_user.storage_used_bytes += len(file_content)
        db.add(current_user)
    
    db.commit()
    return uploaded_images


@router.put("/rolls/{roll_id}/images/{image_id}", response_model=ImageOut)
async def replace_roll_image(
    roll_id: str,
    image_id: str,
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Replace an existing roll frame in object storage (same key).
    Used when Pro users rotate/edit an image so the cloud copy stays in sync.
    """
    try:
        rid = uuid.UUID(roll_id)
        iid = uuid.UUID(image_id)
    except ValueError:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid roll or image id")

    roll = db.query(Roll).filter(Roll.id == rid).first()
    if not roll or roll.user_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Roll not found")

    row = db.query(Image).filter(Image.id == iid, Image.roll_id == rid).first()
    if not row or not row.image_url:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Image not found")

    old_key = row.image_url
    if not isinstance(old_key, str) or not old_key.startswith("users/"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="This image is not stored in Halide cloud storage and cannot be replaced here",
        )

    max_bytes = 15 * 1024 * 1024
    file_size = 0
    chunk = await file.read(1024 * 1024)
    chunks: list[bytes] = []
    while chunk:
        file_size += len(chunk)
        if file_size > max_bytes:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"File exceeds the {max_bytes // (1024 * 1024)} MB limit.",
            )
        chunks.append(chunk)
        chunk = await file.read(1024 * 1024)
    file_content = b"".join(chunks)

    old_size = 0
    if storage_service.s3 is not None:
        try:
            head = storage_service.s3.head_object(
                Bucket=storage_service.bucket_name,
                Key=old_key,
            )
            old_size = int(head.get("ContentLength", 0) or 0)
        except Exception:
            old_size = 0

    new_size = len(file_content)
    projected = current_user.storage_used_bytes - old_size + new_size
    if projected > current_user.total_storage_limit:
        raise HTTPException(
            status_code=status.HTTP_402_PAYMENT_REQUIRED,
            detail="Storage limit would be exceeded after this edit.",
        )

    storage_service.replace_roll_image_at_key(old_key, file_content)
    current_user.storage_used_bytes = max(0, projected)
    db.add(current_user)
    db.commit()
    db.refresh(row)
    return row


from ...db.models.storage_credential import StorageCredential, StorageProviderEnum
from ...db.schemas.storage_credential import StorageCredentialCreate, StorageCredentialOut

def _persist_gdrive_tokens(db: Session, cred: StorageCredential, tokens: dict, refreshed: bool) -> None:
    """Persist updated OAuth fields after a successful refresh."""
    if not refreshed:
        return
    cred.encrypted_auth_data = encrypt_credential(json.dumps(tokens))
    db.add(cred)
    db.commit()


def _raise_gdrive_refresh_http_exception(tokens: dict, exc: RefreshError) -> None:
    """Map google.auth RefreshError to an HTTP response; always raises (never returns)."""
    logger.warning("GDrive RefreshError: %s", exc)
    if not is_gdrive_oauth_configured():
        raise HTTPException(
            status_code=503,
            detail=(
                "Google Drive OAuth is not configured on this server. "
                "Set GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET in backend/.env (Web client from Google Cloud Console), "
                "restart uvicorn, then disconnect and reconnect Google Drive in the app."
            ),
        ) from exc
    msg = str(exc).lower()
    if "necessary fields" in msg or "must specify" in msg:
        if not has_stored_refresh_token(tokens):
            raise HTTPException(
                status_code=400,
                detail=(
                    "This Google Drive connection has no refresh token. "
                    "Disconnect and reconnect Google Drive in the app (use Google sign-in with Drive access so the server receives a refresh token)."
                ),
            ) from exc
        raise HTTPException(
            status_code=503,
            detail=(
                "Google Drive cannot refresh tokens: OAuth client id or secret is missing. "
                "Ensure GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET are set in backend/.env (same Web OAuth client as the app’s GOOGLE_DRIVE_SERVER_CLIENT_ID), "
                "restart the server, then reconnect Google Drive."
            ),
        ) from exc
    raise HTTPException(
        status_code=400,
        detail="Google Drive access has expired. Please disconnect and reconnect Google Drive in storage settings.",
    ) from exc


def _list_leaf_files_with_drive_retry(
    db: Session,
    cred: StorageCredential,
    tokens: dict,
    folder_id: str,
):
    """
    Refresh OAuth tokens, list Drive folder contents, and on RefreshError retry once with
    a forced token refresh (handles 'valid' cached access tokens that Google rejects).

    Returns (leaf_files, credentials) for callers that need the same credentials for downloads.
    """
    try:
        credentials, refreshed = refresh_google_credentials(tokens)
        _persist_gdrive_tokens(db, cred, tokens, refreshed)
    except RefreshError as e:
        logger.warning("GDrive token refresh failed, retrying with force: %s", e)
        if not has_stored_refresh_token(tokens):
            _raise_gdrive_refresh_http_exception(tokens, e)
        credentials, refreshed = refresh_google_credentials(tokens, force=True)
        _persist_gdrive_tokens(db, cred, tokens, refreshed)
    try:
        files = list_folder_leaf_files(credentials, folder_id)
        return files, credentials
    except RefreshError as e:
        logger.warning("GDrive list_folder_leaf_files failed, retrying with forced refresh: %s", e)
        if not has_stored_refresh_token(tokens):
            _raise_gdrive_refresh_http_exception(tokens, e)
        credentials, refreshed = refresh_google_credentials(tokens, force=True)
        _persist_gdrive_tokens(db, cred, tokens, refreshed)
        files = list_folder_leaf_files(credentials, folder_id)
        return files, credentials


def _finalize_roll_after_drive_ingest(db: Session, roll: Roll) -> None:
    """
    Set roll to scanned only when at least one gallery row exists with a non-empty storage key.
    Avoids marking scanned (and confusing the app) when every upload failed or quota blocked ingest.
    """
    n = (
        db.query(Image)
        .filter(
            Image.roll_id == roll.id,
            Image.image_url.isnot(None),
        )
        .filter(Image.image_url != "")
        .count()
    )
    roll.status = RollStatusEnum.scanned if n > 0 else RollStatusEnum.lab
    db.add(roll)


@router.post("/connect", response_model=StorageCredentialOut)
def connect_storage(
    data: StorageCredentialCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    auth_data_to_store = data.auth_data
    if data.provider == StorageProviderEnum.gdrive:
        if not is_gdrive_oauth_configured():
            raise HTTPException(
                status_code=503,
                detail="Google Drive OAuth is not configured on this server. Set GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET in backend/.env.",
            )
        try:
            from ...services.google_drive_service import exchange_server_auth_code, DRIVE_SCOPES
            payload = json.loads(data.auth_data)
            # Preferred: mobile sends a one-time server_auth_code; exchange it for
            # a full token dict that includes refresh_token, token_uri, client_id, etc.
            if payload.get("server_auth_code"):
                logger.info(f"[GDrive] Received server_auth_code for user {current_user.id}")
                tokens = exchange_server_auth_code(payload["server_auth_code"])
            else:
                # Fallback: mobile sends a token response directly. Normalise it so
                # that all required fields are present for silent refresh.
                logger.warning(f"[GDrive] No server_auth_code; using direct access_token for user {current_user.id}")
                tokens = {
                    "access_token": payload.get("access_token"),
                    "refresh_token": payload.get("refresh_token"),
                    "token_uri": payload.get("token_uri") or "https://oauth2.googleapis.com/token",
                    "client_id": settings.GOOGLE_CLIENT_ID,
                    "client_secret": settings.GOOGLE_CLIENT_SECRET,
                    "scopes": payload.get("scopes") or DRIVE_SCOPES,
                }
                exp_in = payload.get("expires_in")
                if exp_in is not None:
                    exp_naive = (
                        datetime.now(timezone.utc) + timedelta(seconds=int(exp_in))
                    ).replace(tzinfo=None)
                    tokens["expiry"] = exp_naive.isoformat()
                elif isinstance(payload.get("expiry"), str) and payload.get("expiry"):
                    tokens["expiry"] = payload["expiry"]

            # Validate that we have a refresh_token for Google Drive.
            # Background sync will fail after 1hr without it.
            if not tokens.get("refresh_token"):
                logger.error(
                    f"[GDrive] Missing refresh_token for user {current_user.id}. "
                    f"Keys present in tokens: {list(tokens.keys())}"
                )
                raise HTTPException(
                    status_code=400,
                    detail="Missing GDrive refresh token. Please revoke 'Halide' from your Google Security settings and try again.",
                )

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
        is_scan_sync=data.is_scan_sync,
        display_label=data.display_label,
        is_primary=data.is_primary,
    )
    db.add(cred)
    db.commit()
    db.refresh(cred)
    return cred

@router.get("/connections", response_model=List[StorageCredentialOut])
def get_storage_connections(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    credentials = db.query(StorageCredential).filter(StorageCredential.user_id == current_user.id).all()
    
    # Cast to StorageCredentialOut-compatible objects
    results = []
    for c in credentials:
        results.append(StorageCredentialOut.model_validate(c))
        
    # Show System Cloud connection for all users if they have storage limits.
    # Metadata/Thumbnails are always mirrored to System Cloud (Halide R2) for sync stability.
    if True: 
        results.append(StorageCredentialOut(
            id=uuid.UUID("00000000-0000-0000-0000-000000000000"), # Virtual ID
            provider=StorageProviderEnum.system,
            identifier="System Cloud",
            host=None,
            username=None,
            is_archive=True,
            is_scan_sync=True,
            display_label="System Cloud",
            is_primary=False,
            storage_used=current_user.storage_used_bytes,
            storage_limit=current_user.total_storage_limit
        ))
        
    return results


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


class StorageCredentialUpdate(BaseModel):
    is_archive: Optional[bool] = None
    is_scan_sync: Optional[bool] = None
    is_primary: Optional[bool] = None
    display_label: Optional[str] = None


@router.patch("/connections/{connection_id}", response_model=StorageCredentialOut)
def patch_connection(
    connection_id: str,
    data: StorageCredentialUpdate,
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

    if data.is_archive is not None:
        cred.is_archive = data.is_archive
    if data.is_scan_sync is not None:
        cred.is_scan_sync = data.is_scan_sync
    
    if data.is_primary is True:
        # Unset others for this user to avoid unique constraint violation
        db.query(StorageCredential).filter(
            StorageCredential.user_id == current_user.id,
            StorageCredential.id != cred.id
        ).update({"is_primary": False})
        cred.is_primary = True
    elif data.is_primary is False:
        cred.is_primary = False
        
    if data.display_label is not None:
        cred.display_label = data.display_label

    db.add(cred)
    db.commit()
    db.refresh(cred)
    return cred


class GDriveListLeafFilesRequest(BaseModel):
    folder_url_or_id: str


@router.post("/storage/gdrive/list_leaf_files")
def list_gdrive_leaf_files(
    payload: GDriveListLeafFilesRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):

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

    if not is_gdrive_oauth_configured():
        raise HTTPException(
            status_code=503,
            detail="Google Drive OAuth is not configured on this server (GOOGLE_CLIENT_ID / GOOGLE_CLIENT_SECRET in backend/.env).",
        )

    tokens_json = decrypt_credential(cred.encrypted_auth_data)
    if not tokens_json:
        raise HTTPException(status_code=400, detail="Failed to decrypt Google Drive credentials")

    try:
        tokens = json.loads(tokens_json)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid Google Drive credentials payload")

    # Debug: confirm we have the expected scopes / credential shape.
    # Use print so it always shows in uvicorn logs during development.
    logger.debug(
        "[GDrive] list_leaf_files: scopes=%s has_refresh=%s",
        tokens.get("scopes"),
        bool(tokens.get("refresh_token")),
    )

    try:
        folder_id = extract_drive_folder_id(payload.folder_url_or_id)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    logger.debug("[GDrive] list_leaf_files: folder_id=%s", folder_id)

    try:
        files, _ = _list_leaf_files_with_drive_retry(db, cred, tokens, folder_id)
    except RefreshError as e:
        _raise_gdrive_refresh_http_exception(tokens, e)

    logger.debug(
        "[GDrive] list_leaf_files: returned=%s first=%s",
        len(files),
        (files[:3]) if files else None,
    )
    return files


def _ordered_image_file_ids_from_leaf_list(files: List[dict]) -> List[str]:
    """Image leaf file IDs in the same order/filter as sync_gdrive_leaf_files."""
    out: List[str] = []
    for f in files:
        mime_type = (f.get("mimeType") or "").lower()
        name = (f.get("name") or "").lower()
        fid = f.get("id")
        if not fid:
            continue
        if not (
            mime_type.startswith("image/")
            or name.endswith(".jpg")
            or name.endswith(".jpeg")
            or name.endswith(".png")
        ):
            continue
        out.append(str(fid))
    return out


class GDriveSyncRequest(BaseModel):
    roll_id: str
    folder_url_or_id: str


class GDriveFreeFolderManifestOut(BaseModel):
    file_ids: List[str]


@router.post("/storage/gdrive/free_folder_manifest", response_model=GDriveFreeFolderManifestOut)
def free_folder_manifest(
    payload: GDriveSyncRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Free tier: ordered image file IDs in a Drive folder for client-side download.
    Does not write to R2 or create Image rows.
    """
    if _tier_uses_cloud_drive_r2_sync(current_user.subscription_tier):
        raise HTTPException(
            status_code=400,
            detail="Plus/Pro should use cloud sync.",
        )
    roll = (
        db.query(Roll)
        .filter(Roll.id == payload.roll_id, Roll.user_id == current_user.id)
        .first()
    )
    if not roll:
        raise HTTPException(status_code=404, detail="Roll not found")

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

    if not is_gdrive_oauth_configured():
        raise HTTPException(
            status_code=503,
            detail="Google Drive OAuth is not configured on this server (GOOGLE_CLIENT_ID / GOOGLE_CLIENT_SECRET in backend/.env).",
        )

    tokens_json = decrypt_credential(cred.encrypted_auth_data)
    if not tokens_json:
        raise HTTPException(status_code=400, detail="Failed to decrypt Google Drive credentials")

    try:
        tokens = json.loads(tokens_json)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid Google Drive credentials payload")

    try:
        folder_id = extract_drive_folder_id(payload.folder_url_or_id)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    try:
        files, _ = _list_leaf_files_with_drive_retry(db, cred, tokens, folder_id)
    except RefreshError as e:
        _raise_gdrive_refresh_http_exception(tokens, e)

    return GDriveFreeFolderManifestOut(file_ids=_ordered_image_file_ids_from_leaf_list(files))


@router.get("/storage/gdrive/free_file/{file_id}")
def download_gdrive_file_for_free_local_sync(
    file_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Free tier: return one Google Drive file's bytes. No R2. Authenticated users only.
    """
    if _tier_uses_cloud_drive_r2_sync(current_user.subscription_tier):
        raise HTTPException(
            status_code=400,
            detail="Plus/Pro should use cloud sync.",
        )

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

    try:
        credentials, refreshed = refresh_google_credentials(tokens)
        _persist_gdrive_tokens(db, cred, tokens, refreshed)
    except RefreshError as e:
        _raise_gdrive_refresh_http_exception(tokens, e)

    try:
        content, mime = download_file_bytes(credentials, file_id)
    except Exception as e:
        logger.exception("GDrive free_file download failed: %s", e)
        raise HTTPException(status_code=400, detail="Failed to download file from Google Drive")

    return Response(content=content, media_type=mime or "application/octet-stream")


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

    if not _tier_uses_cloud_drive_r2_sync(current_user.subscription_tier):
        raise HTTPException(
            status_code=402,
            detail="Cloud scan backup requires Plus or Pro. Free saves scans on this device only.",
        )

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

    if not is_gdrive_oauth_configured():
        raise HTTPException(
            status_code=503,
            detail="Google Drive OAuth is not configured on this server (GOOGLE_CLIENT_ID / GOOGLE_CLIENT_SECRET in backend/.env).",
        )

    tokens_json = decrypt_credential(cred.encrypted_auth_data)
    if not tokens_json:
        raise HTTPException(status_code=400, detail="Failed to decrypt Google Drive credentials")

    try:
        tokens = json.loads(tokens_json)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid Google Drive credentials payload")

    try:
        folder_id = extract_drive_folder_id(payload.folder_url_or_id)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    try:
        files, credentials = _list_leaf_files_with_drive_retry(db, cred, tokens, folder_id)
    except RefreshError as e:
        _raise_gdrive_refresh_http_exception(tokens, e)

    synced_count = 0
    skipped_existing = 0
    total_candidates = 0

    ingest_jobs: List[Tuple[int, str, dict]] = []

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

        ingest_jobs.append((idx, file_id, f))

    # Parallel downloads from Google Drive; uploads to R2 remain sequential (DB + transfer_service).
    downloaded = {}  # file_id -> (bytes, mime)

    def _download_one(fid: str):
        try:
            content, mime = download_file_bytes(credentials, fid)
            return (fid, (content, mime))
        except Exception as e:
            return (fid, e)

    if ingest_jobs:
        unique_ids = list({j[1] for j in ingest_jobs})
        with ThreadPoolExecutor(max_workers=8) as pool:
            futures = {pool.submit(_download_one, fid): fid for fid in unique_ids}
            for fut in as_completed(futures):
                fid, payload = fut.result()
                if isinstance(payload, Exception):
                    logger.exception("Failed to download Drive file %s: %s", fid, payload)
                else:
                    downloaded[fid] = payload

    for idx, file_id, f in sorted(ingest_jobs, key=lambda j: j[0]):
        mime_type = (f.get("mimeType") or "").lower()
        name = (f.get("name") or "").lower()
        if file_id not in downloaded:
            continue
        content, mime = downloaded[file_id]
        logger.info("GDrive sync: ingest file_id=%s name=%s mime=%s bytes=%s", file_id, name, mime_type, len(content))

        # Upload to our storage (full + thumbnail) via TransferService.
        from ...services.transfer_service import transfer_service

        full_key = transfer_service.route_transfer(
            db=db,
            user_id=str(current_user.id),
            roll_id=str(roll.id),
            image_id=file_id,
            file_content=content,
            # SYSTEM_CLOUD: real R2 keys. PERSONAL_CLOUD non-Pro returned gdrive:// stubs
            # which _build_roll_dashboard drops → empty image_urls in the app.
            strategy="SYSTEM_CLOUD",
        )

        existing_frame = (
            db.query(Image)
            .filter(Image.roll_id == roll.id, Image.frame_number == idx)
            .first()
        )
        if existing_frame:
            existing_frame.image_url = full_key
            logger.info("GDrive sync: updated existing frame %d with url", idx)
        else:
            db_image = Image(
                roll_id=roll.id,
                image_url=full_key,
                frame_number=idx,
            )
            db.add(db_image)
            logger.info("GDrive sync: created new frame %d", idx)
        synced_count += 1

    _finalize_roll_after_drive_ingest(db, roll)
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

    # Plus tier or higher required for GDrive sync features
    if current_user.subscription_tier not in ["plus", "pro"]:
        raise HTTPException(
            status_code=status.HTTP_402_PAYMENT_REQUIRED,
            detail="Google Drive sync requires Plus or Pro subscription",
        )

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
        try:
            credentials, refreshed = refresh_google_credentials(tokens)
            _persist_gdrive_tokens(db, cred, tokens, refreshed)
            zip_bytes, _mime = download_file_bytes(credentials, zip_id)
            used_auth = True
        except RefreshError as e:
            if not is_gdrive_oauth_configured():
                _raise_gdrive_refresh_http_exception(tokens, e)
            # Token cannot be refreshed (e.g., access-token-only payload or missing
            # client_id/client_secret). Fall back to public ZIP download if allowed.
            logger.warning(
                "GDrive ZIP download auth failed (expired/no refresh token) for zip_id=%s; falling back to public download",
                zip_id,
            )
            used_auth = False
            try:
                zip_bytes = _download_drive_zip_public(zip_id)
            except HTTPException:
                raise
            except Exception as e:
                logger.error(f"Public fallback failed for zip_id={zip_id}: {e}")
                raise HTTPException(
                    status_code=400,
                    detail="Google Drive credentials expired (cannot refresh) and public download failed. Please try reconnecting Google Drive or ensure the file is publicly accessible.",
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

                # Deterministic key: hash the final bytes we will store.
                # This avoids duplicate ingestion when Drive ZIP downloads differ
                # in metadata (e.g. ZipEntry CRC) between sync runs.
                image_id = hashlib.sha1(file_content).hexdigest()

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

                # Upload to R2 (enforces quota). Same rationale as folder ingest above.
                from ...services.transfer_service import transfer_service
                full_key = transfer_service.route_transfer(
                    db=db,
                    user_id=str(current_user.id),
                    roll_id=str(roll.id),
                    image_id=image_id,
                    file_content=file_content,
                    strategy="SYSTEM_CLOUD",
                )

                # Match or create Image record by roll_id and frame_number
                existing_frame = (
                    db.query(Image)
                    .filter(Image.roll_id == roll.id, Image.frame_number == idx)
                    .first()
                )
                if existing_frame:
                    existing_frame.image_url = full_key
                    logger.info("GDrive sync: [zip] updated existing frame %d with url", idx)
                else:
                    db_image = Image(
                        roll_id=roll.id,
                        image_url=full_key,
                        frame_number=idx,
                    )
                    db.add(db_image)
                    logger.info("GDrive sync: [zip] created new frame %d", idx)
                synced_count += 1

            _finalize_roll_after_drive_ingest(db, roll)
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


def _perform_gdrive_sync(user_id: str, roll_id: str, gdrive_url_or_id: str):
    """Refactored background worker task for GDrive sync."""
    from ...db.session import SessionLocal
    db = SessionLocal()
    try:
        current_user = db.query(User).filter(User.id == user_id).first()
        if not current_user:
            logger.error(f"[Sync] User {user_id} not found")
            return

        if not _tier_uses_cloud_drive_r2_sync(current_user.subscription_tier):
            roll = db.query(Roll).filter(Roll.id == roll_id).first()
            if roll and roll.status == RollStatusEnum.syncing:
                roll.status = RollStatusEnum.lab
                db.add(roll)
                db.commit()
            return

        roll = db.query(Roll).filter(Roll.id == roll_id).first()
        if not roll:
            logger.error(f"[Sync] Roll {roll_id} not found")
            return

        # 1. Status is already set to syncing by the request handler for immediate feedback
        # roll.status = RollStatusEnum.syncing
        # db.add(roll)
        # db.commit()

        # 2. Perform the sync
        payload = GDriveSyncImagesFromUrlRequest(roll_id=roll_id, gdrive_url_or_id=gdrive_url_or_id)
        # Note: We call the endpoint function but it works because it's just a function.
        # However, we need to handle the return value or errors.
        try:
            raw = (payload.gdrive_url_or_id or "").strip()
            result = None
            try:
                node_id = extract_drive_folder_id(raw)
            except ValueError:
                logger.error("[Sync] Could not parse Drive URL for roll %s (snippet=%r)", roll_id, raw[:120])
                db.refresh(roll)
                roll.status = RollStatusEnum.lab
                db.add(roll)
                db.commit()
                return

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
                logger.error("[Sync] No Google Drive connection for user %s", user_id)
                db.refresh(roll)
                roll.status = RollStatusEnum.lab
                db.add(roll)
                db.commit()
                return

            tokens_json = decrypt_credential(cred.encrypted_auth_data)
            if not tokens_json:
                logger.error("[Sync] Could not decrypt GDrive credentials for user %s", user_id)
                db.refresh(roll)
                roll.status = RollStatusEnum.lab
                db.add(roll)
                db.commit()
                return

            try:
                tokens = json.loads(tokens_json)
            except Exception:
                logger.exception("[Sync] Invalid GDrive token JSON for user %s", user_id)
                db.refresh(roll)
                roll.status = RollStatusEnum.lab
                db.add(roll)
                db.commit()
                return

            try:
                credentials, refreshed = refresh_google_credentials(tokens)
                _persist_gdrive_tokens(db, cred, tokens, refreshed)
            except RefreshError as e:
                logger.warning("[Sync] GDrive token refresh failed: %s", e)
                db.refresh(roll)
                roll.status = RollStatusEnum.lab
                db.add(roll)
                db.commit()
                return

            mime = get_drive_entry_mime_type(credentials, node_id)
            if mime == _GOOGLE_DRIVE_FOLDER_MIME:
                result = sync_gdrive_leaf_files(
                    payload=GDriveSyncRequest(roll_id=payload.roll_id, folder_url_or_id=raw),
                    current_user=current_user,
                    db=db,
                )
            elif mime:
                result = sync_gdrive_zip_images(
                    payload=GDriveZipSyncRequest(roll_id=payload.roll_id, zip_url_or_id=raw),
                    current_user=current_user,
                    db=db,
                )
            else:
                # files.get failed — fall back to URL substring heuristics (older behavior)
                raw_lower = raw.lower()
                if "/folders/" in raw_lower:
                    result = sync_gdrive_leaf_files(
                        payload=GDriveSyncRequest(roll_id=payload.roll_id, folder_url_or_id=raw),
                        current_user=current_user,
                        db=db,
                    )
                elif "/file/d/" in raw_lower or "export=download" in raw_lower or raw_lower.endswith(".zip"):
                    result = sync_gdrive_zip_images(
                        payload=GDriveZipSyncRequest(roll_id=payload.roll_id, zip_url_or_id=raw),
                        current_user=current_user,
                        db=db,
                    )
                else:
                    logger.error(
                        "[Sync] Could not resolve Drive url for roll %s id=%s (mime lookup returned None)",
                        roll_id,
                        node_id,
                    )
                    db.refresh(roll)
                    roll.status = RollStatusEnum.lab
                    db.add(roll)
                    db.commit()
                    return

            if result:
                logger.info(
                    "[Sync] roll=%s candidates=%s synced=%s skipped=%s",
                    roll_id,
                    result.get("total_image_candidates"),
                    result.get("synced_count"),
                    result.get("skipped_existing"),
                )
                
        except Exception as e:
            logger.exception(f"[Sync] Background sync failed for roll {roll_id}: {e}")
            # Reset status to lab so user can try again
            db.refresh(roll)
            roll.status = RollStatusEnum.lab
            db.add(roll)
            db.commit()

    finally:
        db.close()


@router.post("/storage/gdrive/sync_images_from_url")
async def sync_images_from_url(
    payload: GDriveSyncImagesFromUrlRequest,
    background_tasks: BackgroundTasks,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Convenience wrapper:
    - If URL looks like a Drive folder: route to `sync_leaf_files`.
    - If URL looks like a Drive file: route to `sync_zip_images`.

    If background_tasks is provided, this returns 202 immediately and runs in background.
    """
    if not _tier_uses_cloud_drive_r2_sync(current_user.subscription_tier):
        raise HTTPException(
            status_code=402,
            detail="Cloud scan backup requires Plus or Pro. Free saves scans on this device only.",
        )

    raw = (payload.gdrive_url_or_id or "").strip()
    if not raw:
        raise HTTPException(status_code=400, detail="gdrive_url_or_id is required")

    # Always queue background ingest — holds a DB session for minutes when done inline.
    roll = db.query(Roll).filter(Roll.id == payload.roll_id, Roll.user_id == current_user.id).first()
    if roll:
        roll.status = RollStatusEnum.syncing
        db.add(roll)
        db.commit()

    background_tasks.add_task(_perform_gdrive_sync, current_user.id, payload.roll_id, payload.gdrive_url_or_id)
    return {"detail": "Sync started in background"}
