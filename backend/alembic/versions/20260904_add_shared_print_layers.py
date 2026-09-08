"""add layers jsonb to shared_prints for multi-text verso notes

Revision ID: f1a3c5e7b9d2
Revises: e8a2c4f6b1d0
Create Date: 2026-09-04 12:50:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision: str = "f1a3c5e7b9d2"
down_revision: Union[str, Sequence[str], None] = "e8a2c4f6b1d0"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "shared_prints",
        sa.Column(
            "layers",
            postgresql.JSONB(astext_type=sa.Text()),
            server_default=sa.text("'[]'::jsonb"),
            nullable=False,
        ),
    )
    op.alter_column(
        "shared_prints",
        "font_style",
        existing_type=sa.String(length=16),
        type_=sa.String(length=32),
        existing_nullable=False,
        existing_server_default=sa.text("'hand'"),
    )


def downgrade() -> None:
    op.alter_column(
        "shared_prints",
        "font_style",
        existing_type=sa.String(length=32),
        type_=sa.String(length=16),
        existing_nullable=False,
        existing_server_default=sa.text("'hand'"),
    )
    op.drop_column("shared_prints", "layers")
