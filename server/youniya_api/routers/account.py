"""11 가입 동의, 87 설정, 91 계정 삭제, 92 공유 거두기, 93 내보내기, 32 문의하기."""

from datetime import datetime, timezone
from typing import Literal

from fastapi import APIRouter, Depends, Query, Request, Response
from pydantic import BaseModel, Field
from sqlalchemy import delete, func, select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from .. import allowance, marketing, membership, nickname
from ..blocks import hidden_users
from ..deps import ApiError, current_user, get_cipher, get_db
from ..export import StarEntry, as_pdf, as_text
from ..prism.engine import split_sentences
from .constellations import TEMPLATES
from ..models import Notice, StarLine, UserNotification, StarLink, TelescopeReport, CoinEntry, DeviceToken, Inquiry, Nebula, NebulaShare, Resonance, Star, StarlightLine, StarShare, User
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


def settings_of(user: User, member: bool = False) -> AppSettings:
    """A member sky saved by someone who is no longer a member shows as violet (기획서 13장)."""
    out = AppSettings(**(user.settings or {}))
    if not membership.sky_allowed(out.sky, member):
        out.sky = "violet"
    return out


@router.get("/me")
def me(request: Request, user: User = Depends(current_user), db: Session = Depends(get_db)):
    """`free_star_today` (0/1), `free_telescope` (this month's and the sign-up one left).
    With MEMBERSHIP=1, `membership` too (see GET /v1/membership); a member's counts include its own."""
    settings = request.app.state.settings
    member = membership.is_member(db, settings, user)
    return {
        "id": user.id,
        "provider": user.provider,
        "joined_at": iso(user.created_at),  # 87-6 가입한 날
        "needs_consent": user.consented_at is None,
        "marketing_opt_in": user.marketing_opt_in,
        "marketing": marketing.view(user),  # 14.3: {opt_in, consented_at, revoked_at, reconfirm_due}
        "nickname": user.nickname,  # 별지기 이름 (15장); null until chosen
        "nickname_next_change": iso(nickname.next_change(user)),
        # 18.3: an operator asked for another 별지기 이름; it can change now, whatever the 30 days.
        "nickname_rename_required": user.nickname_rename_requested_at is not None,
        "plaza_restricted_until": iso(user.plaza_restricted_until),
        "coins": user.coins,
        "free_telescope_available": allowance.telescopes_left(user) > 0,
        **membership.free_summary(db, settings, user),
        "settings": settings_of(user, member).model_dump(),
    } | ({"membership": membership.view(db, settings, user)} if settings.membership else {})


class NicknameIn(BaseModel):
    name: str = Field(..., min_length=1, max_length=40)


@router.get("/me/nickname/check")
def check_nickname(name: str = Query(..., max_length=40), user: User = Depends(current_user),
                   db: Session = Depends(get_db)):
    """15장 별지기 이름: {available, reason (form | hurtful | reserved | taken), message}."""
    why = nickname.problem(db, name, user)
    return {"available": why is None, "reason": why, "message": nickname.MESSAGES.get(why)}


@router.put("/me/nickname", dependencies=[per_user("nickname", 20, 3600)])
def set_nickname(body: NicknameIn, user: User = Depends(current_user), db: Session = Depends(get_db)):
    """The first name any time; after that once in 30 days (429 nickname_too_soon, with `next_change`)."""
    name = body.name.strip()
    if user.nickname == name:
        return {"nickname": name, "next_change": iso(nickname.next_change(user))}
    if (at := nickname.next_change(user)) is not None:
        raise ApiError(429, "nickname_too_soon", "별지기 이름은 30일에 한 번 바꿀 수 있어요.", next_change=iso(at))
    if (why := nickname.problem(db, name, user)) is not None:
        raise ApiError(409 if why == "taken" else 422, f"nickname_{why}", nickname.MESSAGES[why])
    user.nickname, user.nickname_key = name, nickname.key(name)
    user.nickname_changed_at, user.nickname_rename_requested_at = datetime.now(timezone.utc), None
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise ApiError(409, "nickname_taken", nickname.MESSAGES["taken"])
    return {"nickname": name, "next_change": iso(nickname.next_change(user))}


@router.post("/me/consent")
def consent(body: Consent, request: Request, user: User = Depends(current_user), db: Session = Depends(get_db)):
    user.consented_at = user.consented_at or datetime.now(timezone.utc)
    marketing.set_consent(db, request.app.state.push, user, body.marketing)
    db.add(user)
    db.commit()
    return {"needs_consent": False, "marketing_opt_in": user.marketing_opt_in}


