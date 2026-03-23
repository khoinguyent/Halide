"""merge_heads

Revision ID: 2c8494b5b0aa
Revises: 20260314_storage_head, 20260320_add_roll_drive_url
Create Date: 2026-03-22 00:34:07.191320

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '2c8494b5b0aa'
down_revision: Union[str, Sequence[str], None] = ('20260314_storage_head', '20260320_add_roll_drive_url')
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    pass


def downgrade() -> None:
    """Downgrade schema."""
    pass
