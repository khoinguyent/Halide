from __future__ import annotations

import json
import logging
from datetime import datetime, timezone
from datetime import timedelta
from typing import Any, Optional
from urllib.parse import quote, unquote, urlparse

import httpx
from fastapi import APIRouter, Depends, Header, HTTPException, Query, Request
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
        "NON_RENEWING_PURCHASE",
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

# Stackable storage add-ons (consumable / non-consumable): count purchases in RevenueCat
# `subscriber.non_subscriptions[product_id]` (V1 API) and multiply by GB per SKU.
STORAGE_ADDON_PRODUCT_GB = {
    # Legacy (non-consumable / older App Store identifiers)
    "halide_storage_5gb": 5,
    "halide_storage_10gb": 10,
    "halide_storage_50gb": 50,
    # Current consumable IAP identifiers
    "halide_storage_5gb_ext": 5,
    "halide_storage_10gb_ext": 10,
    "halide_storage_50gb_ext": 50,
}

# Entitlements that grant storage quota but must not set subscription_tier to "pro".
STORAGE_ONLY_ENTITLEMENT_IDS = frozenset({"halide_cloud_system_storage"})

# RevenueCat V2 internal product ids → App Store SKU. Needed when the API secret cannot
# call GET /v2/.../products (missing project_configuration:products:read).
REVENUE_CAT_V2_STORAGE_PRODUCT_ID_TO_SKU: dict[str, str] = {
    "prod7334b44418": "halide_storage_5gb_ext",
    "prod6ce8f884b2": "halide_storage_5gb_ext",
    "prod1cab8213d3": "halide_storage_5gb_ext",
    "prod1973c922e5": "halide_storage_5gb_ext",
    "prod14bbf1c53f": "halide_storage_5gb_ext",
    "prod629aa4ce2f": "halide_storage_50gb_ext",
}


def revenuecat_v2_storage_product_id_map() -> dict[str, str]:
    """Static V2 id map plus optional `REVENUE_CAT_V2_STORAGE_PRODUCT_MAP` env overrides."""
    from ...core.config import settings

    merged = dict(REVENUE_CAT_V2_STORAGE_PRODUCT_ID_TO_SKU)
    raw = (getattr(settings, "REVENUE_CAT_V2_STORAGE_PRODUCT_MAP", None) or "").strip()
    for part in raw.split(","):
        part = part.strip()
        if ":" not in part:
            continue
        pid, sku = part.split(":", 1)
        pid, sku = pid.strip(), sku.strip()
        if pid and sku:
            merged[pid] = sku
    return merged


def _webhook_apple_transaction_id(event: dict) -> Optional[str]:
    """
    Stable per-purchase id for stackable IAP rows.

    RevenueCat usually sends `transaction_id`; some payloads also include
    `original_transaction_id` (often identical for consumables). Prefer
    `transaction_id` when present so repeat purchases of the same SKU remain
    distinct rows.
    """
    tx = event.get("transaction_id")
    if isinstance(tx, str) and tx.strip():
        return tx.strip()
    orig = event.get("original_transaction_id")
    if isinstance(orig, str) and orig.strip():
        return orig.strip()
    return None


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
    tier_ids = [eid for eid in active_ids if eid not in STORAGE_ONLY_ENTITLEMENT_IDS]
    is_premium = any(eid in known_pro_ids for eid in tier_ids)

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


def _purchase_count_in_non_subscriptions(non_sub: dict, product_id: str) -> int:
    if not non_sub or product_id not in non_sub:
        return 0
    val = non_sub[product_id]
    if isinstance(val, list):
        return len(val)
    if isinstance(val, dict):
        return 1
    return 0


def additional_storage_bytes_from_non_subscriptions(non_sub: dict) -> int:
    total = 0
    for pid, gb in STORAGE_ADDON_PRODUCT_GB.items():
        n = _purchase_count_in_non_subscriptions(non_sub, pid)
        total += n * gb * 1024 * 1024 * 1024
    return total


