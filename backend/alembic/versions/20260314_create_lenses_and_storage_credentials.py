"""Create lenses, user_lenses, storage_credentials tables

Revision ID: 20260314_lenses_storage
Revises: 532927a5f35c
Create Date: 2026-03-14

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = '20260314_lenses_storage'
down_revision: Union[str, Sequence[str], None] = '532927a5f35c'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Lenses (master table)
    op.create_table('lenses',
        sa.Column('id', sa.UUID(), server_default=sa.text('gen_random_uuid()'), nullable=False),
        sa.Column('brand', sa.String(length=100), nullable=False),
        sa.Column('model', sa.String(length=100), nullable=False),
        sa.Column('focal_length', sa.String(length=20), nullable=True),
        sa.Column('max_aperture', sa.String(length=20), nullable=True),
        sa.Column('description', sa.String(), nullable=True),
        sa.Column('image_urls', postgresql.JSONB(astext_type=sa.Text()), nullable=True),
        sa.PrimaryKeyConstraint('id')
    )
    # User lenses (user-owned lens instances, optional link to user_camera)
    op.create_table('user_lenses',
        sa.Column('id', sa.UUID(), server_default=sa.text('gen_random_uuid()'), nullable=False),
        sa.Column('user_id', sa.String(length=255), nullable=True),
        sa.Column('lens_id', sa.UUID(), nullable=True),
        sa.Column('parent_camera_id', sa.UUID(), nullable=True),
        sa.Column('gear_nickname', sa.String(length=255), nullable=True),
        sa.Column('created_at', sa.DateTime(), server_default=sa.text('NOW()'), nullable=True),
        sa.ForeignKeyConstraint(['lens_id'], ['lenses.id'], ),
        sa.ForeignKeyConstraint(['parent_camera_id'], ['user_cameras.id'], ),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ),
        sa.PrimaryKeyConstraint('id')
    )
    # Storage provider enum and credentials (BE_4.1 - external storage config per user)
    op.create_table('storage_credentials',
        sa.Column('id', sa.UUID(), server_default=sa.text('gen_random_uuid()'), nullable=False),
        sa.Column('user_id', sa.String(length=255), nullable=False),
        sa.Column('provider', sa.Enum('gdrive', 'onedrive', 'ftp', 'smb', name='storageproviderenum', create_type=True), nullable=False),
        sa.Column('identifier', sa.String(length=255), nullable=True),
        sa.Column('host', sa.String(length=255), nullable=True),
        sa.Column('username', sa.String(length=255), nullable=True),
        sa.Column('encrypted_auth_data', sa.String(), nullable=False),
        sa.Column('is_archive', sa.Boolean(), server_default=sa.text('FALSE'), nullable=True),
        sa.Column('created_at', sa.DateTime(), server_default=sa.text('NOW()'), nullable=True),
        sa.Column('updated_at', sa.DateTime(), server_default=sa.text('NOW()'), nullable=True),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )


def downgrade() -> None:
    op.drop_table('storage_credentials')
    op.execute('DROP TYPE IF EXISTS storageproviderenum')
    op.drop_table('user_lenses')
    op.drop_table('lenses')
