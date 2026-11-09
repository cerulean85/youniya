"""관리자 콘솔 owner 화면 (기획서 18장): A-02 대시보드, A-08 코인·결제, A-09 AI 사용량·원가,
A-10 별빛 측정 방식, A-11 초대 계정, A-12 공지·점검. Owners only; every change needs a reason and
goes to the audit log. No writing, starlight numbers or telescope results appear here."""

from datetime import datetime, timedelta, timezone
from typing import Literal

from fastapi import APIRouter, Depends, Query, Request
from pydantic import BaseModel, Field
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from .. import invites, runtime
from .. import operators as ops
from ..deps import ApiError, get_db
from ..models import (AdminAudit, AdminLog, AiCost, AiUsage, CoinEntry, DeviceToken, Inquiry, InviteAccount, Notice,
                      Operator, PrismTest, ShareReport, Star, StarLineReport, User)
from ..push import Message, notify
from ..rules import AI_COST_ALERT_KRW, COIN_PACKAGES, PRISM_VERSION
from ..views import KST, iso
from .admin_auth import owner

router = APIRouter(prefix="/v1/admin", tags=["admin"], dependencies=[Depends(owner)])


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _month(month: str | None) -> tuple[str, datetime, datetime]:
    """'YYYY-MM' (Korean time) and its start and end in UTC."""
    m = month or datetime.now(KST).strftime("%Y-%m")
    start = datetime(int(m[:4]), int(m[5:]), 1, tzinfo=KST)
    end = (start.replace(day=28) + timedelta(days=5)).replace(day=1)
    return m, start.astimezone(timezone.utc), end.astimezone(timezone.utc)


def _actor(op: Operator) -> Operator | None:
    return op if op.id else None


# --- A-02 대시보드 --------------------------------------------------------------------------------

@router.get("/dashboard")
def dashboard(range: Literal["today", "week", "month"] = "today", db: Session = Depends(get_db)):
    now_kst = datetime.now(KST)
    start = now_kst.replace(hour=0, minute=0, second=0, microsecond=0)
    if range == "week":
        start -= timedelta(days=6)
    elif range == "month":
        start = start.replace(day=1)
    since = start.astimezone(timezone.utc)
    stars = select(func.count()).select_from(Star).where(Star.created_at >= since)
    lit = db.scalar(stars.where(Star.state == "floated"))
    total = db.scalar(stars)
    month, mstart, _ = _month(None)
    pending_reports = (db.scalar(select(func.count()).select_from(ShareReport).where(ShareReport.notified_at.is_(None)))
                       + db.scalar(select(func.count()).select_from(StarLineReport)
                                   .where(StarLineReport.notified_at.is_(None))))
    alerts = db.scalars(select(AdminLog).where(AdminLog.action.in_(("ai_cost_over", "urgent_report_star",
                                                                    "urgent_report_nebula")))
                        .order_by(AdminLog.created_at.desc()).limit(10)).all()
    paid = db.scalars(select(CoinEntry).where(CoinEntry.transaction_id.is_not(None), CoinEntry.delta > 0,
                                              CoinEntry.created_at >= since)).all()
    return {
        "range": range, "since": iso(since),
        "stars": {"lit": lit, "unlit": total - lit, "total": total},
        "new_keepers": db.scalar(select(func.count()).select_from(User).where(User.created_at >= since)),
        "reports_pending": pending_reports,
        "inquiries_new": db.scalar(select(func.count()).select_from(Inquiry).where(Inquiry.status == "new")),
        "ai_cost_month_krw": round(db.scalar(select(func.coalesce(func.sum(AiCost.krw), 0.0))
                                             .where(AiCost.month == month)), 1),
        # Only how many; never what was written (18.1).
        "crisis_stars": db.scalar(select(func.count()).select_from(Star).where(Star.crisis.is_(True),
                                                                               Star.created_at >= since)),
        "alerts": [{"kind": a.action, "target_id": a.target_id, "at": iso(a.created_at)} for a in alerts],
        "payments": {"count": len(paid), "coins": sum(p.delta for p in paid),
                     "krw_estimate": sum(_price(p.delta) for p in paid)},
    }


# --- A-08 코인·결제 -------------------------------------------------------------------------------

_BY_COINS = {p["coins"] + p.get("bonus", 0): p["price"] for p in COIN_PACKAGES.values()} | {
    p["coins"]: p["price"] for p in COIN_PACKAGES.values()}


