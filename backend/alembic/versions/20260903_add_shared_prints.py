"""add shared_prints table for photo+note sharing

Revision ID: e8a2c4f6b1d0
Revises: d1f4a7c9e3b6
Create Date: 2026-09-03 13:30:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision: str = "e8a2c4f6b1d0"
down_revision: Union[str, Sequence[str], None] = "d1f4a7c9e3b6"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "shared_prints",
        sa.Column("id", postgresql.UUID(as_uuid=True), server_default=sa.text("gen_random_uuid()"), nullable=False),
        sa.Column("public_token", sa.String(length=64), nullable=False),
        sa.Column("user_id", sa.String(length=255), nullable=False),
        sa.Column("image_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("roll_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("image_storage_key", sa.String(), nullable=False),
        sa.Column("note_text", sa.Text(), server_default=sa.text("''"), nullable=False),
        sa.Column("font_style", sa.String(length=16), server_default=sa.text("'hand'"), nullable=False),
        sa.Column("font_size", sa.Float(), server_default=sa.text("22"), nullable=False),
        sa.Column("text_color", sa.String(length=32), server_default=sa.text("'#2c2416'"), nullable=False),
        sa.Column("text_align", sa.String(length=16), server_default=sa.text("'left'"), nullable=False),
        sa.Column("pos_x", sa.Float(), server_default=sa.text("0.1"), nullable=False),
        sa.Column("pos_y", sa.Float(), server_default=sa.text("0.15"), nullable=False),
        sa.Column("paper_style", sa.String(length=16), server_default=sa.text("'cream'"), nullable=False),
        sa.Column(
            "recipient_emails",
            postgresql.JSONB(astext_type=sa.Text()),
            server_default=sa.text("'[]'::jsonb"),
            nullable=False,
        ),
        sa.Column("sender_display_name", sa.String(length=255), nullable=True),
        sa.Column("created_at", sa.DateTime(), server_default=sa.text("NOW()"), nullable=False),
        sa.Column("expires_at", sa.DateTime(), nullable=False),
        sa.Column("revoked_at", sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(["image_id"], ["images.id"]),
        sa.ForeignKeyConstraint(["roll_id"], ["rolls.id"]),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("public_token"),
    )
    op.create_index("ix_shared_prints_public_token", "shared_prints", ["public_token"], unique=True)
    op.create_index("ix_shared_prints_user_id", "shared_prints", ["user_id"], unique=False)


def downgrade() -> None:
    op.drop_index("ix_shared_prints_user_id", table_name="shared_prints")
    op.drop_index("ix_shared_prints_public_token", table_name="shared_prints")
    op.drop_table("shared_prints")
