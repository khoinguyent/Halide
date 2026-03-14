from apscheduler.schedulers.background import BackgroundScheduler
from ..services.transfer_service import transfer_service

scheduler = BackgroundScheduler()

def run_transfer_job():
    print("Running background transfer job...")
    transfer_service.process_credentials()

def start_worker():
    # Run every 5 minutes (or 30 seconds for local dev if desired)
    scheduler.add_job(run_transfer_job, 'interval', minutes=5)
    scheduler.start()
    print("Transfer worker started.")

def stop_worker():
    scheduler.shutdown()
