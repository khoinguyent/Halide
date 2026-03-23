from fastapi import APIRouter, Depends, Header, HTTPException, Request
from sqlalchemy.orm import Session
from ...db.session import get_db
from ...db.models.user import User
from ...core.dependencies import get_current_user
import logging

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
            logger.warning(f"[Billing] Unauthorized webhook attempt: {authorization}")
            raise HTTPException(status_code=401, detail="Unauthorized")

    payload = await request.json()
    event = payload.get("event", {})
    event_type = event.get("type")
    app_user_id = event.get("app_user_id")
    is_sandbox = event.get("is_sandbox", False)

    # 2. Environment enforcement
    if settings.IS_REVENUE_CAT_SANDBOX != is_sandbox:
        env_str = "SANDBOX" if is_sandbox else "PRODUCTION"
        server_env = "SANDBOX" if settings.IS_REVENUE_CAT_SANDBOX else "PRODUCTION"
        logger.warning(f"[Billing] Dropping {env_str} event on {server_env} server")
        return {"status": "ignored", "reason": "environment_mismatch"}

    if not app_user_id or not event_type:
        return {"status": "ignored", "reason": "missing_fields"}

    user = db.query(User).filter(User.id == app_user_id).first()
    if not user:
        # If user is not found, we might want to log it but return 200 
        # to avoid RevenueCat retries for non-existent users.
        logger.warning(f"[Billing] Webhook received for unknown user: {app_user_id}")
        return {"status": "user_not_found"}

    env_str = "SANDBOX" if is_sandbox else "PRODUCTION"
    logger.info(f"[Billing] [{env_str}] Webhook event {event_type} for user {app_user_id}")

    # 2. Handle specific event types
    if event_type in ["INITIAL_PURCHASE", "RENEWAL", "PRODUCT_CHANGE"]:
        entitlements = event.get("entitlements", [])
        _update_user_tier(user, entitlements)
        
    elif event_type == "EXPIRATION":
        # Check if they have other active entitlements
        entitlements = event.get("entitlements", [])
        _update_user_tier(user, entitlements)

    elif event_type == "NON_RENEWING_PURCHASE":
        # This is where one-time purchases (like extra storage) land
        product_id = event.get("product_id")
        if product_id == "extra_storage_10gb":
            user.additional_storage_bytes = (user.additional_storage_bytes or 0) + (10 * 1024 * 1024 * 1024)
            logger.info(f"[Billing] Added 10GB to user {user.id}")

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

    url = f"https://api.revenuecat.com/v1/subscribers/{current_user.id}"
    headers = {
        "Authorization": f"Bearer {settings.REVENUE_CAT_SECRET_KEY}",
        "Content-Type": "application/json"
    }

    async with httpx.AsyncClient() as client:
        try:
            response = await client.get(url, headers=headers)
            if response.status_code != 200:
                logger.error(f"[Billing] RC Sync failed: {response.text}")
                raise HTTPException(status_code=502, detail="Failed to fetch from RevenueCat")
            
            data = response.json()
            subscriber = data.get("subscriber", {})
            entitlements_dict = subscriber.get("entitlements", {})
            
            # Map dictionary style entitlements to our processing logic
            active_entitlements = []
            for eid, detail in entitlements_dict.items():
                # RC says an entitlement is active if it has no expires_date or the date is in the future
                active_entitlements.append({"id": eid})
            
            _update_user_tier(current_user, active_entitlements)
            
            # Handle non-subscriptions (consumables) like extra storage if present in non_subscriptions
            non_subscriptions = subscriber.get("non_subscriptions", {})
            # This logic is trickier because we need to avoid double-counting.
            # Usually, you'd only increment if the purchase ID is new.
            # For now, we rely on the Webhook for consumables for atomic increments.
            
            db.add(current_user)
            db.commit()
            return {"status": "synced", "tier": current_user.subscription_tier}
            
        except Exception as e:
            logger.error(f"[Billing] Sync Error: {str(e)}")
            raise HTTPException(status_code=500, detail="Internal Sync Error")

def _update_user_tier(user: User, entitlements: list):
    """Update user.subscription_tier based on active entitlements."""
    # Hierarchy: pro > plus > free
    is_pro = any(e["id"] == "pro" for e in entitlements)
    is_plus = any(e["id"] == "plus" for e in entitlements)

    if is_pro:
        user.subscription_tier = "pro"
    elif is_plus:
        user.subscription_tier = "plus"
    else:
        user.subscription_tier = "free"
    
    logger.info(f"[Billing] User {user.id} tier updated to {user.subscription_tier}")
