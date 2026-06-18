"""extend purchase_history with Apple / RC transaction fields

Revision ID: a3f9e1c2b4d8
Revises: fb19ccfe3508
Create Date: 2026-05-13

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "a3f9e1c2b4d8"
down_revision: Union[str, Sequence[str], None] = "fb19ccfe3508"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    conn = op.get_bind()
    # Idempotent for Postgres (may already exist if applied manually on a droplet).
    conn.execute(
        sa.text(
            "ALTER TABLE purchase_history ADD COLUMN IF NOT EXISTS "
            "original_transaction_id VARCHAR(255)"
        )
    )
    conn.execute(
        sa.text(
            "ALTER TABLE purchase_history ADD COLUMN IF NOT EXISTS rc_event_id VARCHAR(255)"
        )
    )

    conn.execute(
        sa.text(
            """
            UPDATE purchase_history
            SET
              rc_event_id = COALESCE(rc_event_id, (payload::json -> 'event' ->> 'id')),
              original_transaction_id = COALESCE(
                  original_transaction_id,
                  (payload::json -> 'event' ->> 'original_transaction_id')
              ),
              transaction_id = COALESCE(
                  NULLIF(TRIM(transaction_id), ''),
                  NULLIF(TRIM(payload::json -> 'event' ->> 'transaction_id'), ''),
                  NULLIF(TRIM(payload::json -> 'event' ->> 'original_transaction_id'), '')
              )
            WHERE payload IS NOT NULL
              AND TRIM(payload) <> ''
              AND LEFT(TRIM(payload), 1) = '{'
            """
        )
    )


def downgrade() -> None:
    conn = op.get_bind()
    conn.execute(sa.text("ALTER TABLE purchase_history DROP COLUMN IF EXISTS rc_event_id"))
    conn.execute(sa.text("ALTER TABLE purchase_history DROP COLUMN IF EXISTS original_transaction_id"))
