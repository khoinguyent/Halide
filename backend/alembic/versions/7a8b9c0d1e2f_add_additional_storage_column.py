"""add_additional_storage_column

Revision ID: 7a8b9c0d1e2f
Revises: 661b5699484b
Create Date: 2026-03-22 23:54:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '7a8b9c0d1e2f'
down_revision: Union[str, Sequence[str], None] = 'f5921b4a1449'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column('users', sa.Column('additional_storage_bytes', sa.BigInteger(), server_default=sa.text('0'), nullable=True))


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_column('users', 'additional_storage_bytes')
