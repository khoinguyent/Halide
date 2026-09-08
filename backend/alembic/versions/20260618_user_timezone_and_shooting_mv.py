"""user timezone and shooting analytics materialized view

Revision ID: b4c8d2e6f1a0
Revises: a3f9e1c2b4d8
Create Date: 2026-06-18 12:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "b4c8d2e6f1a0"
down_revision: Union[str, Sequence[str], None] = "a3f9e1c2b4d8"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

MV_NAME = "mv_user_shooting_shots"


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column("timezone", sa.String(length=64), nullable=True),
    )

    op.execute(
        f"""
        CREATE MATERIALIZED VIEW {MV_NAME} AS
        SELECT
            i.id AS image_id,
            r.user_id,
            i.created_at AS shot_at,
            fs.id AS film_stock_id,
            fs.brand AS film_brand,
            fs.name AS film_name,
            ul.id AS user_lens_id,
            l.brand AS lens_brand,
            l.model AS lens_model,
            ul.gear_nickname AS lens_nickname
        FROM images i
        INNER JOIN rolls r ON r.id = i.roll_id
        INNER JOIN film_stocks fs ON fs.id = r.film_stock_id
        LEFT JOIN user_lenses ul ON ul.id = r.user_lens_id
        LEFT JOIN lenses l ON l.id = ul.lens_id
        WHERE i.created_at >= (CURRENT_DATE - INTERVAL '364 days')
        WITH NO DATA
        """
    )

    op.execute(
        f"CREATE UNIQUE INDEX uq_{MV_NAME}_image_id ON {MV_NAME} (image_id)"
    )
    op.execute(
        f"CREATE INDEX ix_{MV_NAME}_user_shot_at ON {MV_NAME} (user_id, shot_at)"
    )
    op.execute(f"REFRESH MATERIALIZED VIEW {MV_NAME}")


def downgrade() -> None:
    op.execute(f"DROP MATERIALIZED VIEW IF EXISTS {MV_NAME}")
    op.drop_column("users", "timezone")
