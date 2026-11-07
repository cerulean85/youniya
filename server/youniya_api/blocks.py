"""Who a user must not see, and must not be seen by: everyone they blocked or who blocked them."""

from sqlalchemy import select
from sqlalchemy.orm import Session

from .models import Block, NebulaShare, ShareReport, StarShare


def hidden_users(db: Session, user_id: str) -> set[str]:
    rows = db.execute(select(Block.blocker_id, Block.blocked_id)
                      .where((Block.blocker_id == user_id) | (Block.blocked_id == user_id))).all()
    return {blocked if blocker == user_id else blocker for blocker, blocked in rows}


def visible_shares(db: Session, user_id: str, model: type[StarShare] | type[NebulaShare]) -> list:
    """Where-clauses for plaza shares this user may see: not taken down, not reported by them,
    and not from anyone on either side of a block."""
    kind = "star" if model is StarShare else "nebula"
    reported = select(ShareReport.target_id).where(ShareReport.kind == kind, ShareReport.user_id == user_id)
    return [model.hidden.is_(False), model.id.not_in(reported), model.user_id.not_in(hidden_users(db, user_id))]


def can_see(db: Session, user_id: str, row) -> bool:
    model = type(row)
    return db.scalar(select(model.id).where(model.id == row.id, *visible_shares(db, user_id, model))) is not None
