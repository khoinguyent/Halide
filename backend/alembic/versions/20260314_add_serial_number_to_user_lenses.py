"""Add serial_number to user_lenses

Revision ID: 20260314_user_lenses
Revises: 532927a5f35c
Create Date: 2026-03-14

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

revision: str = '20260314_user_lenses'
down_revision: Union[str, Sequence[str], None] = '532927a5f35c'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('user_lenses', sa.Column('serial_number', sa.String(length=100), nullable=True))


def downgrade() -> None:
    op.drop_column('user_lenses', 'serial_number')
