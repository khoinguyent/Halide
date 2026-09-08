"""add personal drive sync jobs/roll/image tracking tables

Revision ID: d1f4a7c9e3b6
Revises: c7e1a9f3b2d4
Create Date: 2026-08-05 09:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision: str = "d1f4a7c9e3b6"
down_revision: Union[str, Sequence[str], None] = "c7e1a9f3b2d4"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


_job_status = postgresql.ENUM(
    "queued", "running", "succeeded", "failed", "partial",
    name="personal_drive_sync_job_status",
    create_type=False,
)
_sync_status = postgresql.ENUM(
    "pending", "syncing", "synced", "failed",
    name="personal_drive_sync_status",
    create_type=False,
)
_image_sync_status = postgresql.ENUM(
    "pending", "syncing", "synced", "failed",
    name="personal_drive_image_sync_status",
    create_type=False,
)


def upgrade() -> None:
    bind = op.get_bind()
    postgresql.ENUM(
        "queued", "running", "succeeded", "failed", "partial",
        name="personal_drive_sync_job_status",
    ).create(bind, checkfirst=True)
    postgresql.ENUM(
        "pending", "syncing", "synced", "failed",
        name="personal_drive_sync_status",
    ).create(bind, checkfirst=True)
    postgresql.ENUM(
        "pending", "syncing", "synced", "failed",
        name="personal_drive_image_sync_status",
    ).create(bind, checkfirst=True)

    inspector = sa.inspect(bind)
    existing = set(inspector.get_table_names())

    if "personal_drive_sync_jobs" not in existing:
        op.create_table(
            "personal_drive_sync_jobs",
            sa.Column("id", postgresql.UUID(as_uuid=True), server_default=sa.text("gen_random_uuid()"), primary_key=True),
            sa.Column("user_id", sa.String(length=255), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
            sa.Column("roll_ids", postgresql.JSONB(), nullable=True),
            sa.Column("force", sa.Boolean(), nullable=False, server_default=sa.text("FALSE")),
            sa.Column("status", _job_status, nullable=False, server_default="queued"),
            sa.Column("total_rolls", sa.Integer(), nullable=False, server_default="0"),
            sa.Column("completed_rolls", sa.Integer(), nullable=False, server_default="0"),
            sa.Column("failed_rolls", sa.Integer(), nullable=False, server_default="0"),
            sa.Column("skipped_rolls", sa.Integer(), nullable=False, server_default="0"),
            sa.Column("result", postgresql.JSONB(), nullable=True),
            sa.Column("error", sa.Text(), nullable=True),
            sa.Column("created_at", sa.DateTime(), server_default=sa.text("NOW()")),
            sa.Column("started_at", sa.DateTime(), nullable=True),
            sa.Column("finished_at", sa.DateTime(), nullable=True),
        )
        op.create_index(
            "ix_personal_drive_sync_jobs_user_status",
            "personal_drive_sync_jobs",
            ["user_id", "status"],
        )

    if "personal_drive_roll_syncs" not in existing:
        op.create_table(
            "personal_drive_roll_syncs",
            sa.Column("id", postgresql.UUID(as_uuid=True), server_default=sa.text("gen_random_uuid()"), primary_key=True),
            sa.Column("roll_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("rolls.id", ondelete="CASCADE"), nullable=False, unique=True),
            sa.Column(
                "storage_credential_id",
                postgresql.UUID(as_uuid=True),
                sa.ForeignKey("storage_credentials.id", ondelete="SET NULL"),
                nullable=True,
            ),
            sa.Column("drive_folder_id", sa.String(length=255), nullable=True),
            sa.Column("readme_hash", sa.String(length=64), nullable=True),
            sa.Column("status", _sync_status, nullable=False, server_default="pending"),
            sa.Column("images_total", sa.Integer(), nullable=False, server_default="0"),
            sa.Column("images_uploaded", sa.Integer(), nullable=False, server_default="0"),
            sa.Column("last_synced_at", sa.DateTime(), nullable=True),
            sa.Column("last_error", sa.Text(), nullable=True),
            sa.Column("created_at", sa.DateTime(), server_default=sa.text("NOW()")),
            sa.Column("updated_at", sa.DateTime(), server_default=sa.text("NOW()")),
        )

    if "personal_drive_image_syncs" not in existing:
        op.create_table(
            "personal_drive_image_syncs",
            sa.Column("id", postgresql.UUID(as_uuid=True), server_default=sa.text("gen_random_uuid()"), primary_key=True),
            sa.Column("image_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("images.id", ondelete="CASCADE"), nullable=False, unique=True),
            sa.Column(
                "roll_sync_id",
                postgresql.UUID(as_uuid=True),
                sa.ForeignKey("personal_drive_roll_syncs.id", ondelete="CASCADE"),
                nullable=False,
            ),
            sa.Column("drive_file_id", sa.String(length=255), nullable=True),
            sa.Column("content_hash", sa.String(length=64), nullable=True),
            sa.Column("status", _image_sync_status, nullable=False, server_default="pending"),
            sa.Column("synced_at", sa.DateTime(), nullable=True),
            sa.Column("last_error", sa.Text(), nullable=True),
            sa.Column("created_at", sa.DateTime(), server_default=sa.text("NOW()")),
            sa.Column("updated_at", sa.DateTime(), server_default=sa.text("NOW()")),
            sa.UniqueConstraint("image_id", name="uq_personal_drive_image_syncs_image_id"),
        )
        op.create_index(
            "ix_personal_drive_image_syncs_roll_sync_id",
            "personal_drive_image_syncs",
            ["roll_sync_id"],
        )


def downgrade() -> None:
    op.drop_index("ix_personal_drive_image_syncs_roll_sync_id", table_name="personal_drive_image_syncs")
    op.drop_table("personal_drive_image_syncs")
    op.drop_table("personal_drive_roll_syncs")
    op.drop_index("ix_personal_drive_sync_jobs_user_status", table_name="personal_drive_sync_jobs")
    op.drop_table("personal_drive_sync_jobs")
    _image_sync_status.drop(op.get_bind(), checkfirst=True)
    _sync_status.drop(op.get_bind(), checkfirst=True)
    _job_status.drop(op.get_bind(), checkfirst=True)
