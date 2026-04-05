#!/usr/bin/env python3
"""
Truncate all user-owned rows on a Postgres database (typical: staging).

Preserves master catalog data: film_stocks, cameras, lenses.

Does NOT delete objects in R2/S3 — only database rows.

Usage (staging server or tunnel):
  export DATABASE_URL='postgresql://user:pass@host:5432/halide_staging'
  python scripts/clear_staging_user_data.py --yes

Or load DATABASE_URL from a file:
  python scripts/clear_staging_user_data.py --env-file .env.staging --yes

On the staging host, `DATABASE_URL` usually uses hostname `db` (Compose network). Either:

- Copy `.env.staging` into the image or mount it, then run inside `backend-staging`, or
- Pass the URL explicitly:

  docker compose -f docker-compose.prod.yml exec -T -e DATABASE_URL='postgresql://...' \\
    backend-staging python scripts/clear_staging_user_data.py --yes

Plain SQL (from `db` container; replace DB name if different):

  psql -U halide_user -d halide_staging -c \\
    "TRUNCATE TABLE images, rolls, storage_credentials, purchase_history, user_lenses, user_cameras, users RESTART IDENTITY CASCADE;"
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

# backend/ on sys.path for app imports if needed later
_BACKEND = Path(__file__).resolve().parent.parent
if str(_BACKEND) not in sys.path:
    sys.path.insert(0, str(_BACKEND))


def _load_database_url_from_env_file(path: Path) -> str:
    for raw in path.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("DATABASE_URL="):
            v = line.split("=", 1)[1].strip().strip('"').strip("'")
            return v
    raise SystemExit(f"No DATABASE_URL= line in {path}")


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument(
        "--env-file",
        type=Path,
        help="Path to .env-style file containing DATABASE_URL=...",
    )
    p.add_argument(
        "--yes",
        action="store_true",
        help="Required: confirm destructive truncate.",
    )
    args = p.parse_args()

    if not args.yes:
        p.error("Refusing to run without --yes (this deletes all user data).")

    url = os.environ.get("DATABASE_URL")
    if args.env_file:
        url = _load_database_url_from_env_file(args.env_file)
    if not url:
        p.error("Set DATABASE_URL or pass --env-file with DATABASE_URL.")

    from sqlalchemy import create_engine, text

    engine = create_engine(url)
    sql = text(
        """
        TRUNCATE TABLE
            images,
            rolls,
            storage_credentials,
            purchase_history,
            user_lenses,
            user_cameras,
            users
        RESTART IDENTITY CASCADE;
        """
    )
    with engine.begin() as conn:
        conn.execute(sql)
    print("OK: truncated user tables (catalog film_stocks / cameras / lenses unchanged).")


if __name__ == "__main__":
    main()
