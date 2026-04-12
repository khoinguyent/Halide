from __future__ import annotations

import json
import logging
from datetime import datetime, timezone
from typing import Optional
from datetime import timedelta

import httpx
from fastapi import APIRouter, Depends, Header, HTTPException, Request
from sqlalchemy.orm import Session

from ...core.dependencies import get_current_user
from ...db.models.user import User, PurchaseHistory
from ...db.session import get_db
from ...services.email_service import send_downgrade_warning

router = APIRouter()
logger = logging.getLogger(__name__)

# RevenueCat webhook events that carry entitlement info (or imply we should recompute tier).
# See: https://www.revenuecat.com/docs/integrations/webhooks/event-types-and-fields
WEBHOOK_TIER_SYNC_EVENT_TYPES = frozenset(
    {
        "INITIAL_PURCHASE",
        "RENEWAL",
        "PRODUCT_CHANGE",
        "EXPIRATION",
        "CANCELLATION",
        "UNCANCELLATION",
        "BILLING_ISSUE",
        "SUBSCRIPTION_EXTENDED",
        "SUBSCRIPTION_PAUSED",
        "TEMPORARY_ENTITLEMENT_GRANT",
        "REFUND_REVERSED",
    }
)


def _normalized_entitlement_inputs(event: dict) -> tuple[list, list]:
    """Normalize `entitlements` / `entitlement_ids` from a webhook `event` object."""
    raw_ents = event.get("entitlements")
    eids = event.get("entitlement_ids")
    if eids is None:
        eids = []
    if raw_ents is None:
        ents: list = []
    elif isinstance(raw_ents, dict):
        ents = [{"id": k, **(v if isinstance(v, dict) else {})} for k, v in raw_ents.items()]
    elif isinstance(raw_ents, list):
        ents = raw_ents
    else:
        ents = []
    return ents, eids


def _update_user_tier(user: User, entitlements: list | None = None, entitlement_ids: list | None = None) -> None:
    """Set user.subscription_tier from active entitlement IDs (webhook fields or sync API)."""
    from ...core.config import settings

    active_ids: list[str] = []
    if entitlement_ids:
        active_ids.extend([str(eid).lower().strip() for eid in entitlement_ids])
    if entitlements:
        active_ids.extend([str(e.get("id", "")).lower().strip() for e in entitlements if e.get("id")])

    known_pro_ids = [id.strip().lower() for id in settings.REVENUE_CAT_PRO_ENTITLEMENT_IDS.split(",")]
    is_premium = any(eid in known_pro_ids for eid in active_ids)

    user.subscription_tier = "pro" if is_premium else "free"
    logger.info(
        "[Billing] User %s tier -> %s (active entitlement ids: %s)",
        user.id,
        user.subscription_tier,
        active_ids,
    )


def _maybe_email_downgrade_notice(*, previous_tier: Optional[str], new_tier: Optional[str], user: User) -> None:
    """
    Send a retention email exactly when a user transitions from premium -> free.
    RevenueCat's CANCELLATION means "will not renew" but entitlement may still be active;
    so we only email when tier actually becomes free.
    """
    prev = (previous_tier or "").lower()
    new = (new_tier or "").lower()
    if prev in ("pro", "plus") and new == "free" and user.email:
        deletion_date = (datetime.now(timezone.utc) + timedelta(days=30)).strftime("%b %d, %Y")
        send_downgrade_warning(
            to=user.email,
            display_name=user.display_name or "there",
            deletion_date=deletion_date,
        )


def parse_active_entitlements_from_customer_json(data: dict) -> list[dict]:
    """Parse RevenueCat V1 or V2 customer REST response into list of active entitlement dicts with `id`."""
    from ...core.config import settings

    active_entitlements: list[dict] = []

    if settings.REVENUE_CAT_PROJECT_ID:
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
    else:
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
    return active_entitlements


async def fetch_revenuecat_customer_json(app_user_id: str) -> Optional[dict]:
    """GET subscriber/customer from RevenueCat (V2 project or V1). Returns None on failure."""
    from ...core.config import settings

    if not settings.REVENUE_CAT_SECRET_KEY:
        return None

    if settings.REVENUE_CAT_PROJECT_ID:
        url = f"https://api.revenuecat.com/v2/projects/{settings.REVENUE_CAT_PROJECT_ID}/customers/{app_user_id}"
    else:
        url = f"https://api.revenuecat.com/v1/subscribers/{app_user_id}"

    headers = {
        "Authorization": f"Bearer {settings.REVENUE_CAT_SECRET_KEY}",
        "Content-Type": "application/json",
    }

    async with httpx.AsyncClient() as client:
        response = await client.get(url, headers=headers)
        if response.status_code != 200:
            logger.warning(
                "[Billing] RevenueCat GET %s failed: %s %s",
                app_user_id,
                response.status_code,
                response.text[:500],
            )
            return None
        return response.json()


