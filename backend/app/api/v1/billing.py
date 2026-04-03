from fastapi import APIRouter, Depends, Header, HTTPException, Request
from sqlalchemy.orm import Session
from ...db.session import get_db
from ...db.models.user import User, PurchaseHistory
from ...core.dependencies import get_current_user
import logging
import json

router = APIRouter()
logger = logging.getLogger(__name__)

# TODO: Secure this with REVENUE_CAT_WEBHOOK_SECRET token verification
@router.post("/webhook")
async def revenue_cat_webhook(
    request: Request,
    authorization: str = Header(None),
    db: Session = Depends(get_db)
):
    """
    Handle RevenueCat server-to-server webhooks.
    Documentation: https://docs.revenuecat.com/docs/webhooks
    """
    from ...core.config import settings
    # 1. Authorization verification
    if settings.REVENUE_CAT_WEBHOOK_SECRET:
        if authorization != f"Bearer {settings.REVENUE_CAT_WEBHOOK_SECRET}":
            print(f"[Billing] Unauthorized webhook attempt: {authorization}")
            raise HTTPException(status_code=401, detail="Unauthorized")

    payload = await request.json()
    event = payload.get("event", {})
    event_type = event.get("type")
    app_user_id = event.get("app_user_id")
    
    # RevenueCat uses 'environment' field, but some SDK versions might use 'is_sandbox'
    is_sandbox_raw = event.get("is_sandbox")
    environment_raw = event.get("environment")
    
    is_sandbox = is_sandbox_raw
    if is_sandbox is None:
        is_sandbox = environment_raw == "SANDBOX"

    # 2. Environment enforcement
    if settings.IS_REVENUE_CAT_SANDBOX != is_sandbox:
        env_str = "SANDBOX" if is_sandbox else "PRODUCTION"
        server_env = "SANDBOX" if settings.IS_REVENUE_CAT_SANDBOX else "PRODUCTION"
        print(f"[Billing] Dropping {env_str} event on {server_env} server. raw_is_sandbox={is_sandbox_raw}, environment={environment_raw}")
        return {"status": "ignored", "reason": "environment_mismatch"}

    if not app_user_id or not event_type:
        return {"status": "ignored", "reason": "missing_fields"}

    user = db.query(User).filter(User.id == app_user_id).first()
    if not user:
        print(f"[Billing] Webhook received for unknown user: {app_user_id}")
        return {"status": "user_not_found"}

    # Track Purchase History
    try:
        history = PurchaseHistory(
            user_id=app_user_id,
            event_type=event_type,
            product_id=event.get("product_id"),
            transaction_id=event.get("transaction_id"),
            payload=json.dumps(payload)
        )
        db.add(history)
    except Exception as e:
        print(f"[Billing] Failed to log purchase history: {e}")

    env_str = "SANDBOX" if is_sandbox else "PRODUCTION"
    print(f"[Billing] [{env_str}] Webhook event {event_type} for user {app_user_id}")

    # 2. Handle specific event types
    if event_type in ["INITIAL_PURCHASE", "RENEWAL", "PRODUCT_CHANGE", "EXPIRATION"]:
        # Capture either list of objects or list of IDs for robustness
        entitlements = event.get("entitlements", [])
        entitlement_ids = event.get("entitlement_ids", [])
        _update_user_tier(user, entitlements, entitlement_ids)

    elif event_type == "NON_RENEWING_PURCHASE":
        product_id = event.get("product_id")
        if product_id == "extra_storage_10gb":
            user.additional_storage_bytes = (user.additional_storage_bytes or 0) + (10 * 1024 * 1024 * 1024)
            print(f"[Billing] Added 10GB to user {user.id}")

    db.add(user)
    db.commit()
    return {"status": "ok"}

