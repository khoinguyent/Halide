"""Add storage_credentials table (for DBs that already ran old chain without it)

Revision ID: 20260314_storage_head
Revises: 20260314_uc_images
Create Date: 2026-03-14

Use CREATE TABLE IF NOT EXISTS so safe for DBs that already have it from 20260314_lenses_storage.
"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = '20260314_storage_head'
down_revision: Union[str, Sequence[str], None] = '20260314_uc_images'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Create enum only if not exists (PostgreSQL 9.1+)
    op.execute("DO $$ BEGIN CREATE TYPE storageproviderenum AS ENUM ('gdrive', 'onedrive', 'ftp', 'smb'); EXCEPTION WHEN duplicate_object THEN null; END $$")
    # Create table only if not exists
    op.execute("""
        CREATE TABLE IF NOT EXISTS storage_credentials (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            user_id VARCHAR(255) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            provider storageproviderenum NOT NULL,
            identifier VARCHAR(255),
            host VARCHAR(255),
            username VARCHAR(255),
            encrypted_auth_data VARCHAR NOT NULL,
            is_archive BOOLEAN DEFAULT FALSE,
            created_at TIMESTAMP DEFAULT NOW(),
            updated_at TIMESTAMP DEFAULT NOW()
        )
    """)


def downgrade() -> None:
    op.drop_table('storage_credentials')
    op.execute('DROP TYPE IF EXISTS storageproviderenum')