def additional_storage_bytes_from_purchase_history(db: Session, user_id: str) -> int:
    """
    Compute stackable storage from webhook-backed purchase history.

    This is our most reliable source for V2 projects when the RevenueCat API key
    can't resolve product ids to store identifiers.
    """
    # One logical purchase = (store product_id, Apple transaction id). Different
    # `transaction_id` values for the same SKU (stackable consumables) are all counted.
    purchased_keys: set[tuple[str, str]] = set()
    refunded_keys: set[tuple[str, str]] = set()

    rows = (
        db.query(
            PurchaseHistory.event_type,
            PurchaseHistory.product_id,
            PurchaseHistory.transaction_id,
            PurchaseHistory.rc_event_id,
        )
        .filter(PurchaseHistory.user_id == user_id)
        .filter(PurchaseHistory.product_id.in_(list(STORAGE_ADDON_PRODUCT_GB.keys())))
        .all()
    )

    for ev_type, product_id, tx_id, rc_id in rows:
        if not product_id:
            continue
        tid = (str(tx_id).strip() if tx_id else "") or (str(rc_id).strip() if rc_id else "")
        if not tid:
            continue
        key = (product_id, tid)
        et = (ev_type or "").upper()
        if et in ("REFUND", "REFUNDED", "REVOKE", "REVOKED", "CANCELLATION"):
            refunded_keys.add(key)
            continue
        if et in ("NON_RENEWING_PURCHASE", "INITIAL_PURCHASE"):
            purchased_keys.add(key)

    total = 0
    for product_id, tx_id in purchased_keys:
        if (product_id, tx_id) in refunded_keys:
            continue
        total += STORAGE_ADDON_PRODUCT_GB[product_id] * 1024 * 1024 * 1024
    return total


def backfill_purchase_history_from_v2_items(
    db: Session,
    user_id: str,
    items: list[dict],
    *,
    product_id_to_store_identifier: dict[str, str],
) -> None:
    """Insert missing purchase_history rows from V2 purchases (reconcile without webhooks)."""
    existing: set[tuple[str, str]] = set()
    for product_id, tx_id in (
        db.query(PurchaseHistory.product_id, PurchaseHistory.transaction_id)
        .filter(PurchaseHistory.user_id == user_id)
        .filter(PurchaseHistory.product_id.in_(list(STORAGE_ADDON_PRODUCT_GB.keys())))
        .all()
    ):
        if product_id and tx_id:
            existing.add((product_id, str(tx_id).strip()))

    for p in items:
        if not isinstance(p, dict) or p.get("object") != "purchase":
            continue
        status = (p.get("status") or "owned").lower()
        if status in ("refunded", "revoked"):
            continue
        sku = _v2_purchase_storage_sku(p)
        if not sku:
            raw_pid = p.get("product_id")
            if isinstance(raw_pid, str):
                mapped = product_id_to_store_identifier.get(raw_pid)
                if mapped in STORAGE_ADDON_PRODUCT_GB:
                    sku = mapped
        if not sku:
            continue
        tx = p.get("store_purchase_identifier")
        if not isinstance(tx, str) or not tx.strip():
            tx = p.get("id")
        if not isinstance(tx, str) or not tx.strip():
            continue
        tx = tx.strip()
        key = (sku, tx)
        if key in existing:
            continue
        rc_id = p.get("id")
        db.add(
            PurchaseHistory(
                user_id=user_id,
                event_type="NON_RENEWING_PURCHASE",
                product_id=sku,
                transaction_id=tx,
                original_transaction_id=None,
                rc_event_id=rc_id if isinstance(rc_id, str) else None,
                payload=json.dumps({"source": "v2_backfill", "purchase_id": rc_id}),
            )
        )
        existing.add(key)


