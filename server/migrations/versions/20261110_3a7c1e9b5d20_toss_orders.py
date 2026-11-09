"""toss orders (web 코인 충전)

Revision ID: 3a7c1e9b5d20
Revises: fdd059159a37
Create Date: 2026-11-10 00:30:00
"""
from alembic import op
import sqlalchemy as sa


revision = '3a7c1e9b5d20'
down_revision = 'fdd059159a37'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table('toss_orders',
    sa.Column('id', sa.String(length=64), nullable=False),
    sa.Column('user_id', sa.String(length=36), nullable=True),
    sa.Column('package_id', sa.String(length=32), nullable=False),
    sa.Column('coins', sa.Integer(), nullable=False),
    sa.Column('amount', sa.Integer(), nullable=False),
    sa.Column('order_name', sa.String(length=40), nullable=False),
    sa.Column('status', sa.String(length=16), nullable=False),
    sa.Column('payment_key', sa.String(length=200), nullable=True),
    sa.Column('method', sa.String(length=32), nullable=True),
    sa.Column('failure_code', sa.String(length=64), nullable=True),
    sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
    sa.Column('expires_at', sa.DateTime(timezone=True), nullable=False),
    sa.Column('approved_at', sa.DateTime(timezone=True), nullable=True),
    sa.Column('canceled_at', sa.DateTime(timezone=True), nullable=True),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='SET NULL'),
    sa.PrimaryKeyConstraint('id'),
    sa.UniqueConstraint('payment_key')
    )
    with op.batch_alter_table('toss_orders', schema=None) as batch_op:
        batch_op.create_index(batch_op.f('ix_toss_orders_created_at'), ['created_at'], unique=False)
        batch_op.create_index(batch_op.f('ix_toss_orders_user_id'), ['user_id'], unique=False)


def downgrade() -> None:
    with op.batch_alter_table('toss_orders', schema=None) as batch_op:
        batch_op.drop_index(batch_op.f('ix_toss_orders_user_id'))
        batch_op.drop_index(batch_op.f('ix_toss_orders_created_at'))
    op.drop_table('toss_orders')