@router.post("/sync")
async def sync_billing_status(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Manually sync user's entitlement status from RevenueCat REST API.
    """
    from ...core.config import settings
    import httpx

    if not settings.REVENUE_CAT_SECRET_KEY:
        raise HTTPException(status_code=501, detail="RevenueCat Secret Key not configured")

    if settings.REVENUE_CAT_PROJECT_ID:
        # V2: https://api.revenuecat.com/v2/projects/{project_id}/customers/{app_user_id}
        url = f"https://api.revenuecat.com/v2/projects/{settings.REVENUE_CAT_PROJECT_ID}/customers/{current_user.id}"
    else:
        # V1: https://api.revenuecat.com/v1/subscribers/{current_user.id}
        url = f"https://api.revenuecat.com/v1/subscribers/{current_user.id}"

    headers = {
        "Authorization": f"Bearer {settings.REVENUE_CAT_SECRET_KEY}",
        "Content-Type": "application/json"
    }

    async with httpx.AsyncClient() as client:
        try:
            print(f"[Billing] Syncing for {current_user.id} via {url}")
            response = await client.get(url, headers=headers)
            if response.status_code != 200:
                print(f"[Billing] RC Sync failed ({response.status_code}): {response.text}")
                raise HTTPException(status_code=502, detail=f"Failed to fetch from RevenueCat ({response.status_code})")
            
            data = response.json()
            active_entitlements = []
            from datetime import datetime, timezone

            if settings.REVENUE_CAT_PROJECT_ID:
                # Parse V2 Response
                active_ent_data = data.get("active_entitlements", {})
                entitlements_items = active_ent_data.get("items", [])
                for item in entitlements_items:
                    eid = item.get("lookup_key") or item.get("entitlement_id")
                    expires_at_ms = item.get("expires_at")
                    if expires_at_ms is None:
                        active_entitlements.append({"id": eid})
                    else:
                        if (expires_at_ms / 1000) > datetime.now(timezone.utc).timestamp():
                            active_entitlements.append({"id": eid})
                print(f"[Billing] V2 Sync for {current_user.id}: {[e['id'] for e in active_entitlements]}")
            else:
                # Parse V1 Response
                subscriber = data.get("subscriber", {})
                entitlements_dict = subscriber.get("entitlements", {})
                for eid, detail in entitlements_dict.items():
                    expires_date = detail.get("expires_date")
                    if expires_date is None:
                        active_entitlements.append({"id": eid})
                    else:
                        try:
                            expiry = datetime.fromisoformat(expires_date.replace("Z", "+00:00"))
                            if expiry > datetime.now(timezone.utc):
                                active_entitlements.append({"id": eid})
                        except (ValueError, TypeError):
                            active_entitlements.append({"id": eid})
                print(f"[Billing] V1 Sync for {current_user.id}: {[e['id'] for e in active_entitlements]}")
            
            _update_user_tier(current_user, active_entitlements)
            db.add(current_user)
            db.commit()
            return {"status": "synced", "tier": current_user.subscription_tier}
            
        except HTTPException:
            raise
        except Exception as e:
            print(f"[Billing] Sync Error: {str(e)}")
            raise HTTPException(status_code=500, detail="Internal Sync Error")

def _update_user_tier(user: User, entitlements: list = None, entitlement_ids: list = None):
    """Update user.subscription_tier based on active entitlements."""
    from ...core.config import settings
    # Collect all IDs from both sources
    active_ids = []
    if entitlement_ids:
        active_ids.extend([str(eid).lower().strip() for eid in entitlement_ids])
    if entitlements:
        active_ids.extend([str(e.get("id", "")).lower().strip() for e in entitlements])

    # Mapping known identifiers from settings
    known_pro_ids = [id.strip().lower() for id in settings.REVENUE_CAT_PRO_ENTITLEMENT_IDS.split(",")]
    is_premium = any(eid in known_pro_ids for eid in active_ids)

    if is_premium:
        user.subscription_tier = "pro"
    else:
        user.subscription_tier = "free"
    
    print(f"[Billing] User {user.id} tier updated to {user.subscription_tier} (Active IDs: {active_ids})")