def _price(coins: int) -> int:
    """The package price a purchase of this many coins came from; 0 when none matches."""
    return _BY_COINS.get(coins, 0)


def _kind(e: CoinEntry) -> str:
    if e.transaction_id and e.delta > 0:
        return "purchase"
    if e.transaction_id and e.delta < 0:
        return "refund"
    if e.title == "운영자 지급":
        return "grant"
    return "spend" if e.delta < 0 else "other"


@router.get("/coins")
def coins_ledger(month: str | None = Query(None, pattern=r"^\d{4}-\d{2}$"), limit: int = Query(500, ge=1, le=5000),
                 db: Session = Depends(get_db)):
    """One ledger: App Store purchases and refunds, operator grants, coins spent. (Web payments with Toss come
    when they exist.) `krw_estimate` is the package price for a purchase."""
    m, start, end = _month(month)
    rows = db.scalars(select(CoinEntry).where(CoinEntry.created_at >= start, CoinEntry.created_at < end)
                      .order_by(CoinEntry.created_at.desc())).all()
    nos = {u.id: u.keeper_no for u in db.scalars(select(User).where(User.id.in_({r.user_id for r in rows if r.user_id})))}
    totals: dict[str, dict] = {}
    for r in rows:
        t = totals.setdefault(_kind(r), {"count": 0, "coins": 0, "krw_estimate": 0})
        t["count"] += 1
        t["coins"] += r.delta
        t["krw_estimate"] += _price(r.delta) if _kind(r) == "purchase" else 0
    return {"month": m, "totals": totals,
            "items": [{"id": r.id, "at": iso(r.created_at), "kind": _kind(r), "source": "app_store" if r.transaction_id
                       else "server", "keeper_no": nos.get(r.user_id), "title": r.title, "coins": r.delta,
                       "transaction_id": r.transaction_id,
                       "krw_estimate": _price(r.delta) if _kind(r) == "purchase" else None} for r in rows[:limit]]}


# --- A-09 AI 사용량·원가 --------------------------------------------------------------------------

@router.get("/ai")
def ai_usage(month: str | None = Query(None, pattern=r"^\d{4}-\d{2}$"), db: Session = Depends(get_db)):
    m, _, _ = _month(month)
    features = []
    for u in db.scalars(select(AiUsage).where(AiUsage.month == m).order_by(AiUsage.krw.desc())):
        features.append({
            "feature": u.feature, "requests": u.requests, "calls": u.calls, "krw": round(u.krw, 1),
            "krw_per_request": round(u.krw / u.requests, 2) if u.requests else None,
            "avg_input_tokens": round(u.input_tokens / u.calls) if u.calls else None,
            "avg_output_tokens": round(u.output_tokens / u.calls) if u.calls else None,
            "cache_hit_rate": round(u.cached_tokens / u.input_tokens, 3) if u.input_tokens else None,
            "attempts": u.attempts, "failures": u.failures,
            "failure_rate": round(u.failures / u.attempts, 3) if u.attempts else None})
    over = db.scalars(select(AiCost).where(AiCost.month == m, AiCost.krw > AI_COST_ALERT_KRW)
                      .order_by(AiCost.krw.desc())).all()
    nos = {u.id: (u.keeper_no, u.nickname) for u in db.scalars(select(User).where(User.id.in_({o.user_id for o in over})))}
    total = db.scalar(select(func.coalesce(func.sum(AiCost.krw), 0.0)).where(AiCost.month == m))
    return {"month": m, "total_krw": round(total, 1), "features": features, "alert_krw": AI_COST_ALERT_KRW,
            "over_alert": [{"user_id": o.user_id, "keeper_no": nos.get(o.user_id, (None, None))[0],
                            "nickname": nos.get(o.user_id, (None, None))[1], "krw": round(o.krw, 1),
                            "calls": o.calls} for o in over]}


# --- A-10 별빛 측정 방식 --------------------------------------------------------------------------

