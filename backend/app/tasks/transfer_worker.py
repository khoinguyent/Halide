import asyncio

from apscheduler.schedulers.background import BackgroundScheduler
from ..services.transfer_service import transfer_service
from ..services.personal_drive_sync_queue import process_queued_jobs

scheduler = BackgroundScheduler()

def run_transfer_job():
    print("Running background transfer job...")
    # 1) Enqueue "sync everything that changed" for users with an archive-capable
    #    Google Drive connection (cheap: skips if a job is already queued/running).
    transfer_service.process_credentials()
    # 2) Drain the queue: claim + run queued jobs with bounded concurrency per job.
    #    APScheduler jobs run sync, so bridge into asyncio here.
    try:
        processed = asyncio.run(process_queued_jobs(limit=10))
        if processed:
            print(f"Processed {processed} personal Drive sync job(s).")
    except Exception as e:
        print(f"Error draining personal Drive sync queue: {e}")

def start_worker():
    # Run every 5 minutes (or 30 seconds for local dev if desired)
    scheduler.add_job(run_transfer_job, 'interval', minutes=5)
    scheduler.start()
    print("Transfer worker started.")

def stop_worker():
    scheduler.shutdown()