def _v2_purchase_storage_sku(purchase: dict) -> Optional[str]:
    """Map a V2 purchase object to a STORAGE_ADDON_PRODUCT_GB key (App Store / store identifier)."""
    keys = STORAGE_ADDON_PRODUCT_GB.keys()
    pid = purchase.get("product_id")
    if isinstance(pid, str):
        mapped = revenuecat_v2_storage_product_id_map().get(pid)
        if mapped in keys:
            return mapped
    if isinstance(pid, str) and pid in keys:
        return pid
    prod = purchase.get("product")
    if isinstance(prod, dict):
        sid = prod.get("store_identifier")
        if isinstance(sid, str) and sid in keys:
            return sid
    ent_block = purchase.get("entitlements")
    if not isinstance(ent_block, dict):
        return None
    for ent in ent_block.get("items") or []:
        if not isinstance(ent, dict):
            continue
        prods = ent.get("products")
        if not isinstance(prods, dict):
            continue
        for pr in prods.get("items") or []:
            if not isinstance(pr, dict):
                continue
            sid = pr.get("store_identifier")
            if isinstance(sid, str) and sid in keys:
                return sid
    return None


def additional_storage_bytes_from_v2_purchase_items(
    items: list[dict], *, product_id_to_store_identifier: Optional[dict[str, str]] = None
) -> int:
    """Sum stackable storage from RevenueCat V2 GET .../customers/{id}/purchases items."""
    total = 0
    for p in items:
        if not isinstance(p, dict) or p.get("object") != "purchase":
            continue
        status = (p.get("status") or "owned").lower()
        if status in ("refunded", "revoked"):
            continue
        sku = _v2_purchase_storage_sku(p)
        if not sku and product_id_to_store_identifier:
            raw_pid = p.get("product_id")
            if isinstance(raw_pid, str):
                mapped = product_id_to_store_identifier.get(raw_pid)
                if mapped in STORAGE_ADDON_PRODUCT_GB:
                    sku = mapped
        if not sku:
            continue
        gb = STORAGE_ADDON_PRODUCT_GB[sku]
        try:
            qty = int(p.get("quantity") or 1)
        except (TypeError, ValueError):
            qty = 1
        if qty < 1:
            qty = 1
        total += qty * gb * 1024 * 1024 * 1024
    return total


async def fetch_revenuecat_v2_product_store_identifier(product_id: str) -> Optional[str]:
    """
    Resolve RevenueCat V2 product id (e.g. "prod...") to the store identifier
    (e.g. "halide_storage_50gb_ext") so we can map purchases to storage SKUs.
    """
    from ...core.config import settings

    if not isinstance(product_id, str) or not product_id:
        return None

    mapped = revenuecat_v2_storage_product_id_map().get(product_id)
    if mapped:
        return mapped

    if not settings.REVENUE_CAT_SECRET_KEY or not settings.REVENUE_CAT_PROJECT_ID:
        return None

    url = (
        f"https://api.revenuecat.com/v2/projects/{settings.REVENUE_CAT_PROJECT_ID}"
        f"/products/{quote(product_id, safe='')}"
    )
    headers = {
        "Authorization": f"Bearer {settings.REVENUE_CAT_SECRET_KEY}",
        "Content-Type": "application/json",
    }

    async with httpx.AsyncClient() as client:
        resp = await client.get(url, headers=headers)
        if resp.status_code != 200:
            logger.warning(
                "[Billing] RevenueCat V2 GET product %s failed: %s %s",
                product_id,
                resp.status_code,
                resp.text[:500],
            )
            return None
        body = resp.json()
        if not isinstance(body, dict):
            return None
        # Common shape: {"object":"product", ...} or {"product": {...}}
        prod = body.get("product") if isinstance(body.get("product"), dict) else body
        if not isinstance(prod, dict):
            return None
        sid = prod.get("store_identifier") or prod.get("lookup_key")
        return sid if isinstance(sid, str) else None


