from __future__ import annotations

import logging
from datetime import date, datetime, timedelta
from typing import Dict, List, Optional, Tuple
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from fastapi import HTTPException
from sqlalchemy import text
from sqlalchemy.orm import Session

from ..db.models.user import User
from ..db.schemas.analytics import (
    DailyCount,
    LightingInsight,
    RankedItem,
    ShootingMatrixResponse,
    ShootingMatrixTotals,
    StreakAnalytics,
    TopEmulsion,
    TopHardware,
)
from .analytics_mv_service import MV_NAME, shooting_mv_exists

logger = logging.getLogger(__name__)

MATRIX_DAYS = 365
BREAKDOWN_LIMIT = 10

_LIVE_SHOT_FILTER = """
    FROM images i
    INNER JOIN rolls r ON r.id = i.roll_id
    WHERE r.user_id = :user_id
      AND i.created_at >= :since
"""

_LIVE_EMULSION_FROM = """
    FROM images i
    INNER JOIN rolls r ON r.id = i.roll_id
    INNER JOIN film_stocks fs ON fs.id = r.film_stock_id
    WHERE r.user_id = :user_id
      AND i.created_at >= :since
"""

_LIVE_HARDWARE_FROM = """
    FROM images i
    INNER JOIN rolls r ON r.id = i.roll_id
    INNER JOIN user_lenses ul ON ul.id = r.user_lens_id
    INNER JOIN lenses l ON l.id = ul.lens_id
    WHERE r.user_id = :user_id
      AND i.created_at >= :since
      AND r.user_lens_id IS NOT NULL
"""


def _validate_timezone(tz_name: str) -> str:
    try:
        ZoneInfo(tz_name)
    except ZoneInfoNotFoundError as exc:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid timezone '{tz_name}'. Use an IANA name such as 'America/New_York'.",
        ) from exc
    return tz_name


def resolve_timezone(
    user: User,
    device_timezone: Optional[str] = None,
) -> str:
    candidate = device_timezone or user.timezone or "UTC"
    return _validate_timezone(candidate)


def persist_user_timezone(
    db: Session,
    user: User,
    timezone_name: str,
) -> str:
    tz = _validate_timezone(timezone_name)
    if user.timezone != tz:
        user.timezone = tz
        db.commit()
        db.refresh(user)
    return tz


def _period_bounds(period_days: int = MATRIX_DAYS) -> Tuple[date, date, datetime]:
    end = date.today()
    start = end - timedelta(days=period_days - 1)
    since = datetime.combine(start, datetime.min.time())
    return start, end, since


def _fill_matrix(count_by_date: Dict[date, int], start: date, end: date) -> List[DailyCount]:
    rows: List[DailyCount] = []
    current = start
    while current <= end:
        rows.append(DailyCount(date=current.isoformat(), count=count_by_date.get(current, 0)))
        current += timedelta(days=1)
    return rows


def _compute_streaks(matrix: List[DailyCount]) -> StreakAnalytics:
    current_streak = 0
    for day in reversed(matrix):
        if day.count > 0:
            current_streak += 1
        else:
            break

    longest_streak = 0
    run = 0
    for day in matrix:
        if day.count > 0:
            run += 1
            longest_streak = max(longest_streak, run)
        else:
            run = 0

    return StreakAnalytics(current_streak=current_streak, longest_streak=longest_streak)


def _film_label(brand: str, name: str) -> str:
    return f"{brand} {name}".strip()


def _lens_label(brand: Optional[str], model: Optional[str], nickname: Optional[str]) -> str:
    if nickname and nickname.strip():
        return nickname.strip()
    return f"{brand or ''} {model or ''}".strip()


def _percentage(count: int, total: int) -> float:
    if total <= 0:
        return 0.0
    return round((count / total) * 100, 1)


def _empty_response(tz: str, period_days: int = MATRIX_DAYS) -> ShootingMatrixResponse:
    start, end, _ = _period_bounds(period_days)
    matrix = _fill_matrix({}, start, end)
    return ShootingMatrixResponse(
        matrix=matrix,
        streaks=StreakAnalytics(current_streak=0, longest_streak=0),
        top_emulsion=None,
        top_hardware=None,
        emulsion_breakdown=[],
        hardware_breakdown=[],
        lighting_insight=LightingInsight(
            golden_hour_percentage=0.0,
            golden_hour_shots=0,
            total_shots=0,
        ),
        totals=ShootingMatrixTotals(total_shots=0, active_days=0, period_days=period_days),
        timezone=tz,
    )


