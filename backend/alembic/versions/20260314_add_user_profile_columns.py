"""Add professional_nickname and bio to users

Revision ID: 20260314_user_profile
Revises: 20260314_max_frames
Create Date: 2026-03-14

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

revision: str = '20260314_user_profile'
down_revision: Union[str, Sequence[str], None] = '20260314_max_frames'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('users', sa.Column('professional_nickname', sa.String(length=255), nullable=True))
    op.add_column('users', sa.Column('bio', sa.String(), nullable=True))


def downgrade() -> None:
    op.drop_column('users', 'bio')
    op.drop_column('users', 'professional_nickname')
