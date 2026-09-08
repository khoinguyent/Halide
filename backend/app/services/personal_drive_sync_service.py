"""
Sync rolls to the user's personal Google Drive under ``Agxel Vault``.

Layout:
  Agxel Vault/
    {Roll Title}/
      README.txt          # description, film, iso
      001.jpg, 002.jpg…   # full-quality frames

Idempotency: ``PersonalDriveRollSync`` / ``PersonalDriveImageSync`` (see
``db/models/personal_drive_sync.py``) persist a content hash + remote file id per
image and a folder id + README hash per roll, so re-running a sync only touches
frames that actually changed, and unaffected rolls can be skipped outright.
"""
from __future__ import annotations

import hashlib
import json
import logging
import re
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Tuple

from sqlalchemy.orm import Session

from ..core.encryption import decrypt_credential, encrypt_credential
from ..db.models.film_stock import FilmStock
from ..db.models.image import Image
from ..db.models.personal_drive_sync import (
    PersonalDriveImageSync,
    PersonalDriveRollSync,
    PersonalDriveSyncStatus,
)
from ..db.models.roll import Roll
from ..db.models.storage_credential import StorageCredential, StorageProviderEnum
from . import google_drive_service as gdrive
from .storage_service import storage_service

logger = logging.getLogger(__name__)

_README_NAME = "README.txt"


def _users_key_from_image_url(raw: Optional[str]) -> Optional[str]:
    if not raw or not isinstance(raw, str):
        return None
    s = raw.strip()
    if not s:
        return None
    if s.startswith("users/"):
        return s.split("?", 1)[0].rstrip("/")
    if s.startswith("http://") or s.startswith("https://"):
        idx = s.find("/users/")
        if idx >= 0:
            return s[idx + 1 :].split("?", 1)[0].rstrip("/")
    return None


def _sanitize_folder_name(title: Optional[str]) -> str:
    """Drive forbids ``/`` in names; collapse other control chars."""
    name = (title or "").strip() or "Untitled Roll"
    name = re.sub(r"[/\x00-\x1f]", " ", name)
    name = re.sub(r"\s+", " ", name).strip()
    return name[:200] or "Untitled Roll"


def _frame_filename(frame_number: Optional[int], image_id: str, index: int) -> str:
    if frame_number is not None and frame_number > 0:
        return f"{int(frame_number):03d}.jpg"
    return f"{index:03d}_{image_id}.jpg"


def _sha256_hex(content: bytes) -> str:
    return hashlib.sha256(content).hexdigest()


def _now() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


def build_roll_readme(roll: Roll, film: Optional[FilmStock]) -> str:
    title = (roll.title or "").strip() or "Untitled Roll"
    description = (roll.description or "").strip() or "(none)"
    if film:
        film_label = f"{film.brand} {film.name}".strip()
        catalog_iso = film.iso
    else:
        film_label = "(unknown)"
        catalog_iso = None
    shot_iso = roll.shot_at_iso
    iso_parts = []
    if shot_iso is not None:
        iso_parts.append(f"shot at {shot_iso}")
    if catalog_iso is not None:
        iso_parts.append(f"stock {catalog_iso}")
    iso_line = ", ".join(iso_parts) if iso_parts else "(unknown)"

    return "\n".join(
        [
            "Agxel Vault — Roll Archive",
            "",
            f"Title: {title}",
            f"Description: {description}",
            f"Film: {film_label}",
            f"ISO: {iso_line}",
            f"Roll ID: {roll.id}",
            "",
        ]
    )


def get_personal_gdrive_credential(db: Session, user_id: str) -> Optional[StorageCredential]:
    """Prefer primary Google Drive, else any archive-flagged Drive connection."""
    primary = (
        db.query(StorageCredential)
        .filter(
            StorageCredential.user_id == user_id,
            StorageCredential.provider == StorageProviderEnum.gdrive,
            StorageCredential.is_primary == True,  # noqa: E712
        )
        .first()
    )
    if primary:
        return primary
    return (
        db.query(StorageCredential)
        .filter(
            StorageCredential.user_id == user_id,
            StorageCredential.provider == StorageProviderEnum.gdrive,
            StorageCredential.is_archive == True,  # noqa: E712
        )
        .first()
    )