async def _fetch_revenuecat_v2_customer_purchase_items_for_env(
    app_user_id: str,
    *,
    environment: str,
) -> list[dict]:
    """Paginate GET .../purchases for one RevenueCat environment (sandbox | production)."""
    from ...core.config import settings

    if not settings.REVENUE_CAT_SECRET_KEY or not settings.REVENUE_CAT_PROJECT_ID:
        return []

    encoded_id = quote(app_user_id, safe="")
    base_path = (
        f"https://api.revenuecat.com/v2/projects/{settings.REVENUE_CAT_PROJECT_ID}"
        f"/customers/{encoded_id}/purchases"
    )
    headers = {
        "Authorization": f"Bearer {settings.REVENUE_CAT_SECRET_KEY}",
        "Content-Type": "application/json",
    }

    out: list[dict] = []
    next_url: Optional[str] = base_path
    next_params: Optional[dict[str, Any]] = {"limit": 100, "environment": environment}

    async with httpx.AsyncClient() as client:
        for _ in range(100):
            if not next_url:
                break
            response = await client.get(next_url, headers=headers, params=next_params)
            if response.status_code != 200:
                logger.warning(
                    "[Billing] RevenueCat V2 GET purchases %s env=%s failed: %s %s",
                    app_user_id,
                    environment,
                    response.status_code,
                    response.text[:500],
                )
                break
            body = response.json()
            if not isinstance(body, dict):
                break
            items = body.get("items") or []
            for it in items:
                if isinstance(it, dict):
                    out.append(it)
            np = body.get("next_page")
            if not np or not isinstance(np, str):
                break
            if np.startswith("http"):
                next_url = np
                next_params = None
            else:
                parsed = urlparse(np)
                next_url = f"https://api.revenuecat.com{parsed.path}"
                next_params = _parse_qs_to_dict(parsed.query) if parsed.query else None

    return out


async def fetch_revenuecat_v2_customer_purchase_items(
    app_user_id: str,
) -> list[dict]:
    """
    Paginate GET /v2/projects/{project_id}/customers/{customer_id}/purchases.

    When the server is configured for production (`IS_REVENUE_CAT_SANDBOX=false`), also
  queries sandbox so TestFlight consumable purchases reconcile on the prod API host.
    """
    from ...core.config import settings

    primary = "sandbox" if settings.IS_REVENUE_CAT_SANDBOX else "production"
    items = await _fetch_revenuecat_v2_customer_purchase_items_for_env(app_user_id, environment=primary)
    if not settings.IS_REVENUE_CAT_SANDBOX:
        sandbox_items = await _fetch_revenuecat_v2_customer_purchase_items_for_env(
            app_user_id, environment="sandbox"
        )
        seen: set[str] = set()
        merged: list[dict] = []
        for it in items + sandbox_items:
            pid = it.get("id") if isinstance(it.get("id"), str) else None
            if pid and pid in seen:
                continue
            if pid:
                seen.add(pid)
            merged.append(it)
        return merged
    return items


def _parse_qs_to_dict(qs: str) -> dict[str, str]:
    """Parse query string from RevenueCat `next_page` URLs into httpx params."""
    out: dict[str, str] = {}
    for part in qs.split("&"):
        if not part:
            continue
        if "=" in part:
            k, v = part.split("=", 1)
            out[unquote(k)] = unquote(v)
        else:
            out[unquote(part)] = ""
    return out


async def fetch_revenuecat_v1_subscriber_json(app_user_id: str) -> Optional[dict]:
    """V1 subscriber payload includes `non_subscriptions` (needed for consumable stack counts)."""
    from ...core.config import settings

    if not settings.REVENUE_CAT_SECRET_KEY:
        return None
    url = f"https://api.revenuecat.com/v1/subscribers/{app_user_id}"
    headers = {
        "Authorization": f"Bearer {settings.REVENUE_CAT_SECRET_KEY}",
        "Content-Type": "application/json",
    }
    async with httpx.AsyncClient() as client:
        response = await client.get(url, headers=headers)
        if response.status_code != 200:
            logger.warning(
                "[Billing] RevenueCat V1 GET subscriber %s failed: %s %s",
                app_user_id,
                response.status_code,
                response.text[:500],
            )
            return None
        return response.json()