async def apply_tier_from_revenuecat_api(db: Session, user: User) -> bool:
    """Fetch current entitlements from RevenueCat REST API and update user tier. Returns True if applied."""
    data = await fetch_revenuecat_customer_json(user.id)
    if not data:
        return False
    active = parse_active_entitlements_from_customer_json(data)
    _update_user_tier(user, entitlements=active)
    db.add(user)
    return True


async def _resolve_user_for_webhook(db: Session, event: dict) -> Optional[User]:
    """Match app user id from RevenueCat (aliases / original id)."""
    app_user_id = event.get("app_user_id")
    if app_user_id:
        u = db.query(User).filter(User.id == app_user_id).first()
        if u:
            return u
    original = event.get("original_app_user_id")
    if original and original != app_user_id:
        u = db.query(User).filter(User.id == original).first()
        if u:
            return u
    for alias in event.get("aliases") or []:
        if not alias:
            continue
        u = db.query(User).filter(User.id == alias).first()
        if u:
            return u
    return None


def _collect_transfer_user_ids(event: dict) -> dict[str, str]:
    """Map RevenueCat user id -> source label for logging (TRANSFER)."""
    out: dict[str, str] = {}
    for uid in event.get("transferred_from") or []:
        if uid:
            out[str(uid)] = "from"
    for uid in event.get("transferred_to") or []:
        if uid:
            out[str(uid)] = "to"
    return out


def _webhook_auth_ok(authorization: Optional[str], secret: str) -> bool:
    """
    RevenueCat sends the dashboard \"authorization header\" value as the raw
    `Authorization` header (no automatic \"Bearer \" prefix). Accept either
    `Bearer <secret>` or `<secret>` so the dashboard matches typical env config.
    """
    if not authorization:
        return False
    auth = authorization.strip()
    bearer = f"Bearer {secret}"
    return auth == secret or auth == bearer