def _daily_counts(
    db: Session,
    user_id: str,
    since: datetime,
    timezone_name: str,
    *,
    use_mv: bool,
) -> Dict[date, int]:
    if use_mv:
        sql = f"""
            SELECT (timezone(:tz, timezone('UTC', shot_at)))::date AS day,
                   COUNT(*) AS cnt
            FROM {MV_NAME}
            WHERE user_id = :user_id
              AND shot_at >= :since
            GROUP BY day
        """
    else:
        sql = f"""
            SELECT (timezone(:tz, timezone('UTC', i.created_at)))::date AS day,
                   COUNT(*) AS cnt
            {_LIVE_SHOT_FILTER}
            GROUP BY day
        """

    rows = db.execute(
        text(sql),
        {"user_id": user_id, "since": since, "tz": timezone_name},
    ).all()
    return {row.day: int(row.cnt) for row in rows}


def _emulsion_breakdown(
    db: Session,
    user_id: str,
    since: datetime,
    total_shots: int,
    *,
    use_mv: bool,
) -> Tuple[Optional[TopEmulsion], List[RankedItem]]:
    if use_mv:
        sql = f"""
            SELECT film_brand, film_name, COUNT(*) AS cnt
            FROM {MV_NAME}
            WHERE user_id = :user_id
              AND shot_at >= :since
            GROUP BY film_stock_id, film_brand, film_name
            ORDER BY cnt DESC
            LIMIT :limit
        """
    else:
        sql = f"""
            SELECT fs.brand AS film_brand, fs.name AS film_name, COUNT(*) AS cnt
            {_LIVE_EMULSION_FROM}
            GROUP BY fs.id, fs.brand, fs.name
            ORDER BY cnt DESC
            LIMIT :limit
        """

    rows = db.execute(
        text(sql),
        {"user_id": user_id, "since": since, "limit": BREAKDOWN_LIMIT},
    ).all()
    if not rows:
        return None, []

    breakdown = [
        RankedItem(
            name=_film_label(row.film_brand, row.film_name),
            count=int(row.cnt),
            percentage=_percentage(int(row.cnt), total_shots),
        )
        for row in rows
    ]
    top = rows[0]
    top_emulsion = TopEmulsion(
        name=_film_label(top.film_brand, top.film_name),
        brand=top.film_brand,
        count=int(top.cnt),
        percentage=_percentage(int(top.cnt), total_shots),
    )
    return top_emulsion, breakdown


def _hardware_breakdown(
    db: Session,
    user_id: str,
    since: datetime,
    total_shots: int,
    *,
    use_mv: bool,
) -> Tuple[Optional[TopHardware], List[RankedItem]]:
    if use_mv:
        sql = f"""
            SELECT lens_brand, lens_model, lens_nickname, COUNT(*) AS cnt
            FROM {MV_NAME}
            WHERE user_id = :user_id
              AND shot_at >= :since
              AND user_lens_id IS NOT NULL
            GROUP BY user_lens_id, lens_brand, lens_model, lens_nickname
            ORDER BY cnt DESC
            LIMIT :limit
        """
    else:
        sql = f"""
            SELECT l.brand AS lens_brand, l.model AS lens_model,
                   ul.gear_nickname AS lens_nickname, COUNT(*) AS cnt
            {_LIVE_HARDWARE_FROM}
            GROUP BY ul.id, l.brand, l.model, ul.gear_nickname
            ORDER BY cnt DESC
            LIMIT :limit
        """

    rows = db.execute(
        text(sql),
        {"user_id": user_id, "since": since, "limit": BREAKDOWN_LIMIT},
    ).all()
    if not rows:
        return None, []

    lens_total = sum(int(row.cnt) for row in rows)
    breakdown = [
        RankedItem(
            name=_lens_label(row.lens_brand, row.lens_model, row.lens_nickname),
            count=int(row.cnt),
            percentage=_percentage(int(row.cnt), lens_total),
        )
        for row in rows
    ]
    top = rows[0]
    top_hardware = TopHardware(
        name=_lens_label(top.lens_brand, top.lens_model, top.lens_nickname),
        count=int(top.cnt),
        percentage=_percentage(int(top.cnt), lens_total),
    )
    return top_hardware, breakdown


