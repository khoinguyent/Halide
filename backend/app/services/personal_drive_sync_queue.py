"""
Async, bounded-concurrency queue for syncing many rolls to a user's personal Drive
in one request.

Why a DB-backed queue (not just ``asyncio.create_task``): the API can return a job id
immediately (202-style), the mobile app can poll progress, and a periodic worker tick
(APScheduler, see ``tasks/transfer_worker.py``) can pick up anything left ``queued`` if
the process restarted mid-job. ``SELECT ... FOR UPDATE SKIP LOCKED`` on claim makes it
safe to run the tick and an explicit API-triggered run concurrently without double
processing the same job.

Why asyncio at all when SQLAlchemy/Drive calls are sync: each roll's sync runs in its
own thread (``asyncio.to_thread``) with its own DB session, bounded by a semaphore, so
multiple rolls upload concurrently (bounded to avoid hammering the Drive API / DB pool)
while the event loop stays free to report progress.
"""
from __future__ import annotations

import asyncio
import logging
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

from sqlalchemy.orm import Session

from ..db.models.personal_drive_sync import PersonalDriveSyncJob, PersonalDriveSyncJobStatus
from ..db.models.roll import Roll
from ..db.session import SessionLocal
from .personal_drive_sync_service import (
    get_personal_gdrive_credential,
    roll_needs_personal_drive_sync,
    sync_roll_to_personal_gdrive,
)

logger = logging.getLogger(__name__)

# Cap concurrent Drive uploads per job so we don't trip Google's per-user rate limits
# or exhaust the SQLAlchemy connection pool with one job per roll thread.
MAX_CONCURRENT_ROLL_SYNCS = 3


def _now() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


def enqueue_personal_drive_sync_job(
    db: Session, *, user_id: str, roll_ids: Optional[List[str]] = None, force: bool = False
) -> PersonalDriveSyncJob:
    """Insert a queued job row. Caller decides whether/when to kick off processing."""
    job = PersonalDriveSyncJob(
        user_id=user_id,
        roll_ids=list(roll_ids) if roll_ids else None,
        force=force,
        status=PersonalDriveSyncJobStatus.queued,
    )
    db.add(job)
    db.commit()
    db.refresh(job)
    return job


def _claim_job(db: Session, job_id: str) -> Optional[PersonalDriveSyncJob]:
    """
    Atomically claim one queued job for processing. Uses SKIP LOCKED so a periodic
    worker tick and a direct API-triggered run never process the same job twice.
    """
    row = (
        db.query(PersonalDriveSyncJob)
        .filter(PersonalDriveSyncJob.id == job_id, PersonalDriveSyncJob.status == PersonalDriveSyncJobStatus.queued)
        .with_for_update(skip_locked=True)
        .first()
    )
    if not row:
        return None
    row.status = PersonalDriveSyncJobStatus.running
    row.started_at = _now()
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


def _claim_any_queued_job(db: Session) -> Optional[PersonalDriveSyncJob]:
    row = (
        db.query(PersonalDriveSyncJob)
        .filter(PersonalDriveSyncJob.status == PersonalDriveSyncJobStatus.queued)
        .order_by(PersonalDriveSyncJob.created_at.asc())
        .with_for_update(skip_locked=True)
        .first()
    )
    if not row:
        return None
    row.status = PersonalDriveSyncJobStatus.running
    row.started_at = _now()
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


def _sync_one_roll_blocking(user_id: str, roll_id: str, force: bool = False) -> Dict[str, Any]:
    """Runs in a worker thread with its own DB session (SQLAlchemy sessions aren't thread-safe to share)."""
    db = SessionLocal()
    try:
        return sync_roll_to_personal_gdrive(db, user_id=user_id, roll_id=roll_id, force=force)
    except Exception as e:
        return {"roll_id": roll_id, "error": str(e)}
    finally:
        db.close()


