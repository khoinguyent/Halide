"""Add max_frames to rolls

Revision ID: 20260314_max_frames
Revises: 20260314_notes
Create Date: 2026-03-14

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

revision: str = '20260314_max_frames'
down_revision: Union[str, Sequence[str], None] = '20260314_notes'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('rolls', sa.Column('max_frames', sa.Integer(), server_default=sa.text('36'), nullable=False))


def downgrade() -> None:
    op.drop_column('rolls', 'max_frames')
