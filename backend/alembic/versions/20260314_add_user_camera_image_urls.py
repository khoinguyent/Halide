"""Add image_urls and primary_image_index to user_cameras

Revision ID: 20260314_uc_images
Revises: 20260314_add_notes_to_user_lenses
Create Date: 2026-03-14

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = '20260314_uc_images'
down_revision: Union[str, Sequence[str], None] = '20260314_user_profile'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('user_cameras', sa.Column('image_urls', postgresql.JSONB(astext_type=sa.Text()), nullable=True))
    op.add_column('user_cameras', sa.Column('primary_image_index', sa.Integer(), server_default='0', nullable=False))


def downgrade() -> None:
    op.drop_column('user_cameras', 'primary_image_index')
    op.drop_column('user_cameras', 'image_urls')
