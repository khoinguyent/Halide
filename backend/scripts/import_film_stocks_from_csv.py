"""
Replace all rows in `film_stocks` with data from docs/film_stock.csv.

Clears foreign-key references from `rolls.film_stock_id` first, then deletes
existing film stocks, then inserts CSV rows.

Usage (from repo root or backend/):
  cd backend && python scripts/import_film_stocks_from_csv.py
"""
from __future__ import annotations

import argparse
import csv
import sys
from pathlib import Path

BACKEND_ROOT = Path(__file__).resolve().parent.parent
REPO_ROOT = BACKEND_ROOT.parent
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

from sqlalchemy import text

from app.db.models.film_stock import FilmStock, FormatEnum, ColorTypeEnum
from app.db.session import SessionLocal

DEFAULT_CSV = BACKEND_ROOT / "app" / "db" / "data" / "film_stock.csv"

FORMAT_MAP = {
    "format_135": FormatEnum.format_135,
    "format_120": FormatEnum.format_120,
    "format_large": FormatEnum.format_large,
}
COLOR_MAP = {
    "color_negative": ColorTypeEnum.color_negative,
    "slide": ColorTypeEnum.slide,
    "b_w": ColorTypeEnum.b_w,
}


def _normalize_row(raw: dict) -> dict:
    return {str(k).strip(): (v.strip() if isinstance(v, str) else v) for k, v in raw.items()}


def _read_csv_rows(path: Path) -> list[dict]:
    with path.open(newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f, skipinitialspace=True)
        rows = []
        for raw in reader:
            row = _normalize_row(raw)
            if not any(v for v in row.values() if v not in (None, "")):
                continue
            rows.append(row)
    return rows


def _parse_row(row: dict) -> dict:
    fmt = (row.get("format") or "").strip()
    ct = (row.get("color_type") or "").strip()
    if fmt not in FORMAT_MAP:
        raise ValueError(f"Unknown format: {fmt!r} in row {row}")
    if ct not in COLOR_MAP:
        raise ValueError(f"Unknown color_type: {ct!r} in row {row}")
    iso = int(str(row.get("iso", "")).strip())
    return {
        "brand": (row.get("brand") or "").strip(),
        "name": (row.get("name") or "").strip(),
        "iso": iso,
        "format": FORMAT_MAP[fmt],
        "color_type": COLOR_MAP[ct],
        "description": (row.get("description") or "").strip() or None,
        "best_practice": (row.get("best_practice") or "").strip() or None,
        "image_urls": None,
    }


def import_film_stocks(csv_path: Path) -> int:
    rows = _read_csv_rows(csv_path)
    if not rows:
        raise SystemExit(f"No data rows in {csv_path}")

    parsed = [_parse_row(r) for r in rows]

    db = SessionLocal()
    try:
        # Allow deleting film_stocks while rolls still reference them
        db.execute(text("UPDATE rolls SET film_stock_id = NULL WHERE film_stock_id IS NOT NULL"))
        db.query(FilmStock).delete()
        for data in parsed:
            db.add(FilmStock(**data))
        db.commit()
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()

    return len(parsed)


def main() -> None:
    parser = argparse.ArgumentParser(description="Replace film_stocks from CSV")
    parser.add_argument(
        "--csv",
        type=Path,
        default=DEFAULT_CSV,
        help=f"Path to film_stock.csv (default: {DEFAULT_CSV})",
    )
    args = parser.parse_args()
    path = args.csv.resolve()
    if not path.is_file():
        raise SystemExit(f"File not found: {path}")

    n = import_film_stocks(path)
    print(f"Imported {n} film stock rows from {path}")


if __name__ == "__main__":
    main()