@router.get("/prism")
def prism_versions(db: Session = Depends(get_db)):
    """The versions stars were read with, and the recorded comparison tests (tools/compare_prism.py --record).
    A test calls the model about 120 times and runs past the server's time limit, so it is run from the
    operator's machine; a new version ships with the code (rules.PRISM_VERSION), not from here."""
    rows = db.execute(select(Star.prism_version, func.count(), func.min(Star.floated_at), func.max(Star.floated_at))
                      .where(Star.state == "floated").group_by(Star.prism_version)).all()
    tests = db.scalars(select(PrismTest).order_by(PrismTest.run_at.desc()).limit(50)).all()
    return {"current": PRISM_VERSION,
            "versions": [{"key": v or "before-prism-v1", "stars": n, "first_at": iso(a), "last_at": iso(b),
                          "status": "current" if v == PRISM_VERSION else "retired"} for v, n, a, b in rows],
            "tests": [{"id": t.id, "version": t.version, "baseline": t.baseline, "passed": t.passed,
                       "writings": t.writings, "mean_shift": t.mean_shift, "flips": t.flips,
                       "correlation": t.correlation, "cost_krw": t.cost_krw, "run_at": iso(t.run_at)} for t in tests],
            "limits": {"mean_shift": 30, "flips": 3}}


@router.post("/prism/{key}/test", status_code=409)
@router.post("/prism/{key}/deploy", status_code=409)
def prism_manual(key: str):
    raise ApiError(409, "manual_only", "측정 방식 시험과 배포는 서버 코드로 해요. 결과는 이 화면에 기록돼요.")


# --- A-11 초대 계정 -------------------------------------------------------------------------------

class InviteSettingsIn(BaseModel):
    enabled: bool
    reason: str = Field(..., min_length=1, max_length=500)


class InviteIn(BaseModel):
    login_id: str = Field(..., min_length=3, max_length=40, pattern=r"^[A-Za-z0-9._-]+$")
    memo: str | None = Field(None, max_length=200)
    reason: str = Field(..., min_length=1, max_length=500)


class InvitePatch(BaseModel):
    enabled: bool | None = None
    reset_password: bool = False
    reason: str = Field(..., min_length=1, max_length=500)


def _invite_view(db: Session, r: InviteAccount) -> dict:
    u = db.get(User, r.user_id)
    return {"id": r.login, "login_id": r.login, "memo": r.memo, "enabled": not r.disabled,
            "created_at": iso(r.created_at), "last_seen_at": iso(u.last_seen_at) if u else None,
            "keeper_no": u.keeper_no if u else None,
            "stars": db.scalar(select(func.count()).select_from(Star).where(Star.user_id == r.user_id))}


@router.get("/invites")
def list_invites(request: Request, db: Session = Depends(get_db)):
    return {"enabled": runtime.invite_login(request.app),
            "items": [_invite_view(db, r) for r in db.scalars(select(InviteAccount).order_by(InviteAccount.created_at))]}


@router.put("/invites/settings")
def invite_settings(body: InviteSettingsIn, request: Request, op: Operator = Depends(owner),
                    db: Session = Depends(get_db)):
    runtime.put(db, "invite_login", body.enabled, op.email)
    ops.audit(db, _actor(op), "invite_login_" + ("on" if body.enabled else "off"), reason=body.reason)
    db.commit()
    runtime.forget(request.app)
    return {"enabled": runtime.invite_login(request.app)}


@router.post("/invites", status_code=201)
def create_invite(body: InviteIn, op: Operator = Depends(owner), db: Session = Depends(get_db)):
    """The password is shown once."""
    try:
        _, password = invites.create(db, body.login_id)
    except ValueError:
        raise ApiError(409, "invite_exists", "이미 있는 아이디예요.")
    row = db.get(InviteAccount, body.login_id.strip().lower())
    row.memo = body.memo
    ops.audit(db, _actor(op), "invite_create", target=f"invite:{row.login}", reason=body.reason)
    db.commit()
    return _invite_view(db, row) | {"password": password}


@router.patch("/invites/{login_id}")
def change_invite(login_id: str, body: InvitePatch, op: Operator = Depends(owner), db: Session = Depends(get_db)):
    row = db.get(InviteAccount, login_id.strip().lower())
    if row is None:
        raise ApiError(404, "not_found", "초대 계정을 찾지 못했어요.")
    out = {}
    if body.enabled is not None:
        row.disabled = not body.enabled
    if body.reset_password:
        out["password"] = invites.reset(db, row.login)
    ops.audit(db, _actor(op), "invite_change", target=f"invite:{row.login}", reason=body.reason,
              enabled=body.enabled, reset_password=body.reset_password)
    db.commit()
    return _invite_view(db, row) | out