async def _run_job_async(job_id: str) -> None:
    db = SessionLocal()
    try:
        job = db.query(PersonalDriveSyncJob).filter(PersonalDriveSyncJob.id == job_id).first()
        if not job or job.status != PersonalDriveSyncJobStatus.running:
            return

        user_id = job.user_id
        requested_roll_ids = list(job.roll_ids) if job.roll_ids else None
        force = bool(job.force)

        if not get_personal_gdrive_credential(db, user_id):
            job.status = PersonalDriveSyncJobStatus.failed
            job.error = "No personal Google Drive configuration found"
            job.finished_at = _now()
            db.add(job)
            db.commit()
            return

        if requested_roll_ids:
            rolls = db.query(Roll).filter(Roll.user_id == user_id, Roll.id.in_(requested_roll_ids)).all()
            target_roll_ids = [str(r.id) for r in rolls]
        else:
            rolls = db.query(Roll).filter(Roll.user_id == user_id).all()
            target_roll_ids = [str(r.id) for r in rolls if roll_needs_personal_drive_sync(db, r)]

        job.total_rolls = len(target_roll_ids)
        db.add(job)
        db.commit()
    finally:
        db.close()

    if not target_roll_ids:
        db = SessionLocal()
        try:
            job = db.query(PersonalDriveSyncJob).filter(PersonalDriveSyncJob.id == job_id).first()
            job.status = PersonalDriveSyncJobStatus.succeeded
            job.result = []
            job.finished_at = _now()
            db.add(job)
            db.commit()
        finally:
            db.close()
        return

    semaphore = asyncio.Semaphore(MAX_CONCURRENT_ROLL_SYNCS)
    results: List[Dict[str, Any]] = []
    completed = 0
    failed = 0

    async def _run_bounded(rid: str) -> Dict[str, Any]:
        async with semaphore:
            return await asyncio.to_thread(_sync_one_roll_blocking, user_id, rid, force)

    tasks = [asyncio.create_task(_run_bounded(rid)) for rid in target_roll_ids]
    for finished in asyncio.as_completed(tasks):
        result = await finished
        results.append(result)
        if result.get("error"):
            failed += 1
        else:
            completed += 1

        # Persist progress incrementally so the app can poll mid-run.
        db = SessionLocal()
        try:
            job = db.query(PersonalDriveSyncJob).filter(PersonalDriveSyncJob.id == job_id).first()
            if job:
                job.completed_rolls = completed
                job.failed_rolls = failed
                job.result = results
                db.add(job)
                db.commit()
        finally:
            db.close()

    db = SessionLocal()
    try:
        job = db.query(PersonalDriveSyncJob).filter(PersonalDriveSyncJob.id == job_id).first()
        if job:
            if failed == 0:
                job.status = PersonalDriveSyncJobStatus.succeeded
            elif completed == 0:
                job.status = PersonalDriveSyncJobStatus.failed
            else:
                job.status = PersonalDriveSyncJobStatus.partial
            job.finished_at = _now()
            db.add(job)
            db.commit()
    finally:
        db.close()


async def process_job(job_id: str) -> None:
    """Claim (if still queued) and run one job to completion."""
    db = SessionLocal()
    try:
        claimed = _claim_job(db, job_id)
    finally:
        db.close()
    if not claimed:
        return
    await _run_job_async(job_id)


async def process_queued_jobs(limit: int = 10) -> int:
    """Claim and run up to ``limit`` queued jobs (any user). Used by the periodic worker tick."""
    processed = 0
    while processed < limit:
        db = SessionLocal()
        try:
            job = _claim_any_queued_job(db)
        finally:
            db.close()
        if not job:
            break
        await _run_job_async(str(job.id))
        processed += 1
    return processed


def run_job_in_background(job_id: str) -> None:
    """
    Fire-and-forget an asyncio task for this job on the current event loop, falling
    back to a fresh loop when called from sync contexts (e.g. the APScheduler tick).
    """
    try:
        loop = asyncio.get_running_loop()
        loop.create_task(process_job(job_id))
    except RuntimeError:
        asyncio.run(process_job(job_id))