class MarketingIn(BaseModel):
    opt_in: bool


@router.put("/me/marketing", dependencies=[per_user("marketing", 20, 3600)])
def set_marketing(body: MarketingIn, request: Request, user: User = Depends(current_user),
                  db: Session = Depends(get_db)):
    """14.3 새 기능·혜택 알림 수신 동의, apart from the other consents. The result comes as an app notice."""
    changed = marketing.set_consent(db, request.app.state.push, user, body.opt_in)
    db.commit()
    return marketing.view(user) | {"changed": changed}


@router.patch("/me/settings")
def update_settings(body: SettingsPatch, request: Request, user: User = Depends(current_user),
                    db: Session = Depends(get_db)):
    """우주의 색: violet and ocean for everyone, the rest for 별지기 멤버십 (403 member_only)."""
    member = membership.is_member(db, request.app.state.settings, user)
    if body.sky and not membership.sky_allowed(body.sky, member):
        raise ApiError(403, "member_only", "별지기 멤버십에서 쓸 수 있는 우주의 색이에요.")
    merged = settings_of(user, member).model_dump() | body.model_dump(exclude_none=True)
    user.settings = AppSettings(**merged).model_dump()
    db.add(user)
    db.commit()
    return user.settings


@router.delete("/me", status_code=204)
def delete_account(user: User = Depends(current_user), db: Session = Depends(get_db)):
    """91: stars, nebulae, the milky way and the account go, with no way back.
    Everything hangs off users.id with ON DELETE CASCADE, except the store purchase and refund
    records: they stay, cut off from the account, for 5 years (전자상거래법; 개인정보 처리방침 3)."""
    db.execute(update(CoinEntry).where(CoinEntry.user_id == user.id, CoinEntry.transaction_id.is_not(None))
               .values(user_id=None))
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
                   "resonances": resonances("star", sh.id), "hidden": sh.hidden,
                   # Off the plaza until another 대표 문장 is picked (PUT /v1/stars/{id}/share).
                   "quote_missing": sh.quote is None, "receive_lines": sh.receive_lines,
                   "lines": db.scalar(select(func.count()).select_from(StarLine).where(
                       StarLine.star_id == sh.star_id, StarLine.hidden.is_(False),
                       StarLine.user_id.not_in(hidden)))} for sh, st in stars],
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
    """93 텍스트 파일로 · PDF로: every star with its 별빛 풀이, 망원경 결과 and linked stars, then each month's
    별자리 이야기 and the nebulae. The file stays on the device."""
    rows = db.scalars(select(Star).where(Star.user_id == user.id).order_by(Star.created_at)).all()
    titles = {s.id: cipher.dec(s.title_enc) for s in rows}
    links: dict[str, list[str]] = {}
    for a, b in db.execute(select(StarLink.star_a, StarLink.star_b).where(StarLink.user_id == user.id)):
        links.setdefault(a, []).append(b)
        links.setdefault(b, []).append(a)
    scopes: dict[str, dict] = {}
    for r in db.scalars(select(TelescopeReport).where(TelescopeReport.user_id == user.id)
                        .order_by(TelescopeReport.created_at)):
        if len(r.star_ids) == 1:
            scopes[r.star_ids[0]] = cipher.dec_json(r.report_enc)  # the latest wins
    stars, stories = [], {}
    for s in rows:
        t = local(s.created_at)
        state = f"별빛 {s.starlight}" if s.starlight is not None else "별빛 없는 별"
        moods = " · ".join(MOOD_LABELS[m] for m in (s.moods or [s.mood]))
        a = cipher.dec_json(s.analysis_enc) if s.state == "floated" and s.analysis_enc else None
        extra = []
        if a:
            for key, label in (("depth_reason", "별의 깊이"), ("clarity_reason", "빛의 선명함"),
                               ("weight_reason", "마음의 무게"), ("interpretation", "별빛 풀이")):
                if a.get(key):
                    extra.append(f"{label}: {a[key]}")
        if (scope := scopes.get(s.id)) is not None:
            extra.append(f"마음 망원경: {scope['star_name']} · {scope.get('mood_interpretation') or scope['question']}")
            extra += [f"  {f['label']}: {f['sentence']}" for f in scope.get("fog_items") or []]
        if s.id in links:
            extra.append("이어진 별: " + ", ".join(titles[i] for i in links[s.id] if i in titles))
        stars.append(StarEntry(cipher.dec(s.title_enc), f"{t.year}년 {t.month}월 {t.day}일 {t:%H:%M} · {moods} · {state}",
                               cipher.dec(s.body_enc), extra))
        body = cipher.dec(s.body_enc)
        sentence = a["impact_quote"] if a else (split_sentences(body) or [body.strip()])[0]
        stories.setdefault(t.strftime("%Y-%m"), []).append(f"  {t.day}일 · {sentence}")
    constellations = []
    for month, entries in stories.items():
        constellations += [f"{month[:4]}년 {int(month[5:])}월 · {TEMPLATES[int(month[5:])]['name']}"] + entries
    nebulae = [f"- {n.name}: " + ", ".join(titles[i] for i in n.star_ids if i in titles)
               for n in db.scalars(select(Nebula).where(Nebula.user_id == user.id).order_by(Nebula.created_at))]
    sections = [("별자리 이야기", constellations), ("성운", nebulae)]
    if format == "pdf":
        return Response(as_pdf(stars, sections), media_type="application/pdf",
                        headers={"Content-Disposition": 'attachment; filename="youniya-export.pdf"'})
    return Response(as_text(stars, sections), media_type="text/plain; charset=utf-8",
                    headers={"Content-Disposition": 'attachment; filename="youniya-export.txt"'})


