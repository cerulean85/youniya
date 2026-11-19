"""coin expiry: coin_lots (backfilled), users.coins_active_at, coins_notice_days, email_enc;
auth_handoffs.email_enc; starlight_attempts.charged_lots

Revision ID: 8d1f3b6e2a47
Revises: 5c9e2a7d4b13
Create Date: 2026-11-19 12:00:00
"""
import uuid

from alembic import op
import sqlalchemy as sa


revision = '8d1f3b6e2a47'
down_revision = '5c9e2a7d4b13'
branch_labels = None
depends_on = None


def _source(tx):
    if not tx:
        return "server"
    key = tx.removeprefix("refund:")
    return "toss" if key.startswith("toss:") else "google_play" if key.startswith("gp:") else "app_store"


def _backfill(bind) -> None:
    """Each account's coin history replayed oldest first: charges make lots, uses and take-backs draw the oldest
    (a refund its own purchase first). App Store charges so far never expire. If the replay doesn't end at the
    balance, the difference is a lot that never expires (the person's favour) or comes off the newest lots."""
    entries = bind.execute(sa.text(
        "SELECT id, user_id, delta, transaction_id, created_at FROM coin_entries "
        "WHERE user_id IS NOT NULL ORDER BY user_id, created_at, id")).all()
    balances = dict(bind.execute(sa.text("SELECT id, coins FROM users")).all())
    by_user: dict[str, list] = {}
    for e in entries:
        by_user.setdefault(e.user_id, []).append(e)
    lots_table = sa.table("coin_lots", *(sa.column(c) for c in
                          ("id", "user_id", "entry_id", "source", "expires", "amount", "remaining", "created_at")))
    rows = []
    for user_id, coins in balances.items():
        lots = []
        by_tx = {}
        for e in by_user.get(user_id, []):
            if e.delta > 0:
                lot = {"id": str(uuid.uuid4()), "user_id": user_id, "entry_id": e.id if e.transaction_id else None,
                       "source": _source(e.transaction_id), "expires": _source(e.transaction_id) != "app_store",
                       "amount": e.delta, "remaining": e.delta, "created_at": e.created_at}
                lots.append(lot)
                if e.transaction_id:
                    by_tx[e.transaction_id] = lot
            elif e.delta < 0:
                need = -e.delta
                first = by_tx.get((e.transaction_id or "").removeprefix("refund:"))
                for lot in ([first] if first else []) + lots:
                    n = min(lot["remaining"], need)
                    lot["remaining"] -= n
                    need -= n
                    if need == 0:
                        break
        diff = coins - sum(l["remaining"] for l in lots)
        for lot in reversed(lots):
            if diff >= 0:
                break
            n = min(lot["remaining"], -diff)
            lot["remaining"] -= n
            diff += n
        if diff > 0:
            lots.append({"id": str(uuid.uuid4()), "user_id": user_id, "entry_id": None, "source": "server",
                         "expires": False, "amount": diff, "remaining": diff, "created_at": sa.func.now()})
        rows += [l for l in lots if l["remaining"] > 0]
    for row in rows:
        bind.execute(sa.insert(lots_table).values(**row))


def upgrade() -> None:
    op.create_table('coin_lots',
    sa.Column('id', sa.String(length=36), nullable=False),
    sa.Column('user_id', sa.String(length=36), nullable=False),
    sa.Column('entry_id', sa.String(length=36), nullable=True),
    sa.Column('source', sa.String(length=16), nullable=False),
    sa.Column('expires', sa.Boolean(), nullable=False),
    sa.Column('amount', sa.Integer(), nullable=False),
    sa.Column('remaining', sa.Integer(), nullable=False),
    sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id')
    )
    op.create_index('ix_coin_lots_user_id', 'coin_lots', ['user_id'])
    op.create_index('ix_coin_lots_entry_id', 'coin_lots', ['entry_id'])
    op.create_index('ix_coin_lots_created_at', 'coin_lots', ['created_at'])
    # No activity backfill: activity before the policy starts (2026-12-01) counts from that day.
    with op.batch_alter_table('users') as b:
        b.add_column(sa.Column('coins_active_at', sa.DateTime(timezone=True), nullable=True))
        b.add_column(sa.Column('coins_notice_days', sa.Integer(), nullable=True))
        b.add_column(sa.Column('email_enc', sa.Text(), nullable=True))
    with op.batch_alter_table('auth_handoffs') as b:
        b.add_column(sa.Column('email_enc', sa.Text(), nullable=True))
    with op.batch_alter_table('starlight_attempts') as b:
        b.add_column(sa.Column('charged_lots', sa.JSON(), nullable=True))
    _backfill(op.get_bind())


def downgrade() -> None:
    with op.batch_alter_table('starlight_attempts') as b:
        b.drop_column('charged_lots')
    with op.batch_alter_table('auth_handoffs') as b:
        b.drop_column('email_enc')
    with op.batch_alter_table('users') as b:
        b.drop_column('email_enc')
        b.drop_column('coins_notice_days')
        b.drop_column('coins_active_at')
    op.drop_table('coin_lots')
