from __future__ import annotations

import logging
import time
from typing import Optional

from sqlalchemy import event, text
from sqlalchemy.engine import Engine
from sqlalchemy.orm import Session, object_session

from ..db.models.image import Image
from ..db.session import engine

logger = logging.getLogger(__name__)

MV_NAME = "mv_user_shooting_shots"
_REFRESH_DEBOUNCE_SEC = 30.0
_last_refresh_monotonic = 0.0
_listeners_registered = False


def mark_shooting_mv_stale(session: Session) -> None:
    session.info["refresh_shooting_mv"] = True


def shooting_mv_exists(db: Session) -> bool:
    row = db.execute(
        text("SELECT 1 FROM pg_matviews WHERE matviewname = :name"),
        {"name": MV_NAME},
    ).first()
    return row is not None


def refresh_shooting_mv(force: bool = False) -> None:
    """Refresh the shooting analytics materialized view (debounced unless forced)."""
    global _last_refresh_monotonic

    now = time.monotonic()
    if not force and (now - _last_refresh_monotonic) < _REFRESH_DEBOUNCE_SEC:
        return

    try:
        with engine.connect().execution_options(isolation_level="AUTOCOMMIT") as conn:
            exists = conn.execute(
                text("SELECT 1 FROM pg_matviews WHERE matviewname = :name"),
                {"name": MV_NAME},
            ).first()
            if not exists:
                logger.warning("Skipping MV refresh — %s does not exist (run migrations)", MV_NAME)
                return
            conn.execute(text(f"REFRESH MATERIALIZED VIEW CONCURRENTLY {MV_NAME}"))
        _last_refresh_monotonic = now
        logger.debug("Refreshed materialized view %s", MV_NAME)
    except Exception:
        logger.exception("Failed to refresh materialized view %s", MV_NAME)


def _on_after_commit(session: Session) -> None:
    if session.info.pop("refresh_shooting_mv", False):
        refresh_shooting_mv(force=True)


def register_shooting_mv_listeners(bind_engine: Engine) -> None:
    global _listeners_registered
    if _listeners_registered:
        return

    @event.listens_for(Image, "after_insert")
    def _image_after_insert(mapper, connection, target) -> None:
        sess = object_session(target)
        if sess is not None:
            mark_shooting_mv_stale(sess)

    @event.listens_for(Image, "after_delete")
    def _image_after_delete(mapper, connection, target) -> None:
        sess = object_session(target)
        if sess is not None:
            mark_shooting_mv_stale(sess)

    @event.listens_for(Session, "after_commit")
    def _session_after_commit(session: Session) -> None:
        _on_after_commit(session)

    _listeners_registered = True
    logger.info("Registered shooting analytics MV refresh listeners")