async def fetch_revenuecat_customer_json(app_user_id: str) -> Optional[dict]:
    """GET subscriber/customer from RevenueCat (V2 project or V1). Returns None on failure."""
    from ...core.config import settings

    if not settings.REVENUE_CAT_SECRET_KEY:
        return None

    if settings.REVENUE_CAT_PROJECT_ID:
        cid = quote(app_user_id, safe="")
        url = f"https://api.revenuecat.com/v2/projects/{settings.REVENUE_CAT_PROJECT_ID}/customers/{cid}"
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


async def sync_user_from_revenuecat(db: Session, user: User) -> bool:
    """
    Fetch RevenueCat REST data and update subscription_tier plus stackable
    additional_storage_bytes.

    - **V2 project** (`REVENUE_CAT_PROJECT_ID`): stackable storage from
      `GET /v2/projects/.../customers/{id}/purchases` (same secret as other V2 calls).
      V1 `GET /v1/subscribers/{id}` is not used (modern secret keys are often V2-only).
    - **Legacy (no project id)**: storage from V1 `subscriber.non_subscriptions` only.
    """
    from ...core.config import settings

    data = await fetch_revenuecat_customer_json(user.id)
    if not data:
        return False
    active = parse_active_entitlements_from_customer_json(data)
    _update_user_tier(user, entitlements=active)

    non_sub: dict = {}
    sub = data.get("subscriber") if isinstance(data.get("subscriber"), dict) else None
    if isinstance(sub, dict):
        non_sub = dict(sub.get("non_subscriptions") or {})

    if settings.REVENUE_CAT_PROJECT_ID:
        v2_items = await fetch_revenuecat_v2_customer_purchase_items(user.id)
        # V2 purchases use RevenueCat product ids (e.g. "prod...") which must be resolved to
        # store identifiers (e.g. "halide_storage_50gb_ext") to map to our SKU list.
        product_id_to_store_identifier: dict[str, str] = {}
        for it in v2_items:
            if not isinstance(it, dict):
                continue
            raw_pid = it.get("product_id")
            if not isinstance(raw_pid, str) or not raw_pid:
                continue
            if raw_pid in product_id_to_store_identifier:
                continue
            if raw_pid in STORAGE_ADDON_PRODUCT_GB:
                product_id_to_store_identifier[raw_pid] = raw_pid
                continue
            static = revenuecat_v2_storage_product_id_map().get(raw_pid)
            if static:
                product_id_to_store_identifier[raw_pid] = static
                continue
            sid = await fetch_revenuecat_v2_product_store_identifier(raw_pid)
            if isinstance(sid, str) and sid:
                product_id_to_store_identifier[raw_pid] = sid

        backfill_purchase_history_from_v2_items(
            db,
            user.id,
            v2_items,
            product_id_to_store_identifier=product_id_to_store_identifier,
        )
        db.flush()

        v2_bytes = additional_storage_bytes_from_v2_purchase_items(
            v2_items, product_id_to_store_identifier=product_id_to_store_identifier
        )
        history_bytes = additional_storage_bytes_from_purchase_history(db, user.id)
        # V2 purchase pagination / mapping can lag behind webhooks (or miss consumables until
        # RC indexes them). Webhook-backed history is authoritative for stackable SKUs we log.
        # Take the max so a new purchase row increases quota even when v2_bytes is still stale
        # but non-zero (e.g. partial mapping from product id resolution).
        storage_bytes = max(v2_bytes, history_bytes)
        if storage_bytes == 0 and non_sub:
            storage_bytes = additional_storage_bytes_from_non_subscriptions(non_sub)
        user.additional_storage_bytes = storage_bytes
        matched_skus: set[str] = set()
        for it in v2_items:
            if isinstance(it, dict):
                s = _v2_purchase_storage_sku(it)
                if not s:
                    raw_pid = it.get("product_id")
                    if isinstance(raw_pid, str):
                        mapped = product_id_to_store_identifier.get(raw_pid)
                        if mapped in STORAGE_ADDON_PRODUCT_GB:
                            s = mapped
                if s:
                    matched_skus.add(s)
        logger.info(
            "[Billing] Storage sync user=%s additional_storage_bytes=%s "
            "(v2_purchase_items=%s v2_bytes=%s history_bytes=%s matched_skus=%s)",
            user.id,
            user.additional_storage_bytes,
            len(v2_items),
            v2_bytes,
            history_bytes,
            sorted(matched_skus),
        )
    else:
        v1_data = await fetch_revenuecat_v1_subscriber_json(user.id)
        if isinstance(v1_data, dict):
            v1_sub = v1_data.get("subscriber")
            if isinstance(v1_sub, dict):
                v1_non = v1_sub.get("non_subscriptions") or {}
                if v1_non:
                    non_sub = dict(v1_non)
        user.additional_storage_bytes = additional_storage_bytes_from_non_subscriptions(non_sub)
        logger.info(
            "[Billing] Storage sync user=%s additional_storage_bytes=%s (non_sub keys=%s)",
            user.id,
            user.additional_storage_bytes,
            list(non_sub.keys()) if non_sub else [],
        )

    db.add(user)
    return True


