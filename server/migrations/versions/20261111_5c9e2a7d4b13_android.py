"""android: FCM tokens in device_tokens, auth_handoffs (안드로이드 Apple 로그인)

Revision ID: 5c9e2a7d4b13
Revises: 7b2d4f6a8c31
Create Date: 2026-11-11 21:00:00
"""
from alembic import op
import sqlalchemy as sa


revision = '5c9e2a7d4b13'
down_revision = '7b2d4f6a8c31'
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table('device_tokens') as b:
        b.alter_column('token', existing_type=sa.String(length=200), type_=sa.String(length=512),
                       existing_nullable=False)
    op.create_table('auth_handoffs',
    sa.Column('code_hash', sa.String(length=64), nullable=False),
    sa.Column('purpose', sa.String(length=8), nullable=False),
    sa.Column('provider', sa.String(length=16), nullable=False),
    sa.Column('sub', sa.String(length=255), nullable=False),
    sa.Column('challenge', sa.String(length=64), nullable=False),
    sa.Column('apple_code_enc', sa.Text(), nullable=True),
    sa.Column('expires_at', sa.DateTime(timezone=True), nullable=False),
    sa.Column('used_at', sa.DateTime(timezone=True), nullable=True),
    sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
    sa.PrimaryKeyConstraint('code_hash')
    )
    op.create_index('ix_auth_handoffs_expires_at', 'auth_handoffs', ['expires_at'])


def downgrade() -> None:
    op.drop_table('auth_handoffs')
    with op.batch_alter_table('device_tokens') as b:
        b.alter_column('token', existing_type=sa.String(length=512), type_=sa.String(length=200),
                       existing_nullable=False)