def _load_gdrive_credentials(db: Session, cred: StorageCredential) -> Tuple[Any, Dict[str, Any]]:
    if not gdrive.is_gdrive_oauth_configured():
        raise RuntimeError("Google Drive OAuth is not configured on this server")

    tokens_json = decrypt_credential(cred.encrypted_auth_data)
    if not tokens_json:
        raise RuntimeError("Failed to decrypt Google Drive credentials")
    try:
        tokens = json.loads(tokens_json)
    except Exception as e:
        raise RuntimeError(f"Invalid Google Drive credentials payload: {e}") from e

    credentials, refreshed = gdrive.refresh_google_credentials(tokens)
    if refreshed:
        cred.encrypted_auth_data = encrypt_credential(json.dumps(tokens))
        db.add(cred)
        db.commit()
    return credentials, tokens


def _get_or_create_roll_sync(
    db: Session, *, roll_id: str, storage_credential_id: Optional[str]
) -> PersonalDriveRollSync:
    row = db.query(PersonalDriveRollSync).filter(PersonalDriveRollSync.roll_id == roll_id).first()
    if row:
        return row
    row = PersonalDriveRollSync(
        roll_id=roll_id,
        storage_credential_id=storage_credential_id,
        status=PersonalDriveSyncStatus.pending,
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


def _ensure_roll_folder(credentials, roll: Roll, roll_sync: PersonalDriveRollSync, db: Session) -> Dict[str, Any]:
    """Reuse the cached folder id when possible; validate it still resolves on Drive."""
    if roll_sync.drive_folder_id:
        existing = gdrive.get_drive_entry_mime_type(credentials, roll_sync.drive_folder_id)
        if existing:  # folder (or anything) still exists remotely
            return {"id": roll_sync.drive_folder_id}

    vault = gdrive.ensure_agxel_vault_folder(credentials)
    folder_name = _sanitize_folder_name(roll.title)
    folder = gdrive.find_or_create_folder(credentials, folder_name, parent_id=vault["id"])
    roll_sync.drive_folder_id = folder["id"]
    db.add(roll_sync)
    db.commit()
    return folder


def _write_readme_if_changed(
    credentials, roll_folder_id: str, roll: Roll, film: Optional[FilmStock], roll_sync: PersonalDriveRollSync, db: Session
) -> None:
    body_text = build_roll_readme(roll, film)
    new_hash = _sha256_hex(body_text.encode("utf-8"))
    if roll_sync.readme_hash == new_hash:
        return
    gdrive.upload_or_update_file(
        credentials,
        parent_id=roll_folder_id,
        name=_README_NAME,
        file_content=body_text.encode("utf-8"),
        mime_type="text/plain",
    )
    roll_sync.readme_hash = new_hash
    db.add(roll_sync)
    db.commit()


def roll_needs_personal_drive_sync(db: Session, roll: Roll) -> bool:
    """
    True when the roll has at least one R2-backed image not yet reflected (by content
    hash) in ``PersonalDriveImageSync``, or has never been synced.
    """
    roll_sync = db.query(PersonalDriveRollSync).filter(PersonalDriveRollSync.roll_id == roll.id).first()
    if not roll_sync or roll_sync.status != PersonalDriveSyncStatus.synced:
        # Never synced, or last attempt didn't finish cleanly — still only worth
        # trying if there is something to upload.
        has_any = (
            db.query(Image)
            .filter(Image.roll_id == roll.id)
            .filter(Image.image_url.isnot(None))
            .filter(Image.image_url != "")
            .first()
        )
        return has_any is not None

    images = db.query(Image).filter(Image.roll_id == roll.id).all()
    synced_by_image = {
        row.image_id: row
        for row in db.query(PersonalDriveImageSync).filter(PersonalDriveImageSync.roll_sync_id == roll_sync.id).all()
    }
    for img in images:
        key = _users_key_from_image_url(img.image_url)
        if not key or key.endswith("_thumb.jpg"):
            continue
        existing = synced_by_image.get(img.id)
        if not existing or existing.status != PersonalDriveSyncStatus.synced:
            return True
        # Cheap staleness check without downloading bytes: if we've never recorded a
        # hash for this image, treat it as needing a (re)upload.
        if not existing.content_hash:
            return True
    return False


def upload_image_bytes_to_roll_folder(
    db: Session,
    *,
    user_id: str,
    roll_id: str,
    image_id: str,
    file_content: bytes,
    frame_number: Optional[int] = None,
    filename: Optional[str] = None,
) -> str:
    """
    Upload one full-quality image into Agxel Vault/{roll title}/.
    Also refreshes README.txt when it changed. Returns ``gdrive://{file_id}``.
    Records/updates the per-image sync row so a later full-roll sync can skip it
    if the bytes are unchanged.
    """
    cred = get_personal_gdrive_credential(db, user_id)
    if not cred:
        raise RuntimeError("No personal Google Drive configuration found")

    roll = db.query(Roll).filter(Roll.id == roll_id, Roll.user_id == user_id).first()
    if not roll:
        raise RuntimeError("Roll not found")

    film = None
    if roll.film_stock_id:
        film = db.query(FilmStock).filter(FilmStock.id == roll.film_stock_id).first()

    credentials, _ = _load_gdrive_credentials(db, cred)
    roll_sync = _get_or_create_roll_sync(db, roll_id=str(roll.id), storage_credential_id=str(cred.id))
    roll_folder = _ensure_roll_folder(credentials, roll, roll_sync, db)
    _write_readme_if_changed(credentials, roll_folder["id"], roll, film, roll_sync, db)

    content_hash = _sha256_hex(file_content)
    image_sync = (
        db.query(PersonalDriveImageSync).filter(PersonalDriveImageSync.image_id == image_id).first()
    )
    if image_sync and image_sync.content_hash == content_hash and image_sync.status == PersonalDriveSyncStatus.synced:
        # Bytes unchanged since last upload — no Drive API call needed.
        return f"gdrive://{image_sync.drive_file_id}" if image_sync.drive_file_id else f"gdrive://{image_id}"

    name = filename or _frame_filename(frame_number, image_id, 1)
    uploaded = gdrive.upload_or_update_file(
        credentials,
        parent_id=roll_folder["id"],
        name=name,
        file_content=file_content,
        mime_type="image/jpeg",
    )
    file_id = uploaded.get("id") or image_id

    if image_sync is None:
        image_sync = PersonalDriveImageSync(image_id=image_id, roll_sync_id=roll_sync.id)
    image_sync.roll_sync_id = roll_sync.id
    image_sync.drive_file_id = file_id
    image_sync.content_hash = content_hash
    image_sync.status = PersonalDriveSyncStatus.synced
    image_sync.synced_at = _now()
    image_sync.last_error = None
    db.add(image_sync)
    db.commit()

    return f"gdrive://{file_id}"


def sync_roll_to_personal_gdrive(
    db: Session, *, user_id: str, roll_id: str, force: bool = False
) -> Dict[str, Any]:
    """
    Sync an entire roll to personal Drive: Agxel Vault / {title} / README.txt +
    full-quality frames. Skips frames whose content hash already matches the last
    successful upload unless ``force`` is set.
    """
    cred = get_personal_gdrive_credential(db, user_id)
    if not cred:
        raise RuntimeError("No personal Google Drive configuration found")

    roll = db.query(Roll).filter(Roll.id == roll_id, Roll.user_id == user_id).first()
    if not roll:
        raise RuntimeError("Roll not found")

    roll_sync = _get_or_create_roll_sync(db, roll_id=str(roll.id), storage_credential_id=str(cred.id))
    roll_sync.status = PersonalDriveSyncStatus.syncing
    roll_sync.last_error = None
    db.add(roll_sync)
    db.commit()

    try:
        film = None
        if roll.film_stock_id:
            film = db.query(FilmStock).filter(FilmStock.id == roll.film_stock_id).first()

        credentials, _ = _load_gdrive_credentials(db, cred)
        roll_folder = _ensure_roll_folder(credentials, roll, roll_sync, db)
        _write_readme_if_changed(credentials, roll_folder["id"], roll, film, roll_sync, db)

        images: List[Image] = (
            db.query(Image)
            .filter(Image.roll_id == roll.id)
            .order_by(Image.frame_number.asc().nulls_last(), Image.created_at)
            .all()
        )

        existing_syncs = {
            row.image_id: row
            for row in db.query(PersonalDriveImageSync)
            .filter(PersonalDriveImageSync.roll_sync_id == roll_sync.id)
            .all()
        }

        uploaded = 0
        skipped = 0
        failed = 0
        errors: List[str] = []
        eligible_total = 0

        for index, img in enumerate(images, start=1):
            key = _users_key_from_image_url(img.image_url)
            if not key or key.endswith("_thumb.jpg"):
                skipped += 1
                continue
            eligible_total += 1

            content = storage_service.get_object_bytes(key)
            if not content:
                failed += 1
                errors.append(f"missing bytes for image {img.id}")
                row = existing_syncs.get(img.id)
                if row is None:
                    row = PersonalDriveImageSync(image_id=img.id, roll_sync_id=roll_sync.id)
                row.status = PersonalDriveSyncStatus.failed
                row.last_error = "missing R2 bytes"
                db.add(row)
                continue

            content_hash = _sha256_hex(content)
            row = existing_syncs.get(img.id)
            if (
                not force
                and row is not None
                and row.status == PersonalDriveSyncStatus.synced
                and row.content_hash == content_hash
            ):
                skipped += 1
                continue

            name = _frame_filename(img.frame_number, str(img.id), index)
            try:
                result = gdrive.upload_or_update_file(
                    credentials,
                    parent_id=roll_folder["id"],
                    name=name,
                    file_content=content,
                    mime_type="image/jpeg",
                )
                if row is None:
                    row = PersonalDriveImageSync(image_id=img.id, roll_sync_id=roll_sync.id)
                row.drive_file_id = result.get("id")
                row.content_hash = content_hash
                row.status = PersonalDriveSyncStatus.synced
                row.synced_at = _now()
                row.last_error = None
                db.add(row)
                uploaded += 1
            except Exception as e:
                logger.exception("Personal Drive upload failed for image %s: %s", img.id, e)
                if row is None:
                    row = PersonalDriveImageSync(image_id=img.id, roll_sync_id=roll_sync.id)
                row.status = PersonalDriveSyncStatus.failed
                row.last_error = str(e)
                db.add(row)
                failed += 1
                errors.append(f"image {img.id}: {e}")

        db.commit()

        roll_sync.images_total = eligible_total
        # Cumulative count of frames currently in "synced" state, not just this pass.
        roll_sync.images_uploaded = (
            db.query(PersonalDriveImageSync)
            .filter(
                PersonalDriveImageSync.roll_sync_id == roll_sync.id,
                PersonalDriveImageSync.status == PersonalDriveSyncStatus.synced,
            )
            .count()
        )
        roll_sync.status = PersonalDriveSyncStatus.failed if failed and not uploaded and not skipped else PersonalDriveSyncStatus.synced
        roll_sync.last_synced_at = _now()
        if errors:
            roll_sync.last_error = "; ".join(errors[:5])
        db.add(roll_sync)
        db.commit()

        return {
            "roll_id": str(roll.id),
            "folder_name": _sanitize_folder_name(roll.title),
            "folder_id": roll_folder.get("id"),
            "uploaded": uploaded,
            "skipped": skipped,
            "failed": failed,
            "errors": errors,
        }
    except Exception as e:
        roll_sync.status = PersonalDriveSyncStatus.failed
        roll_sync.last_error = str(e)
        db.add(roll_sync)
        db.commit()
        raise

