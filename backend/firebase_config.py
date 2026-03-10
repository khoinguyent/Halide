import firebase_admin
from firebase_admin import credentials
from .config import settings
import os

def init_firebase():
    if not firebase_admin._apps:
        if settings.FIREBASE_SERVICE_ACCOUNT_JSON and os.path.exists(settings.FIREBASE_SERVICE_ACCOUNT_JSON):
            cred = credentials.Certificate(settings.FIREBASE_SERVICE_ACCOUNT_JSON)
            firebase_admin.initialize_app(cred, {
                'projectId': settings.FIREBASE_PROJECT_ID,
            })
        else:
            # Fallback to default credentials or just project ID if running in GCP/Firebase environment
            firebase_admin.initialize_app(options={
                'projectId': settings.FIREBASE_PROJECT_ID,
            })

# Note: In a real app, you might want to call this during startup
