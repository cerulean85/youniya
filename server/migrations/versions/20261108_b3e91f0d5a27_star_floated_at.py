"""star floated_at

Revision ID: b3e91f0d5a27
Revises: 6430fe7ce4a4
Create Date: 2026-11-08 18:00:00
"""
from alembic import op
import sqlalchemy as sa


revision = 'b3e91f0d5a27'
down_revision = '6430fe7ce4a4'
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table('stars', schema=None) as batch_op:
        batch_op.add_column(sa.Column('floated_at', sa.DateTime(timezone=True), nullable=True))
        batch_op.create_index(batch_op.f('ix_stars_floated_at'), ['floated_at'], unique=False)
    # Stars floated before this column: the time they were written is the best we know.
    op.execute("UPDATE stars SET floated_at = created_at WHERE state = 'floated'")


def downgrade() -> None:
    with op.batch_alter_table('stars', schema=None) as batch_op:
        batch_op.drop_index(batch_op.f('ix_stars_floated_at'))
        batch_op.drop_column('floated_at')
