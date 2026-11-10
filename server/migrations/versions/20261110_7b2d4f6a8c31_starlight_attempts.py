"""starlight attempts (20장 별빛 받기 그만두기)

Revision ID: 7b2d4f6a8c31
Revises: 3a7c1e9b5d20
Create Date: 2026-11-10 12:00:00
"""
from alembic import op
import sqlalchemy as sa


revision = '7b2d4f6a8c31'
down_revision = '3a7c1e9b5d20'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column('stars', sa.Column('starlight_cancelled', sa.Boolean(), server_default=sa.false(), nullable=False))
    op.create_table('starlight_attempts',
    sa.Column('id', sa.String(length=64), nullable=False),
    sa.Column('user_id', sa.String(length=36), nullable=False),
    sa.Column('star_id', sa.String(length=36), nullable=True),
    sa.Column('new_star', sa.Boolean(), nullable=False),
    sa.Column('status', sa.String(length=12), nullable=False),
    sa.Column('used', sa.String(length=8), nullable=True),
    sa.Column('charged', sa.Integer(), nullable=False),
    sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
    sa.Column('finished_at', sa.DateTime(timezone=True), nullable=True),
    sa.ForeignKeyConstraint(['star_id'], ['stars.id'], ondelete='CASCADE'),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id')
    )
    op.create_index('ix_starlight_attempts_user_id', 'starlight_attempts', ['user_id'])
    op.create_index('ix_starlight_attempts_star_id', 'starlight_attempts', ['star_id'])
    op.create_index('ix_starlight_attempts_created_at', 'starlight_attempts', ['created_at'])


def downgrade() -> None:
    op.drop_table('starlight_attempts')
    op.drop_column('stars', 'starlight_cancelled')