# TODO: Optionally verify RevenueCat's signed payload when they document it.
@router.post("/webhook")
async def revenue_cat_webhook(
    request: Request,
    authorization: str = Header(None),
    db: Session = Depends(get_db),
):
    """
    Handle RevenueCat server-to-server webhooks.
    Documentation: https://docs.revenuecat.com/docs/webhooks
    """
    from ...core.config import settings

    if settings.REVENUE_CAT_WEBHOOK_SECRET:
        if not _webhook_auth_ok(authorization, settings.REVENUE_CAT_WEBHOOK_SECRET):
            logger.warning("[Billing] Unauthorized webhook attempt")
            raise HTTPException(status_code=401, detail="Unauthorized")

    payload = await request.json()
    event = payload.get("event", {})
    event_type = event.get("type")
    app_user_id = event.get("app_user_id")

    is_sandbox_raw = event.get("is_sandbox")
    environment_raw = event.get("environment")
    is_sandbox: Optional[bool] = is_sandbox_raw
    if is_sandbox is None and environment_raw is not None:
        is_sandbox = environment_raw == "SANDBOX"

    # Dashboard \"Send test event\" uses type TEST and is often SANDBOX; always accept.
    if event_type != "TEST" and is_sandbox is not None:
        if settings.IS_REVENUE_CAT_SANDBOX != is_sandbox:
            env_str = "SANDBOX" if is_sandbox else "PRODUCTION"
            server_env = "SANDBOX" if settings.IS_REVENUE_CAT_SANDBOX else "PRODUCTION"
            logger.info(
                "[Billing] Dropping %s event on %s server (is_sandbox=%s environment=%s)",
                env_str,
                server_env,
                is_sandbox_raw,
                environment_raw,
            )
            return {"status": "ignored", "reason": "environment_mismatch"}

    if not event_type:
        return {"status": "ignored", "reason": "missing_fields"}

    # --- Purchase history (all events with a user id) ---
    history_user_id = app_user_id or event.get("original_app_user_id")
    if not history_user_id and event_type == "TRANSFER":
        tt = event.get("transferred_to") or []
        if tt:
            history_user_id = tt[0]
    if history_user_id:
        try:
            history = PurchaseHistory(
                user_id=history_user_id,
                event_type=event_type,
                product_id=event.get("product_id"),
                transaction_id=event.get("transaction_id"),
                payload=json.dumps(payload),
            )
            db.add(history)
        except Exception as e:
            logger.warning("[Billing] Failed to log purchase history: %s", e)

    env_str = "SANDBOX" if is_sandbox else "PRODUCTION"
    logger.info("[Billing] [%s] Webhook %s for app_user_id=%s", env_str, event_type, app_user_id)

    # --- TRANSFER: refresh tier for every affected user via API (authoritative) ---
    if event_type == "TRANSFER":
        if not settings.REVENUE_CAT_SECRET_KEY:
            logger.warning("[Billing] TRANSFER received but REVENUE_CAT_SECRET_KEY not set; cannot sync tiers")
            db.commit()
            return {"status": "ok", "note": "transfer_no_secret"}

        for uid, label in _collect_transfer_user_ids(event).items():
            u = db.query(User).filter(User.id == uid).first()
            if not u:
                logger.info("[Billing] TRANSFER skip unknown user id=%s (%s)", uid, label)
                continue
            ok = await apply_tier_from_revenuecat_api(db, u)
            logger.info("[Billing] TRANSFER sync user %s (%s) -> %s", uid, label, ok)

        db.commit()
        return {"status": "ok"}

    # --- TEST (dashboard) ---
    if event_type == "TEST":
        db.commit()
        return {"status": "ok"}

    user = await _resolve_user_for_webhook(db, event)
    if not user:
        logger.info("[Billing] Webhook unknown user app_user_id=%s", app_user_id)
        db.commit()
        return {"status": "user_not_found"}

    previous_tier = user.subscription_tier

    # --- Non-renewing purchase (storage add-on + optional tier) ---
    if event_type == "NON_RENEWING_PURCHASE":
        product_id = event.get("product_id")
        if product_id == "extra_storage_10gb":
            user.additional_storage_bytes = (user.additional_storage_bytes or 0) + (10 * 1024 * 1024 * 1024)
            logger.info("[Billing] Added 10GB to user %s", user.id)
        ents, eids = _normalized_entitlement_inputs(event)
        _update_user_tier(user, entitlements=ents, entitlement_ids=eids)
        _maybe_email_downgrade_notice(previous_tier=previous_tier, new_tier=user.subscription_tier, user=user)
        db.add(user)
        db.commit()
        return {"status": "ok"}

    # --- Subscription lifecycle: use webhook entitlements, then REST for ambiguous cases ---
    if event_type in WEBHOOK_TIER_SYNC_EVENT_TYPES:
        ents, eids = _normalized_entitlement_inputs(event)
        _update_user_tier(user, entitlements=ents, entitlement_ids=eids)

        # Refunds / cancellations sometimes omit entitlement_ids; use RevenueCat as source of truth.
        if event_type in frozenset(
            {
                "EXPIRATION",
                "CANCELLATION",
                "BILLING_ISSUE",
                "REFUND_REVERSED",
                "UNCANCELLATION",
                "PRODUCT_CHANGE",
            }
        ):
            if settings.REVENUE_CAT_SECRET_KEY:
                ok = await apply_tier_from_revenuecat_api(db, user)
                if ok:
                    logger.info("[Billing] Reconciled tier from RevenueCat API after %s for %s", event_type, user.id)
        _maybe_email_downgrade_notice(previous_tier=previous_tier, new_tier=user.subscription_tier, user=user)
        db.add(user)
        db.commit()
        return {"status": "ok"}

    db.add(user)
    db.commit()
    return {"status": "ok"}


@router.post("/sync")
async def sync_billing_status(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Manually sync user's entitlement status from RevenueCat REST API.
    """
    from ...core.config import settings

    if not settings.REVENUE_CAT_SECRET_KEY:
        raise HTTPException(status_code=501, detail="RevenueCat Secret Key not configured")

    if not await apply_tier_from_revenuecat_api(db, current_user):
        raise HTTPException(status_code=502, detail="Failed to fetch from RevenueCat")

    db.commit()
    return {"status": "synced", "tier": current_user.subscription_tier}
