"""add user preferred_locale

Revision ID: c7e1a9f3b2d4
Revises: b4c8d2e6f1a0
Create Date: 2026-06-30 12:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "c7e1a9f3b2d4"
down_revision: Union[str, Sequence[str], None] = "b4c8d2e6f1a0"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column("preferred_locale", sa.String(length=16), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("users", "preferred_locale")