def _lighting_insight(
    db: Session,
    user_id: str,
    since: datetime,
    timezone_name: str,
    *,
    use_mv: bool,
) -> LightingInsight:
    if use_mv:
        source = f"""
            FROM {MV_NAME}
            WHERE user_id = :user_id
              AND shot_at >= :since
        """
        ts_expr = "shot_at"
    else:
        source = _LIVE_SHOT_FILTER
        ts_expr = "i.created_at"

    row = db.execute(
        text(
            f"""
            SELECT
                COUNT(*) AS total,
                COUNT(*) FILTER (
                    WHERE EXTRACT(
                        HOUR FROM timezone(:tz, timezone('UTC', {ts_expr}))
                    ) >= 16
                      AND EXTRACT(
                        HOUR FROM timezone(:tz, timezone('UTC', {ts_expr}))
                    ) < 18
                ) AS golden
            {source}
            """
        ),
        {"user_id": user_id, "since": since, "tz": timezone_name},
    ).one()

    total = int(row.total or 0)
    golden = int(row.golden or 0)
    return LightingInsight(
        golden_hour_percentage=_percentage(golden, total),
        golden_hour_shots=golden,
        total_shots=total,
    )


def get_shooting_matrix(
    db: Session,
    user: User,
    device_timezone: Optional[str] = None,
    period_days: int = MATRIX_DAYS,
    sync_timezone: bool = False,
    *,
    force_live: bool = False,
) -> ShootingMatrixResponse:
    if sync_timezone and device_timezone:
        tz = persist_user_timezone(db, user, device_timezone)
    else:
        tz = resolve_timezone(user, device_timezone)

    use_mv = shooting_mv_exists(db) and not force_live
    if force_live:
        logger.info("Shooting analytics using live queries for user %s (forced)", user.id)
    elif not use_mv:
        logger.info(
            "Shooting analytics using live queries for user %s (MV %s not found)",
            user.id,
            MV_NAME,
        )

    start, end, since = _period_bounds(period_days)

    try:
        count_by_date = _daily_counts(db, user.id, since, tz, use_mv=use_mv)
        matrix = _fill_matrix(count_by_date, start, end)
        streaks = _compute_streaks(matrix)

        total_shots = sum(day.count for day in matrix)
        active_days = sum(1 for day in matrix if day.count > 0)

        if total_shots == 0:
            return _empty_response(tz, period_days)

        top_emulsion, emulsion_breakdown = _emulsion_breakdown(
            db, user.id, since, total_shots, use_mv=use_mv
        )
        top_hardware, hardware_breakdown = _hardware_breakdown(
            db, user.id, since, total_shots, use_mv=use_mv
        )
        lighting = _lighting_insight(db, user.id, since, tz, use_mv=use_mv)

        return ShootingMatrixResponse(
            matrix=matrix,
            streaks=streaks,
            top_emulsion=top_emulsion,
            top_hardware=top_hardware,
            emulsion_breakdown=emulsion_breakdown,
            hardware_breakdown=hardware_breakdown,
            lighting_insight=lighting,
            totals=ShootingMatrixTotals(
                total_shots=total_shots,
                active_days=active_days,
                period_days=period_days,
            ),
            timezone=tz,
        )
    except Exception as exc:
        if use_mv:
            logger.warning(
                "MV analytics query failed for user %s, falling back to live queries: %s",
                user.id,
                exc,
            )
            return get_shooting_matrix(
                db,
                user,
                device_timezone=device_timezone,
                period_days=period_days,
                sync_timezone=False,
                force_live=True,
            )
        logger.exception("Shooting analytics failed for user %s", user.id)
        raise HTTPException(
            status_code=500,
            detail="Could not load shooting analytics. Please try again later.",
        ) from exc
