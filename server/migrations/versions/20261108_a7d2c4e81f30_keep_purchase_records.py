"""keep purchase records after an account is deleted

Store purchases and refunds stay for 5 years (전자상거래법), cut off from the account:
coin_entries.user_id becomes nullable and is set to NULL when the account goes.

Revision ID: a7d2c4e81f30
Revises: f319cd303b12
Create Date: 2026-11-08 10:00:00.000000
"""
from alembic import op
import sqlalchemy as sa


revision = 'a7d2c4e81f30'
down_revision = 'f319cd303b12'
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table('coin_entries', schema=None) as batch_op:
        batch_op.alter_column('user_id', existing_type=sa.String(length=36), nullable=True)


def downgrade() -> None:
    # Rows of deleted accounts have no user to point at any more.
    op.execute("DELETE FROM coin_entries WHERE user_id IS NULL")
    with op.batch_alter_table('coin_entries', schema=None) as batch_op:
        batch_op.alter_column('user_id', existing_type=sa.String(length=36), nullable=False)
