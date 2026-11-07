"""11 가입 동의, 87 설정, 91 계정 삭제, 92 공유 거두기, 93 내보내기, 32 문의하기."""

from datetime import datetime, timezone
from typing import Literal

from fastapi import APIRouter, Depends, Response
from pydantic import BaseModel, Field
from sqlalchemy import delete, func, select
from sqlalchemy.orm import Session

from ..blocks import hidden_users
from ..deps import current_user, get_cipher, get_db
from ..export import StarEntry, as_pdf, as_text
from ..models import DeviceToken, Inquiry, Nebula, NebulaShare, Resonance, Star, StarlightLine, StarShare, User
from ..rules import INQUIRY_KINDS, MOOD_LABELS, SKY_THEMES, SOUNDS
from ..security import Cipher
from ..views import iso, local
from ..ratelimit import per_user

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


class DeviceIn(BaseModel):
    token: str = Field(..., pattern=r"^[0-9a-fA-F]{64,200}$", description="APNs device token, hex")
    environment: Literal["production", "sandbox"] = Field(
        ..., description="sandbox for Xcode debug builds, production for TestFlight and the App Store")


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


@router.put("/me/devices", status_code=204)
def register_device(body: DeviceIn, user: User = Depends(current_user), db: Session = Depends(get_db)):
    """After the user allows notifications: remember where to reach them. Call it again whenever iOS hands
    the app a token (it can change). A device moves to whoever signed in on it last."""
    token = body.token.lower()
    row = db.get(DeviceToken, token) or DeviceToken(token=token)
    row.user_id, row.environment = user.id, body.environment
    db.add(row)
    db.commit()


@router.delete("/me/devices/{token}", status_code=204)
def unregister_device(token: str, user: User = Depends(current_user), db: Session = Depends(get_db)):
    """Before signing out, or when the user turns notifications off in iOS settings."""
    db.execute(delete(DeviceToken).where(DeviceToken.token == token.lower(), DeviceToken.user_id == user.id))
    db.commit()


@router.get("/me/shares")
def my_shares(user: User = Depends(current_user), db: Session = Depends(get_db),
              cipher: Cipher = Depends(get_cipher)):
    """What I gave to the plaza, newest first, with the 공명 only I can see.
    Settings › 나눈 별 (Figma 17/18): my own list, so the star's title, time and starlight are shown."""
    def resonances(kind, target_id):
        return db.scalar(select(func.count()).select_from(Resonance)
                         .where(Resonance.kind == kind, Resonance.target_id == target_id))

    stars = db.execute(select(StarShare, Star).join(Star, Star.id == StarShare.star_id)
                       .where(StarShare.user_id == user.id).order_by(StarShare.created_at.desc())).all()
    nebulae = db.scalars(select(NebulaShare).where(NebulaShare.user_id == user.id)
                         .order_by(NebulaShare.created_at.desc())).all()
    hidden = hidden_users(db, user.id)
    return {
        "stars": [{"id": sh.id, "star_id": sh.star_id, "name": sh.name, "title": cipher.dec(st.title_enc),
                   "written_at": iso(st.created_at), "starlight": st.starlight, "created_at": iso(sh.created_at),
                   "resonances": resonances("star", sh.id), "hidden": sh.hidden} for sh, st in stars],
        "nebulae": [{"id": n.id, "nebula_id": n.nebula_id, "name": n.name, "created_at": iso(n.created_at),
                     "resonances": resonances("nebula", n.id), "hidden": n.hidden,
                     "lines": db.scalar(select(func.count()).select_from(StarlightLine)
                                        .where(StarlightLine.share_id == n.id,
                                               StarlightLine.user_id.not_in(hidden)))} for n in nebulae],
    }


@router.delete("/me/shares")
def withdraw_all(user: User = Depends(current_user), db: Session = Depends(get_db)):
    """92 모든 공유 거두기. Resonances already given stay counted (the app says they are kept)."""
    stars = db.execute(delete(StarShare).where(StarShare.user_id == user.id)).rowcount
    nebulae = db.execute(delete(NebulaShare).where(NebulaShare.user_id == user.id)).rowcount
    db.commit()
    return {"withdrawn_stars": stars, "withdrawn_nebulae": nebulae}


@router.get("/me/export")
def export(format: Literal["text", "pdf"] = "text", user: User = Depends(current_user),
           db: Session = Depends(get_db), cipher: Cipher = Depends(get_cipher)):
    """93 텍스트 파일로 · PDF로: every star and nebula. The file stays on the device."""
    rows = db.scalars(select(Star).where(Star.user_id == user.id).order_by(Star.created_at)).all()
    stars = []
    for s in rows:
        when = local(s.created_at).strftime("%Y년 %-m월 %-d일 %H:%M")
        state = f"별빛 {s.starlight}" if s.starlight is not None else "간직한 별"
        stars.append(StarEntry(cipher.dec(s.title_enc), f"{when} · {MOOD_LABELS[s.mood]} · {state}",
                               cipher.dec(s.body_enc)))
    titles = {s.id: cipher.dec(s.title_enc) for s in rows}
    nebulae = [f"- {n.name}: " + ", ".join(titles[i] for i in n.star_ids if i in titles)
               for n in db.scalars(select(Nebula).where(Nebula.user_id == user.id).order_by(Nebula.created_at))]
    if format == "pdf":
        return Response(as_pdf(stars, nebulae), media_type="application/pdf",
                        headers={"Content-Disposition": 'attachment; filename="youniya-export.pdf"'})
    return Response(as_text(stars, nebulae), media_type="text/plain; charset=utf-8",
                    headers={"Content-Disposition": 'attachment; filename="youniya-export.txt"'})


@router.post("/inquiries", status_code=201, dependencies=[per_user("inquiry", 5, 3600)])
def inquire(body: InquiryIn, user: User = Depends(current_user), db: Session = Depends(get_db),
            cipher: Cipher = Depends(get_cipher)):
    row = Inquiry(user_id=user.id, kind=body.kind, email=body.email, body_enc=cipher.enc(body.body))
    db.add(row)
    db.commit()
    return {"id": row.id}
