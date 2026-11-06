"""11 가입 동의, 87 설정, 91 계정 삭제, 92 공유 거두기, 93 내보내기, 32 문의하기."""

from datetime import datetime, timezone
from typing import Literal

from fastapi import APIRouter, Depends, Response
from pydantic import BaseModel, Field
from sqlalchemy import delete, func, select
from sqlalchemy.orm import Session

from ..deps import current_user, get_cipher, get_db
from ..models import Inquiry, Nebula, NebulaShare, Resonance, Star, StarlightLine, StarShare, User
from ..rules import INQUIRY_KINDS, MOOD_LABELS, SKY_THEMES, SOUNDS
from ..security import Cipher
from ..views import iso, local

router = APIRouter(prefix="/v1", tags=["account"])


Sound = Literal[SOUNDS]  # type: ignore[valid-type]
Sky = Literal[SKY_THEMES]  # type: ignore[valid-type]


class AppSettings(BaseModel):
    """iOS AppSettings. Defaults match the app."""

    reduce_animations: bool = False
    haptics: bool = True
    ambience: bool = True
    sound: Sound = SOUNDS[0]
    star_reminder: bool = False
    sky: Sky = SKY_THEMES[0]


class SettingsPatch(BaseModel):
    reduce_animations: bool | None = None
    haptics: bool | None = None
    ambience: bool | None = None
    sound: Sound | None = None
    star_reminder: bool | None = None
    sky: Sky | None = None


class Consent(BaseModel):
    terms: Literal[True]
    privacy: Literal[True]
    sensitive: Literal[True]
    marketing: bool = False


class InquiryIn(BaseModel):
    kind: Literal[INQUIRY_KINDS]  # type: ignore[valid-type]
    email: str = Field(..., pattern=r"^[^@\s]+@[^@\s]+\.[^@\s]+$", max_length=255)
    body: str = Field(..., min_length=1, max_length=5000)


def settings_of(user: User) -> AppSettings:
    return AppSettings(**(user.settings or {}))


@router.get("/me")
def me(user: User = Depends(current_user)):
    return {
        "id": user.id,
        "provider": user.provider,
        "needs_consent": user.consented_at is None,
        "marketing_opt_in": user.marketing_opt_in,
        "coins": user.coins,
        "free_telescope_available": not user.free_telescope_used,
        "settings": settings_of(user).model_dump(),
    }


@router.post("/me/consent")
def consent(body: Consent, user: User = Depends(current_user), db: Session = Depends(get_db)):
    user.consented_at = user.consented_at or datetime.now(timezone.utc)
    user.marketing_opt_in = body.marketing
    db.add(user)
    db.commit()
    return {"needs_consent": False, "marketing_opt_in": user.marketing_opt_in}


@router.patch("/me/settings")
def update_settings(body: SettingsPatch, user: User = Depends(current_user), db: Session = Depends(get_db)):
    merged = settings_of(user).model_dump() | body.model_dump(exclude_none=True)
    user.settings = AppSettings(**merged).model_dump()
    db.add(user)
    db.commit()
    return user.settings


@router.delete("/me", status_code=204)
def delete_account(user: User = Depends(current_user), db: Session = Depends(get_db)):
    """91: stars, nebulae, the milky way and the account go, with no way back.
    Everything hangs off users.id with ON DELETE CASCADE."""
    db.delete(user)
    db.commit()


@router.get("/me/shares")
def my_shares(user: User = Depends(current_user), db: Session = Depends(get_db)):
    """What I gave to the plaza, with the 공명 only I can see."""
    def resonances(kind, target_id):
        return db.scalar(select(func.count()).select_from(Resonance)
                         .where(Resonance.kind == kind, Resonance.target_id == target_id))

    stars = db.scalars(select(StarShare).where(StarShare.user_id == user.id)).all()
    nebulae = db.scalars(select(NebulaShare).where(NebulaShare.user_id == user.id)).all()
    return {
        "stars": [{"id": s.id, "star_id": s.star_id, "name": s.name, "created_at": iso(s.created_at),
                   "resonances": resonances("star", s.id)} for s in stars],
        "nebulae": [{"id": n.id, "nebula_id": n.nebula_id, "name": n.name, "created_at": iso(n.created_at),
                     "resonances": resonances("nebula", n.id),
                     "lines": db.scalar(select(func.count()).select_from(StarlightLine)
                                        .where(StarlightLine.share_id == n.id))} for n in nebulae],
    }


@router.delete("/me/shares")
def withdraw_all(user: User = Depends(current_user), db: Session = Depends(get_db)):
    """92 모든 공유 거두기. Resonances already given stay counted (the app says they are kept)."""
    stars = db.execute(delete(StarShare).where(StarShare.user_id == user.id)).rowcount
    nebulae = db.execute(delete(NebulaShare).where(NebulaShare.user_id == user.id)).rowcount
    db.commit()
    return {"withdrawn_stars": stars, "withdrawn_nebulae": nebulae}


@router.get("/me/export")
def export(user: User = Depends(current_user), db: Session = Depends(get_db),
           cipher: Cipher = Depends(get_cipher)):
    """93 텍스트 파일로: every star and nebula, as plain text. The file stays on the device."""
    lines = ["YOUNIYA 기록 내보내기", ""]
    stars = db.scalars(select(Star).where(Star.user_id == user.id).order_by(Star.created_at)).all()
    for s in stars:
        when = local(s.created_at).strftime("%Y년 %-m월 %-d일 %H:%M")
        state = f"별빛 {s.starlight}" if s.starlight is not None else "간직한 별"
        lines += [f"■ {cipher.dec(s.title_enc)}", f"{when} · {MOOD_LABELS[s.mood]} · {state}", "",
                  cipher.dec(s.body_enc), ""]
    nebulae = db.scalars(select(Nebula).where(Nebula.user_id == user.id).order_by(Nebula.created_at)).all()
    if nebulae:
        lines += ["", "성운", ""]
        titles = {s.id: cipher.dec(s.title_enc) for s in stars}
        for n in nebulae:
            lines.append(f"✦ {n.name}: " + ", ".join(titles.get(i, "") for i in n.star_ids if i in titles))
    return Response("\n".join(lines), media_type="text/plain; charset=utf-8",
                    headers={"Content-Disposition": 'attachment; filename="youniya-export.txt"'})


@router.post("/inquiries", status_code=201)
def inquire(body: InquiryIn, user: User = Depends(current_user), db: Session = Depends(get_db),
            cipher: Cipher = Depends(get_cipher)):
    row = Inquiry(user_id=user.id, kind=body.kind, email=body.email, body_enc=cipher.enc(body.body))
    db.add(row)
    db.commit()
    return {"id": row.id}
