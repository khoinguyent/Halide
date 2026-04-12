#!/usr/bin/env python3
"""
One-off: create Firebase + DB user for App Review, set Pro, clone data from source user by email.

Usage (from backend dir, with env loaded):
  ENV_FILE=.env.prod python scripts/clone_review_user.py

Requires: FIREBASE_SERVICE_ACCOUNT_JSON, DATABASE_URL, Firebase Admin SDK.
"""
from __future__ import annotations

import os
import sys
import uuid
from pathlib import Path

# Backend package on path — load .env.prod when present (local); Docker often has env vars only.
_BACKEND = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(_BACKEND))
_env_prod = _BACKEND / ".env.prod"
if _env_prod.is_file():
    os.environ["ENV_FILE"] = str(_env_prod)

from sqlalchemy.orm import Session  # noqa: E402

from app.core.firebase import init_firebase  # noqa: E402
from app.db.session import SessionLocal  # noqa: E402
from app.db.models.user import User, PRO_STORAGE_LIMIT  # noqa: E402
from app.db.models.camera import UserCamera, UserLens  # noqa: E402
from app.db.models.roll import Roll  # noqa: E402
from app.db.models.image import Image  # noqa: E402
from app.db.models.storage_credential import StorageCredential  # noqa: E402

from firebase_admin import auth as firebase_auth  # noqa: E402

SOURCE_EMAIL = "khoinguyen.to@gmail.com"
TARGET_EMAIL = "apple-review@halide.io.vn"
TARGET_PASSWORD = os.environ.get("REVIEW_USER_PASSWORD", "Halide2026Pro!")


def get_or_create_firebase_user(email: str, password: str) -> str:
    init_firebase()
    try:
        rec = firebase_auth.create_user(email=email, password=password, email_verified=True)
        print(f"[Firebase] Created user uid={rec.uid}")
        return rec.uid
    except firebase_auth.EmailAlreadyExistsError:
        rec = firebase_auth.get_user_by_email(email)
        print(f"[Firebase] User already exists uid={rec.uid}")
        return rec.uid


def ensure_target_db_user(db: Session, uid: str, email: str) -> User:
    u = db.query(User).filter(User.id == uid).first()
    if u:
        u.email = email
        u.subscription_tier = "pro"
        u.storage_limit_bytes = PRO_STORAGE_LIMIT
        u.display_name = u.display_name or "Apple Review"
        print(f"[DB] Updated existing user {uid} -> pro")
        return u
    u = User(
        id=uid,
        email=email,
        display_name="Apple Review",
        subscription_tier="pro",
        storage_limit_bytes=PRO_STORAGE_LIMIT,
        storage_used_bytes=0,
        has_seen_onboarding=True,
        has_seen_roll_guide=True,
        has_seen_lab_guide=True,
    )
    db.add(u)
    print(f"[DB] Inserted user {uid}")
    return u


