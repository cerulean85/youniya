"""51–55 성운 그리기, 84 실루엣, 85 손님별, 70 성운 상세, 80 컬렉션, 83 성운 이야기, 71 하늘에 띄우기."""

from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Request
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.orm import Session

from .. import membership, privacy
from ..blocks import visible_shares
from ..deps import ApiError, consented_user, get_cipher, get_db
from ..models import Beside, Nebula, NebulaShare, Resonance, Star, StarShare, User
from ..rules import MAX_GUEST_STARS, MEMBER_SILHOUETTES, MIN_NEBULA_STARS, NEBULA_SILHOUETTES
from ..security import Cipher
from ..views import iso

router = APIRouter(prefix="/v1/nebulae", tags=["nebulae"])


class NebulaIn(BaseModel):
    name: str = Field(..., min_length=1, max_length=20)  # 54 이 성운의 이름은요?
    silhouette: str | None = None  # None: 직접 그리기
    star_ids: list[str] = Field(..., min_length=MIN_NEBULA_STARS, max_length=200)
    edges: list[tuple[int, int]] = Field(default_factory=list)  # 53 잇기, indexes into star_ids
    guest_share_ids: list[str] = Field(default_factory=list, max_length=MAX_GUEST_STARS)


class NebulaEdit(BaseModel):
    """Only what is given changes. New `star_ids` need their `edges` too: the indexes move."""
    name: str | None = Field(None, min_length=1, max_length=20)
    silhouette: str | None = None
    star_ids: list[str] | None = Field(None, min_length=MIN_NEBULA_STARS, max_length=200)
    edges: list[tuple[int, int]] | None = None
    guest_share_ids: list[str] | None = Field(None, max_length=MAX_GUEST_STARS)


class ShareIn(BaseModel):
    receive_lines: bool = True  # 71 별빛 한 줄 받기
    quote: str | None = Field(None, max_length=300)  # 71 가린 한 문장 함께 보이기


def owned_nebula(db: Session, user: User, nebula_id: str) -> Nebula:
    n = db.get(Nebula, nebula_id)
    if n is None or n.user_id != user.id:
        raise ApiError(404, "not_found", "성운을 찾지 못했어요.")
    return n


def _stars(db: Session, n: Nebula) -> list[Star]:
    rows = {s.id: s for s in db.scalars(select(Star).where(Star.id.in_(n.star_ids)))}
    return sorted((rows[i] for i in n.star_ids if i in rows), key=lambda s: s.created_at)


def nebula_shape(n: Nebula, stars: list[Star], cipher: Cipher) -> dict:
    """What a shared nebula shows: the outline and each star's colour and form, never the writing."""
    out = []
    for s in stars:
        a = cipher.dec_json(s.analysis_enc)
        out.append({"mood": s.mood, "shape": a["shape"], "depth_level": a["depth_level"]})
    return {"silhouette": n.silhouette, "edges": n.edges, "stars": out}


def _snapshot(row: NebulaShare, n: Nebula, stars: list[Star], cipher: Cipher) -> None:
    """What the plaza keeps of a nebula: masked name, shape, colours and depth."""
    row.name = privacy.scan(n.name)["masked"]
    row.shape = nebula_shape(n, stars, cipher)
    row.moods = list(dict.fromkeys(s.mood for s in stars))
    row.depth_level = round(avg_depth(stars, cipher) or 1)


def avg_depth(stars: list[Star], cipher: Cipher) -> float | None:
    levels = [cipher.dec_json(s.analysis_enc)["depth_level"] for s in stars]
    return round(sum(levels) / len(levels), 1) if levels else None


def _check_silhouette(db: Session, request: Request, user: User, silhouette: str | None) -> None:
    if silhouette is not None and silhouette not in NEBULA_SILHOUETTES + MEMBER_SILHOUETTES:
        raise ApiError(422, "unknown_silhouette", "알 수 없는 모양이에요.")
    if silhouette in MEMBER_SILHOUETTES and not membership.is_member(db, request.app.state.settings, user):
        raise ApiError(403, "member_only", "별지기 멤버십에서 쓸 수 있는 모양이에요.")


def _check_stars(db: Session, user: User, star_ids: list[str], edges: list) -> list[str]:
    ids = list(dict.fromkeys(star_ids))
    found = db.scalars(select(Star.id).where(Star.id.in_(ids), Star.user_id == user.id,
                                             Star.state == "floated")).all()
    if len(found) != len(ids) or len(ids) < MIN_NEBULA_STARS:
        raise ApiError(422, "invalid_stars", f"떠 있는 내 별을 {MIN_NEBULA_STARS}개 이상 골라 주세요.")
    if any(not (0 <= a < len(ids) and 0 <= b < len(ids)) or a == b for a, b in edges):
        raise ApiError(422, "invalid_edges", "별과 별을 다시 이어 주세요.")
    return ids


