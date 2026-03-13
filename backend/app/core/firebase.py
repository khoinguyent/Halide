import firebase_admin
from firebase_admin import credentials
from .config import settings

def init_firebase():
    if not firebase_admin._apps:
        if settings.FIREBASE_SERVICE_ACCOUNT_JSON:
            cred = credentials.Certificate(settings.FIREBASE_SERVICE_ACCOUNT_JSON)
            firebase_admin.initialize_app(cred)
        else:
            # Fallback for local dev if needed, or structured for production
            firebase_admin.initialize_app()
