"""Add title/description to rolls

Revision ID: 20260319_roll_title_description
Revises: 20260314_max_frames
Create Date: 2026-03-19
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = "20260319_roll_title_description"
down_revision: Union[str, Sequence[str], None] = "20260314_max_frames"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("rolls", sa.Column("title", sa.String(length=255), nullable=True))
    op.add_column("rolls", sa.Column("description", sa.String(), nullable=True))


def downgrade() -> None:
    op.drop_column("rolls", "description")
    op.drop_column("rolls", "title")