@router.post("/invites/{login_id}/reseed", status_code=409)
def reseed(login_id: str):
    """Seeding builds a whole sky and plaza through the API (tools/seed_review.py --reset) and replaces the
    password; it runs from the operator's machine right before App Review."""
    raise ApiError(409, "manual_only", "심사용 데이터는 서버에서 tools/seed_review.py로 다시 채워요.")


# --- A-12 공지·점검 -------------------------------------------------------------------------------

class MaintenanceIn(BaseModel):
    on: bool
    until: datetime | None = None  # when it ends; default two hours
    reason: str = Field(..., min_length=1, max_length=500)


class MinVersionIn(BaseModel):
    ios: str = Field(..., pattern=r"^\d+(\.\d+){0,2}$")
    reason: str = Field(..., min_length=1, max_length=500)


class NoticeIn(BaseModel):
    title: str = Field(..., min_length=1, max_length=60)
    body: str = Field(..., min_length=1, max_length=2000)
    publish_at: datetime | None = None  # null: now
    push: bool = False  # a service notice to every device, now (a scheduled one is not pushed)
    reason: str = Field(..., min_length=1, max_length=500)


def _notice_view(n: Notice) -> dict:
    return {"id": n.id, "title": n.title, "body": n.body, "publish_at": iso(n.publish_at), "push": n.push,
            "pushed_at": iso(n.pushed_at), "created_by": n.created_by, "created_at": iso(n.created_at),
            "published": n.publish_at <= _now() if n.publish_at.tzinfo else n.publish_at <= _now().replace(tzinfo=None)}


@router.get("/notices")
def notices(request: Request, db: Session = Depends(get_db)):
    start, end = runtime.maintenance(request.app)
    return {"maintenance": {"on": runtime.in_maintenance(request.app), "start": iso(start), "end": iso(end)},
            "min_version": {"ios": runtime.min_app_version(request.app)},
            "items": [_notice_view(n) for n in db.scalars(select(Notice).order_by(Notice.publish_at.desc()).limit(100))]}


@router.put("/maintenance")
def maintenance(body: MaintenanceIn, request: Request, op: Operator = Depends(owner), db: Session = Depends(get_db)):
    """Turns 41 잠시 점검 중이에요 on for everyone but operators, or off."""
    if body.on:
        end = body.until or _now() + timedelta(hours=2)
        if end <= _now():
            raise ApiError(422, "until_past", "끝나는 시각은 지금보다 뒤여야 해요.")
        runtime.put(db, "maintenance", {"start": _now().isoformat(), "end": end.isoformat()}, op.email)
    else:
        runtime.put(db, "maintenance", None, op.email)
    ops.audit(db, _actor(op), "maintenance_" + ("on" if body.on else "off"), reason=body.reason,
              until=iso(body.until))
    db.commit()
    runtime.forget(request.app)
    return notices(request, db)["maintenance"]


@router.put("/min-version")
def min_version(body: MinVersionIn, request: Request, op: Operator = Depends(owner), db: Session = Depends(get_db)):
    """40 새 버전이 필요해요 for iOS builds below this."""
    runtime.put(db, "min_app_version", body.ios, op.email)
    ops.audit(db, _actor(op), "min_version", reason=body.reason, ios=body.ios)
    db.commit()
    runtime.forget(request.app)
    return {"ios": runtime.min_app_version(request.app)}


@router.post("/notices", status_code=201)
def post_notice(body: NoticeIn, request: Request, op: Operator = Depends(owner), db: Session = Depends(get_db)):
    at = body.publish_at or _now()
    n = Notice(title=body.title, body=body.body, publish_at=at, push=body.push, created_by=op.email)
    db.add(n)
    db.flush()
    ops.audit(db, _actor(op), "notice_post", target=f"notice:{n.id}", reason=body.reason, push=body.push)
    db.commit()
    if body.push and at <= _now() + timedelta(minutes=1):
        users = list({d.user_id for d in db.scalars(select(DeviceToken))})
        notify(db, request.app.state.push, users, Message(body.title, body.body[:150], "notice"))
        n.pushed_at = _now()
        db.commit()
    return _notice_view(n)


@router.get("/audit/summary")
def audit_summary(db: Session = Depends(get_db)):
    """How many audit rows there are (A-13 header); the rows are GET /v1/admin/audit."""
    return {"rows": db.scalar(select(func.count()).select_from(AdminAudit)),
            "since": iso(db.scalar(select(func.min(AdminAudit.at))))}
