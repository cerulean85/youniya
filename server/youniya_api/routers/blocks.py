"""차단하기 (App Store 1.2). The client only knows what it saw (a line, a shared star or nebula),
so a block is made from that; the server finds the writer. The list never shows who."""

from typing import Literal

from fastapi import APIRouter, Depends
from pydantic import BaseModel, model_validator
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..blocks import hidden_users
from ..deps import ApiError, consented_user, get_db
from ..models import Block, NebulaShare, StarlightLine, StarShare, User
from ..ratelimit import per_user
from ..views import iso

router = APIRouter(prefix="/v1/blocks", tags=["blocks"])

Source = Literal["line", "star", "nebula"]


class BlockIn(BaseModel):
    line_id: str | None = None  # a 별빛 한 줄
    star_id: str | None = None  # a plaza star: its share id (the `id` in GET /v1/plaza/stars)
    nebula_id: str | None = None  # a plaza nebula: its share id (the `id` in GET /v1/plaza/nebulae)

    @model_validator(mode="after")
    def _one(self):
        if sum(v is not None for v in (self.line_id, self.star_id, self.nebula_id)) != 1:
            raise ValueError("exactly one of line_id, star_id, nebula_id")
        return self


_FROM = {"line": StarlightLine, "star": StarShare, "nebula": NebulaShare}


def writer_of(db: Session, user: User, source: Source, target_id: str) -> str:
    """Something already hidden from this user is not found: the answer would tell who wrote it."""
    row = db.get(_FROM[source], target_id)
    if row is None or row.user_id in hidden_users(db, user.id):
        raise ApiError(404, "not_found", "찾지 못했어요.")
    return row.user_id


def block(db: Session, user: User, source: Source, target_id: str) -> Block:
    """Idempotent: blocking the same person again returns the first block."""
    blocked = writer_of(db, user, source, target_id)
    if blocked == user.id:
        raise ApiError(422, "own_share", "나를 차단할 수는 없어요.")
    row = db.scalar(select(Block).where(Block.blocker_id == user.id, Block.blocked_id == blocked))
    if row is None:
        row = Block(blocker_id=user.id, blocked_id=blocked, source=source)
        db.add(row)
        db.flush()
    return row


def _view(b: Block) -> dict:
    return {"id": b.id, "created_at": iso(b.created_at), "source": b.source}


@router.post("", status_code=201, dependencies=[per_user("block", 30, 3600)])
def create(body: BlockIn, user: User = Depends(consented_user), db: Session = Depends(get_db)):
    source, target = next((s, v) for s, v in (("line", body.line_id), ("star", body.star_id),
                                              ("nebula", body.nebula_id)) if v is not None)
    row = block(db, user, source, target)
    db.commit()
    return _view(row)


@router.get("")
def list_blocks(user: User = Depends(consented_user), db: Session = Depends(get_db)):
    """설정 › 차단한 별지기: when and where, never who."""
    rows = db.scalars(select(Block).where(Block.blocker_id == user.id).order_by(Block.created_at.desc()))
    return {"items": [_view(b) for b in rows]}


@router.delete("/{block_id}", status_code=204)
def unblock(block_id: str, user: User = Depends(consented_user), db: Session = Depends(get_db)):
    row = db.get(Block, block_id)
    if row is None or row.blocker_id != user.id:
        raise ApiError(404, "not_found", "찾지 못했어요.")
    db.delete(row)
    db.commit()
