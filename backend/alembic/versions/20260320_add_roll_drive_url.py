"""Add drive_url to rolls

Revision ID: 20260320_add_roll_drive_url
Revises: 20260319_roll_title_description
Create Date: 2026-03-20
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "20260320_add_roll_drive_url"
down_revision: Union[str, Sequence[str], None] = "20260319_roll_title_description"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("rolls", sa.Column("drive_url", sa.String(), nullable=True))


def downgrade() -> None:
    op.drop_column("rolls", "drive_url")