def _check_guests(db: Session, user: User, share_ids: list[str]) -> list[str]:
    guests = list(dict.fromkeys(share_ids))
    if guests:
        ok = db.scalars(select(StarShare.id).where(StarShare.id.in_(guests), StarShare.user_id != user.id,
                                                   *visible_shares(db, user.id, StarShare))).all()
        if len(ok) != len(guests):
            raise ApiError(422, "invalid_guests", "들일 수 없는 손님별이 있어요.")
    return guests


@router.post("", status_code=201)
def create(body: NebulaIn, request: Request, user: User = Depends(consented_user), db: Session = Depends(get_db)):
    _check_silhouette(db, request, user, body.silhouette)
    ids = _check_stars(db, user, body.star_ids, body.edges)
    guests = _check_guests(db, user, body.guest_share_ids)
    n = Nebula(user_id=user.id, name=body.name.strip(), silhouette=body.silhouette, star_ids=ids,
               edges=[list(e) for e in body.edges], guest_share_ids=guests)
    db.add(n)
    db.commit()
    return {"id": n.id, "name": n.name, "created_at": iso(n.created_at)}


@router.patch("/{nebula_id}")
def edit(nebula_id: str, body: NebulaEdit, request: Request, user: User = Depends(consented_user),
         db: Session = Depends(get_db), cipher: Cipher = Depends(get_cipher)):
    """성운 다시 그리기. Same checks as drawing it. A member silhouette needs the membership only when
    newly chosen: one already kept stays after the membership ends (13.5). A nebula on the plaza is updated there too,
    keeping its 공명 and 별빛 한 줄, unless a star in it carries a crisis signal."""
    n = owned_nebula(db, user, nebula_id)
    given = body.model_fields_set
    if "silhouette" in given and body.silhouette != n.silhouette:
        _check_silhouette(db, request, user, body.silhouette)
        n.silhouette = body.silhouette
    if body.star_ids is not None:
        if body.edges is None:
            raise ApiError(422, "edges_required", "별을 바꾸면 잇기도 함께 보내 주세요.")
        ids = _check_stars(db, user, body.star_ids, body.edges)
        n.star_ids, n.edges = ids, [list(e) for e in body.edges]
    elif body.edges is not None:
        _check_stars(db, user, n.star_ids, body.edges)
        n.edges = [list(e) for e in body.edges]
    if body.name is not None:
        if not body.name.strip():
            raise ApiError(422, "empty_name", "성운의 이름을 지어 주세요.")
        n.name = body.name.strip()
    if body.guest_share_ids is not None:
        # Guests already here that have since left the plaza (taken down, blocked, unshared) are let go
        # quietly, so the app can send the list it holds; only newly invited ones must be visible.
        kept = set(n.guest_share_ids or [])
        wanted = list(dict.fromkeys(body.guest_share_ids))
        visible = set(db.scalars(select(StarShare.id).where(StarShare.id.in_(wanted), StarShare.user_id != user.id,
                                                            *visible_shares(db, user.id, StarShare))))
        if any(g not in visible and g not in kept for g in wanted):
            raise ApiError(422, "invalid_guests", "들일 수 없는 손님별이 있어요.")
        n.guest_share_ids = [g for g in wanted if g in visible]
    n.updated_at = datetime.now(timezone.utc)

    row = db.scalar(select(NebulaShare).where(NebulaShare.nebula_id == n.id))
    plaza_updated = False
    if row is not None:
        stars = _stars(db, n)
        if not any(s.crisis for s in stars):
            _snapshot(row, n, stars, cipher)
            if row.quote and not any(row.quote in privacy.scan(cipher.dec(s.body_enc))["masked"] for s in stars):
                row.quote = None
            plaza_updated = True
    db.commit()
    return detail(n.id, user, db, cipher) | {"plaza_updated": plaza_updated}


@router.get("/guest-candidates")
def guest_candidates(user: User = Depends(consented_user), db: Session = Depends(get_db)):
    """85: plaza stars I left a 공명 on, newest first."""
    rows = db.execute(
        select(StarShare, Resonance.created_at)
        .join(Resonance, (Resonance.kind == "star") & (Resonance.target_id == StarShare.id))
        .where(Resonance.user_id == user.id, *visible_shares(db, user.id, StarShare))
        .order_by(Resonance.created_at.desc())
    ).all()
    return {"items": [{"share_id": s.id, "name": s.name, "mood": s.mood, "resonated_at": iso(at)}
                      for s, at in rows], "max": MAX_GUEST_STARS}