def main() -> None:
    db: Session = SessionLocal()
    try:
        src = db.query(User).filter(User.email == SOURCE_EMAIL).first()
        if not src:
            print(f"ERROR: No user with email {SOURCE_EMAIL}")
            sys.exit(1)
        print(f"[DB] Source user id={src.id} email={src.email}")

        tgt_uid = get_or_create_firebase_user(TARGET_EMAIL, TARGET_PASSWORD)
        ensure_target_db_user(db, tgt_uid, TARGET_EMAIL)
        db.flush()

        if (
            db.query(UserCamera).filter(UserCamera.user_id == tgt_uid).count() > 0
            or db.query(Roll).filter(Roll.user_id == tgt_uid).count() > 0
        ):
            if os.environ.get("FORCE_CLONE") != "1":
                print(
                    "ERROR: Target user already has gear or rolls. "
                    "Set FORCE_CLONE=1 to abort duplicate run (no auto-delete)."
                )
                sys.exit(1)

        # Maps old UUID -> new UUID
        cam_map: dict[uuid.UUID, uuid.UUID] = {}
        lens_map: dict[uuid.UUID, uuid.UUID] = {}
        roll_map: dict[uuid.UUID, uuid.UUID] = {}

        # 1) User cameras
        for uc in db.query(UserCamera).filter(UserCamera.user_id == src.id).all():
            nid = uuid.uuid4()
            cam_map[uc.id] = nid
            db.add(
                UserCamera(
                    id=nid,
                    user_id=tgt_uid,
                    camera_id=uc.camera_id,
                    gear_nickname=uc.gear_nickname,
                    rating_functional=uc.rating_functional,
                    rating_view=uc.rating_view,
                    rating_looking=uc.rating_looking,
                    status=uc.status,
                    image_urls=uc.image_urls,
                    primary_image_index=uc.primary_image_index,
                )
            )
        print(f"[DB] Cloned {len(cam_map)} user_cameras")

        # 2) User lenses (after cameras for FK)
        for ul in db.query(UserLens).filter(UserLens.user_id == src.id).all():
            nid = uuid.uuid4()
            lens_map[ul.id] = nid
            new_parent = cam_map.get(ul.parent_camera_id) if ul.parent_camera_id else None
            db.add(
                UserLens(
                    id=nid,
                    user_id=tgt_uid,
                    lens_id=ul.lens_id,
                    parent_camera_id=new_parent,
                    gear_nickname=ul.gear_nickname,
                    serial_number=ul.serial_number,
                    notes=ul.notes,
                )
            )
        print(f"[DB] Cloned {len(lens_map)} user_lenses")

        # 3) Rolls
        for r in db.query(Roll).filter(Roll.user_id == src.id).all():
            nid = uuid.uuid4()
            roll_map[r.id] = nid
            nc = cam_map.get(r.user_camera_id) if r.user_camera_id else None
            nl = lens_map.get(r.user_lens_id) if r.user_lens_id else None
            db.add(
                Roll(
                    id=nid,
                    user_id=tgt_uid,
                    film_stock_id=r.film_stock_id,
                    user_camera_id=nc,
                    user_lens_id=nl,
                    shot_at_iso=r.shot_at_iso,
                    expired_year=r.expired_year,
                    max_frames=r.max_frames,
                    status=r.status,
                    title=r.title,
                    description=r.description,
                    drive_url=r.drive_url,
                    shot_offset=r.shot_offset,
                )
            )
        print(f"[DB] Cloned {len(roll_map)} rolls")
        db.flush()  # Ensure new roll rows exist before images reference roll_id (FK order)

        # 4) Images
        n_img = 0
        for r_old, r_new in roll_map.items():
            for im in db.query(Image).filter(Image.roll_id == r_old).all():
                db.add(
                    Image(
                        id=uuid.uuid4(),
                        roll_id=r_new,
                        frame_number=im.frame_number,
                        image_url=im.image_url,
                        aperture=im.aperture,
                        shutter_speed=im.shutter_speed,
                        notes=im.notes,
                        location_lat=im.location_lat,
                        location_lng=im.location_lng,
                    )
                )
                n_img += 1
        print(f"[DB] Cloned {n_img} images")

        # 5) Storage credentials (tokens are copied; reviewer may need to reconnect OAuth)
        n_st = 0
        for sc in db.query(StorageCredential).filter(StorageCredential.user_id == src.id).all():
            db.add(
                StorageCredential(
                    id=uuid.uuid4(),
                    user_id=tgt_uid,
                    provider=sc.provider,
                    identifier=sc.identifier,
                    host=sc.host,
                    username=sc.username,
                    encrypted_auth_data=sc.encrypted_auth_data,
                    display_label=sc.display_label,
                    is_primary=sc.is_primary,
                    is_archive=sc.is_archive,
                    is_scan_sync=sc.is_scan_sync,
                )
            )
            n_st += 1
        print(f"[DB] Cloned {n_st} storage_credentials (OAuth may require re-login for review account)")

        # Pro storage: mirror source used bytes cap (optional — keep under pro limit)
        tgt = db.query(User).filter(User.id == tgt_uid).first()
        if tgt and src.storage_used_bytes:
            tgt.storage_used_bytes = min(src.storage_used_bytes, tgt.total_storage_limit)

        db.commit()
        print("Done. Target login:", TARGET_EMAIL, "/ password from REVIEW_USER_PASSWORD or default.")
    except Exception as e:
        db.rollback()
        print("ERROR:", e)
        raise
    finally:
        db.close()


if __name__ == "__main__":
    main()
