"""add_onboarding_and_guide_flags

Revision ID: f7f8a799ef1e
Revises: 11533692803f
Create Date: 2026-04-01 22:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'f7f8a799ef1e'
down_revision: Union[str, Sequence[str], None] = '11533692803f'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('users', sa.Column('has_seen_onboarding', sa.Boolean(), server_default=sa.text("false"), nullable=False))
    op.add_column('users', sa.Column('has_seen_roll_guide', sa.Boolean(), server_default=sa.text("false"), nullable=False))
    op.add_column('users', sa.Column('has_seen_lab_guide', sa.Boolean(), server_default=sa.text("false"), nullable=False))


def downgrade() -> None:
    op.drop_column('users', 'has_seen_lab_guide')
    op.drop_column('users', 'has_seen_roll_guide')
    op.drop_column('users', 'has_seen_onboarding')
