"""add_subscription_and_storage_columns

Revision ID: 661b5699484b
Revises: 2c8494b5b0aa
Create Date: 2026-03-22 00:34:12.896803

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '661b5699484b'
down_revision: Union[str, Sequence[str], None] = '2c8494b5b0aa'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column('users', sa.Column('subscription_tier', sa.String(length=50), server_default=sa.text("'free'"), nullable=True))
    op.add_column('users', sa.Column('storage_used_bytes', sa.BigInteger(), server_default=sa.text('0'), nullable=True))
    op.add_column('users', sa.Column('storage_limit_bytes', sa.BigInteger(), server_default=sa.text('104857600'), nullable=True))


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_column('users', 'storage_limit_bytes')
    op.drop_column('users', 'storage_used_bytes')
    op.drop_column('users', 'subscription_tier')