def apply_billing_from_webhook_event(db: Session, user: User, event: dict) -> None:
    """
    Apply subscription tier from the webhook event and stackable storage from
    `purchase_history` only (no RevenueCat REST calls).

    Storage-only `NON_RENEWING_PURCHASE` events often omit entitlement fields; in
    that case we only refresh add-on bytes so we do not overwrite `subscription_tier`
    with `free` by mistake.
    """
    product_id = event.get("product_id")
    event_type = (event.get("type") or "").upper()
    ents, eids = _normalized_entitlement_inputs(event)
    has_ent_signal = bool(ents) or bool(eids)

    storage_only_purchase = (
        event_type == "NON_RENEWING_PURCHASE"
        and isinstance(product_id, str)
        and product_id in STORAGE_ADDON_PRODUCT_GB
    )

    if has_ent_signal or not storage_only_purchase:
        _update_user_tier(user, entitlements=ents, entitlement_ids=eids)

    user.additional_storage_bytes = additional_storage_bytes_from_purchase_history(db, user.id)
    db.add(user)


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

    if not event_type:
        return {"status": "ignored", "reason": "missing_fields"}

    # TestFlight / Xcode StoreKit use SANDBOX IAP while the prod API may run with
    # IS_REVENUE_CAT_SANDBOX=false. Still record purchases and stackable storage;
    # only skip subscription tier updates when environments do not match.
    skip_tier_sync = False
    if event_type != "TEST" and is_sandbox is not None:
        if settings.IS_REVENUE_CAT_SANDBOX != is_sandbox:
            skip_tier_sync = True
            env_str = "SANDBOX" if is_sandbox else "PRODUCTION"
            server_env = "SANDBOX" if settings.IS_REVENUE_CAT_SANDBOX else "PRODUCTION"
            logger.info(
                "[Billing] Environment mismatch (%s event on %s server); "
                "will still log purchase_history and stackable storage SKUs",
                env_str,
                server_env,
            )

    # --- Purchase history (all events with a user id) — before tier/storage apply ---
    history_user_id = app_user_id or event.get("original_app_user_id")
    if not history_user_id and event_type == "TRANSFER":
        tt = event.get("transferred_to") or []
        if tt:
            history_user_id = tt[0]
    if history_user_id:
        try:
            tx_for_row = _webhook_apple_transaction_id(event)
            orig_tx = event.get("original_transaction_id")
            if isinstance(orig_tx, str):
                orig_tx = orig_tx.strip() or None
            else:
                orig_tx = None
            rc_ev = event.get("id")
            if isinstance(rc_ev, str):
                rc_ev = rc_ev.strip() or None
            else:
                rc_ev = None
            history = PurchaseHistory(
                user_id=history_user_id,
                event_type=event_type,
                product_id=event.get("product_id"),
                transaction_id=tx_for_row,
                original_transaction_id=orig_tx,
                rc_event_id=rc_ev,
                payload=json.dumps(payload),
            )
            db.add(history)
            # Ensure the row is visible to subsequent queries in this request (e.g. storage recompute).
            db.flush()
        except Exception as e:
            logger.warning("[Billing] Failed to log purchase history: %s", e)

    env_str = "SANDBOX" if is_sandbox else "PRODUCTION"
    resolved_tx = _webhook_apple_transaction_id(event)
    logger.info(
        "[Billing] [%s] Webhook type=%s app_user_id=%s product_id=%s transaction_id=%s original_transaction_id=%s rc_event_id=%s",
        env_str,
        event_type,
        app_user_id,
        event.get("product_id"),
        resolved_tx,
        event.get("original_transaction_id"),
        event.get("id"),
    )

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
            ok = await sync_user_from_revenuecat(db, u)
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

    # --- Subscription + consumable storage: tier from webhook; storage from DB history ---
    if event_type in WEBHOOK_TIER_SYNC_EVENT_TYPES:
        if skip_tier_sync:
            product_id = event.get("product_id")
            if isinstance(product_id, str) and product_id in STORAGE_ADDON_PRODUCT_GB:
                user.additional_storage_bytes = additional_storage_bytes_from_purchase_history(
                    db, user.id
                )
                db.add(user)
                db.commit()
                logger.info(
                    "[Billing] Storage add-on (env mismatch) user=%s product_id=%s "
                    "additional_storage_bytes=%s",
                    user.id,
                    product_id,
                    user.additional_storage_bytes or 0,
                )
                return {"status": "ok", "note": "storage_only_env_mismatch"}
            db.commit()
            return {"status": "ignored", "reason": "environment_mismatch"}
        apply_billing_from_webhook_event(db, user, event)
        _maybe_email_downgrade_notice(previous_tier=previous_tier, new_tier=user.subscription_tier, user=user)
        db.add(user)
        db.commit()
        product_id = event.get("product_id")
        if isinstance(product_id, str) and product_id in STORAGE_ADDON_PRODUCT_GB:
            logger.info(
                "[Billing] Storage add-on applied user=%s product_id=%s transaction_id=%s "
                "additional_storage_bytes=%s tier=%s",
                user.id,
                product_id,
                resolved_tx,
                user.additional_storage_bytes or 0,
                user.subscription_tier,
            )
        return {"status": "ok"}

    db.add(user)
    db.commit()
    return {"status": "ok"}


@router.post("/sync")
async def sync_billing_status(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    force_remote: bool = Query(
        False,
        description="If true, fetch subscriber state from RevenueCat and reconcile (heavy). "
        "Default false: recompute stackable storage from purchase_history only.",
    ),
):
    """
    Default: recompute `additional_storage_bytes` from `purchase_history` (no RC calls).
    Use `?force_remote=true` after a purchase/restore if you need an immediate full reconcile
    while webhooks catch up.
    """
    from ...core.config import settings

    if force_remote:
        if not settings.REVENUE_CAT_SECRET_KEY:
            raise HTTPException(status_code=501, detail="RevenueCat Secret Key not configured")
        if not await sync_user_from_revenuecat(db, current_user):
            raise HTTPException(status_code=502, detail="Failed to fetch from RevenueCat")
    else:
        current_user.additional_storage_bytes = additional_storage_bytes_from_purchase_history(
            db, current_user.id
        )
        db.add(current_user)

    db.commit()
    return {
        "status": "synced_remote" if force_remote else "synced_db",
        "tier": current_user.subscription_tier,
        "additional_storage_bytes": current_user.additional_storage_bytes or 0,
        "total_storage_limit": current_user.total_storage_limit,
    }