@router.post("/inquiries", status_code=201, dependencies=[per_user("inquiry", 5, 3600)])
def inquire(body: InquiryIn, request: Request, user: User = Depends(current_user), db: Session = Depends(get_db),
            cipher: Cipher = Depends(get_cipher)):
    h = request.headers
    app = {"platform": h.get("x-app-platform"), "version": h.get("x-app-version"), "device": h.get("x-device-model")}
    row = Inquiry(user_id=user.id, kind=body.kind, email=body.email, body_enc=cipher.enc(body.body),
                  app_info=app if any(app.values()) else None)
    db.add(row)
    db.commit()
    return {"id": row.id}


@router.get("/notices")
def app_notices(user: User = Depends(current_user), db: Session = Depends(get_db)):
    """관리자 A-12 공지, newest first, once their time has come."""
    now = datetime.now(timezone.utc)
    rows = db.scalars(select(Notice).where(Notice.publish_at <= now).order_by(Notice.publish_at.desc()).limit(30))
    return {"items": [{"id": n.id, "title": n.title, "body": n.body, "published_at": iso(n.publish_at)} for n in rows]}


class NotificationsRead(BaseModel):
    ids: list[str] = Field(default_factory=list, max_length=500)
    all: bool = False


@router.get("/me/notifications")
def notifications(before: datetime | None = None, limit: int = Query(50, ge=1, le=200),
                  user: User = Depends(current_user), db: Session = Depends(get_db)):
    """알림함 (Mobile 130, web): what the server sent this keeper, newest first, kept 90 days.
    `target` says what a tap opens ({"screen": "star" | "nickname" | "plaza_restricted" | "plaza" |
    "coin_history" | "notice" | "notification_settings" | "notifications", …})."""
    stmt = select(UserNotification).where(UserNotification.user_id == user.id)
    if before:
        stmt = stmt.where(UserNotification.created_at < before)
    rows = db.scalars(stmt.order_by(UserNotification.created_at.desc()).limit(limit)).all()
    unread = db.scalar(select(func.count()).select_from(UserNotification)
                       .where(UserNotification.user_id == user.id, UserNotification.read_at.is_(None)))
    return {"items": [{"id": n.id, "kind": n.kind, "title": n.title, "body": n.body, "target": n.target,
                       "created_at": iso(n.created_at), "read": n.read_at is not None} for n in rows],
            "unread": unread, "next_before": iso(rows[-1].created_at) if len(rows) == limit else None}


@router.post("/me/notifications/read")
def read_notifications(body: NotificationsRead, user: User = Depends(current_user), db: Session = Depends(get_db)):
    stmt = update(UserNotification).where(UserNotification.user_id == user.id, UserNotification.read_at.is_(None))
    if not body.all:
        stmt = stmt.where(UserNotification.id.in_(body.ids))
    db.execute(stmt.values(read_at=datetime.now(timezone.utc)))
    db.commit()
    return {"unread": db.scalar(select(func.count()).select_from(UserNotification)
                                .where(UserNotification.user_id == user.id, UserNotification.read_at.is_(None)))}
