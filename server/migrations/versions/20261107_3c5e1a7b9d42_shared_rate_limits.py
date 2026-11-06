"""shared rate limits

Revision ID: 3c5e1a7b9d42
Revises: ed9f221b7bcb
Create Date: 2026-11-07 10:00:00
"""
from alembic import op
import sqlalchemy as sa


revision = '3c5e1a7b9d42'
down_revision = 'ed9f221b7bcb'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table('rate_hits',
    sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
    sa.Column('key', sa.String(length=200), nullable=False),
    sa.Column('at', sa.Float(), nullable=False),
    sa.PrimaryKeyConstraint('id')
    )
    op.create_index('ix_rate_hits_key_at', 'rate_hits', ['key', 'at'], unique=False)


def downgrade() -> None:
    op.drop_index('ix_rate_hits_key_at', table_name='rate_hits')
    op.drop_table('rate_hits')
