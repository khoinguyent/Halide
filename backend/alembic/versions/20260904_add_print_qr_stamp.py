"""add qr stamp crop + stored qr key on shared_prints

Revision ID: a4b6c8d0e2f1
Revises: f1a3c5e7b9d2
Create Date: 2026-09-04 14:40:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "a4b6c8d0e2f1"
down_revision: Union[str, Sequence[str], None] = "f1a3c5e7b9d2"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("shared_prints", sa.Column("qr_stamp_x", sa.Float(), nullable=True))
    op.add_column("shared_prints", sa.Column("qr_stamp_y", sa.Float(), nullable=True))
    op.add_column("shared_prints", sa.Column("qr_stamp_size", sa.Float(), nullable=True))
    op.add_column("shared_prints", sa.Column("qr_storage_key", sa.String(), nullable=True))


def downgrade() -> None:
    op.drop_column("shared_prints", "qr_storage_key")
    op.drop_column("shared_prints", "qr_stamp_size")
    op.drop_column("shared_prints", "qr_stamp_y")
    op.drop_column("shared_prints", "qr_stamp_x")