@router.get("")
def list_nebulae(user: User = Depends(consented_user), db: Session = Depends(get_db),
                 cipher: Cipher = Depends(get_cipher)):
    """80 컬렉션 · 성운: 내가 그린 and 곁에 둔."""
    shared = set(db.scalars(select(NebulaShare.nebula_id).where(NebulaShare.user_id == user.id)))
    mine = []
    for n in db.scalars(select(Nebula).where(Nebula.user_id == user.id).order_by(Nebula.created_at.desc())):
        stars = _stars(db, n)
        mine.append({"id": n.id, "name": n.name, "silhouette": n.silhouette, "star_count": len(stars),
                     "depth_level": avg_depth(stars, cipher), "shared": n.id in shared,
                     "created_at": iso(n.created_at), "updated_at": iso(n.updated_at)})
    beside = db.scalars(
        select(NebulaShare).join(Beside, (Beside.kind == "nebula") & (Beside.target_id == NebulaShare.id))
        .where(Beside.user_id == user.id, *visible_shares(db, user.id, NebulaShare))
    ).all()
    return {"mine": mine,
            "beside": [{"share_id": s.id, "name": s.name, "depth_level": s.depth_level} for s in beside]}


@router.get("/{nebula_id}")
def detail(nebula_id: str, user: User = Depends(consented_user), db: Session = Depends(get_db),
           cipher: Cipher = Depends(get_cipher)):
    """70 나의 성운 상세"""
    n = owned_nebula(db, user, nebula_id)
    stars = _stars(db, n)
    moods: dict[str, int] = {}
    for s in stars:
        moods[s.mood] = moods.get(s.mood, 0) + 1
    # "5 · 다시 쓴 주제": rewrite chains among the nebula's stars.
    topics = {s.rewrite_of for s in stars if s.rewrite_of}
    guests = db.scalars(select(StarShare).where(StarShare.id.in_(n.guest_share_ids),
                                                *visible_shares(db, user.id, StarShare))).all()
    return {
        "id": n.id,
        "name": n.name,
        "silhouette": n.silhouette,
        "edges": n.edges,
        # Stars come oldest first; `index` is the place in star_ids, which `edges` point into.
        "stars": [{"id": s.id, "index": n.star_ids.index(s.id), "title": cipher.dec(s.title_enc), "mood": s.mood, "starlight": s.starlight,
                   "shape": cipher.dec_json(s.analysis_enc)["shape"],
                   "depth_level": cipher.dec_json(s.analysis_enc)["depth_level"], "created_at": iso(s.created_at)}
                  for s in stars],
        "star_count": len(stars),
        "rewrite_topics": len(topics),
        "depth_level": avg_depth(stars, cipher),
        "moods": [m for m, _ in sorted(moods.items(), key=lambda kv: -kv[1])],
        "guests": [{"share_id": g.id, "name": g.name, "mood": g.mood} for g in guests],
        "shared": db.scalar(select(NebulaShare.id).where(NebulaShare.nebula_id == n.id)) is not None,
        "created_at": iso(n.created_at),
        "updated_at": iso(n.updated_at),
    }


def _story(n: Nebula, stars: list[Star], cipher: Cipher) -> dict:
    entries = []
    for s in stars:
        a = cipher.dec_json(s.analysis_enc)
        entries.append({"star_id": s.id, "date": iso(s.created_at), "title": cipher.dec(s.title_enc),
                        "sentence": a["impact_quote"]})
    return {"name": n.name, "since": entries[0]["date"] if entries else None, "star_count": len(entries),
            "entries": entries}


@router.get("/{nebula_id}/story")
def story(nebula_id: str, user: User = Depends(consented_user), db: Session = Depends(get_db),
          cipher: Cipher = Depends(get_cipher)):
    """83: each star's key sentence in time order. The sentences are never changed. Free."""
    n = owned_nebula(db, user, nebula_id)
    return _story(n, _stars(db, n), cipher)


@router.put("/{nebula_id}/share")
def share(nebula_id: str, body: ShareIn, user: User = Depends(consented_user), db: Session = Depends(get_db),
          cipher: Cipher = Depends(get_cipher)):
    """71 하늘에 띄우기. Goes out: shape, colours, depth, name. Never: writing, dates, account."""
    n = owned_nebula(db, user, nebula_id)
    stars = _stars(db, n)
    if any(s.crisis for s in stars):
        raise ApiError(422, "crisis", "지금은 나누지 않아도 괜찮아요.")
    quote = None
    if body.quote:
        if not any(body.quote in cipher.dec(s.body_enc) for s in stars):
            raise ApiError(422, "quote_not_found", "성운의 별에 쓴 문장 중에서 골라 주세요.")
        quote = privacy.scan(body.quote)["masked"]
    row = db.scalar(select(NebulaShare).where(NebulaShare.nebula_id == n.id)) or NebulaShare(
        nebula_id=n.id, user_id=user.id)
    _snapshot(row, n, stars, cipher)
    row.receive_lines, row.quote = body.receive_lines, quote
    db.add(row)
    db.commit()
    return {"share_id": row.id, "name": row.name, "quote": row.quote, "receive_lines": row.receive_lines}


@router.delete("/{nebula_id}/share", status_code=204)
def unshare(nebula_id: str, user: User = Depends(consented_user), db: Session = Depends(get_db)):
    n = owned_nebula(db, user, nebula_id)
    row = db.scalar(select(NebulaShare).where(NebulaShare.nebula_id == n.id))
    if row:
        db.delete(row)
        db.commit()
