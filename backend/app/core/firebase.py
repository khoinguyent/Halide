import logging
import firebase_admin
from firebase_admin import credentials
from .config import settings

logger = logging.getLogger(__name__)

def init_firebase():
    if not firebase_admin._apps:
        if settings.FIREBASE_SERVICE_ACCOUNT_JSON:
            cred = credentials.Certificate(settings.FIREBASE_SERVICE_ACCOUNT_JSON)
            firebase_admin.initialize_app(cred)
        else:
            # Local dev: need project_id so verify_id_token can fetch public keys
            firebase_admin.initialize_app(options={"projectId": settings.FIREBASE_PROJECT_ID})
