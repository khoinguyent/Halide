"""Add notes to user_lenses

Revision ID: 20260314_notes
Revises: 20260314_user_lenses
Create Date: 2026-03-14

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

revision: str = '20260314_notes'
down_revision: Union[str, Sequence[str], None] = '20260314_user_lenses'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('user_lenses', sa.Column('notes', sa.String(), nullable=True))


def downgrade() -> None:
    op.drop_column('user_lenses', 'notes')
