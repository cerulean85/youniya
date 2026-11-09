"""Operator API: reported 별빛 한 줄 and inquiries. Every call is written to admin_logs."""

import hmac
from typing import Literal

from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Header, Request
from pydantic import BaseModel, Field
from sqlalchemy import delete, func, select
from sqlalchemy.orm import Session

from ..deps import ApiError, get_cipher, get_db
from ..models import (AdminLog, DeviceToken, Inquiry, LineReport, NebulaShare, ShareReport, StarlightLine, StarShare,
                      User)
from .. import marketing
from ..push import Message, is_night_kst, notify
from ..security import Cipher
from ..views import iso


def operator(request: Request, x_admin_token: str | None = Header(None)) -> None:
    expected = request.app.state.settings.admin_token
    if not expected or not x_admin_token or not hmac.compare_digest(expected, x_admin_token):
        raise ApiError(404, "not_found", "찾지 못했어요.")


router = APIRouter(prefix="/v1/admin", tags=["admin"], dependencies=[Depends(operator)])


def _log(db: Session, action: str, target_id: str | None = None) -> None:
    db.add(AdminLog(action=action, target_id=target_id))
    db.commit()


@router.get("/status")
def status(request: Request):
    """Which outside services this deployment is set up for. No secrets, only whether each is on."""
    state, settings = request.app.state, request.app.state.settings
    return {
        "push": state.push is not None,
        "storekit": state.storekit is not None,
        "refund_answers": state.appstore is not None,
        "real_model": bool(settings.gemini_api_key),
        "error_reports": bool(settings.sentry_dsn),
        "invite_login": settings.invite_login,
        "apple_sign_in": bool(settings.apple_client_ids),
        "google_sign_in": bool(settings.google_client_ids),
        "dev_login": settings.dev_login,
        "trust_purchases": settings.trust_purchases,
        "min_app_version": settings.min_app_version,
    }


class PushTestIn(BaseModel):
    user_id: str = Field(..., description="GET /v1/me id of the account signed in on the phone")


@router.post("/push-test")
def push_test(body: PushTestIn, request: Request, db: Session = Depends(get_db)):
    """Sends "시험 알림" to every device of one user and says what APNs answered for each.
    With no devices listed, the app has not registered yet. A device APNs calls dead is forgotten."""
    if db.get(User, body.user_id) is None:
        raise ApiError(404, "not_found", "사용자를 찾지 못했어요.")
    client = request.app.state.push
    if client is None:
        raise ApiError(409, "push_not_configured", "APNs 키가 설정되지 않았어요.")
    devices = db.scalars(select(DeviceToken).where(DeviceToken.user_id == body.user_id)
                         .order_by(DeviceToken.updated_at.desc())).all()
    message = Message("시험 알림", "YOUNIYA 알림이 이 기기에 잘 도착했어요.", "test")
    results = []
    for d in devices:
        result, status, reason = client.send_detail(d.token, d.environment, message)
        results.append({"token": d.token[:8] + "…", "environment": d.environment,
                        "registered_at": iso(d.updated_at), "result": result, "status": status, "reason": reason})
        if result == "gone":
            db.execute(delete(DeviceToken).where(DeviceToken.token == d.token))
    _log(db, "push_test", body.user_id)
    return {"devices": results}


class OperatorTestError(RuntimeError):
    """Raised on purpose by POST /v1/admin/error-test."""


@router.post("/error-test")
def error_test():
    """An unhandled error on purpose (500), to see a report arrive in Sentry. Nothing is written."""
    raise OperatorTestError("operator test")


@router.get("/reports")
def reported_lines(db: Session = Depends(get_db), cipher: Cipher = Depends(get_cipher)):
    """Lines with at least one report, most reported first."""
    counts = (select(LineReport.line_id, LineReport.reason, func.count().label("n"))
              .group_by(LineReport.line_id, LineReport.reason))
    by_line: dict[str, dict[str, int]] = {}
    for line_id, reason, n in db.execute(counts):
        by_line.setdefault(line_id, {})[reason] = n
    rows = db.execute(select(StarlightLine, NebulaShare.name)
                      .join(NebulaShare, NebulaShare.id == StarlightLine.share_id)
                      .where(StarlightLine.id.in_(by_line))).all()
    items = [{"line_id": line.id, "text": line.text, "nebula": name, "hidden": line.hidden,
              "created_at": iso(line.created_at), "reasons": by_line[line.id],
              "reports": sum(by_line[line.id].values())} for line, name in rows]
    shares = []
    share_counts = (select(ShareReport.kind, ShareReport.target_id, ShareReport.reason, func.count().label("n"))
                    .group_by(ShareReport.kind, ShareReport.target_id, ShareReport.reason))
    by_share: dict[tuple[str, str], dict[str, int]] = {}
    for kind, target_id, reason, n in db.execute(share_counts):
        by_share.setdefault((kind, target_id), {})[reason] = n
    for (kind, target_id), reasons in by_share.items():
        row = db.get(StarShare if kind == "star" else NebulaShare, target_id)
        if row:
            # A reported full-text star is judged on what the plaza shows: its masked writing too.
            body = cipher.dec(row.body_masked_enc) if kind == "star" and row.full_text and row.body_masked_enc else None
            shares.append({"kind": kind, "id": row.id, "name": row.name, "quote": row.quote, "body_masked": body,
                           "hidden": row.hidden,
                           "created_at": iso(row.created_at), "reasons": reasons, "reports": sum(reasons.values())})
    _log(db, "list_reports")
    return {"items": sorted(items, key=lambda i: -i["reports"]),
            "shares": sorted(shares, key=lambda i: -i["reports"])}


# 101 "살펴본 뒤 결과를 알림으로 알려 드릴게요". The line itself is never quoted.
REPORT_RESULT = {
    "hide": Message("신고하신 별빛을 살펴봤어요", "운영 정책에 어긋나 광장에서 내렸어요. 알려 주셔서 고마워요.", "report_result"),
    "restore": Message("신고하신 별빛을 살펴봤어요", "운영 정책에 어긋나지 않아 그대로 두었어요. 내게는 계속 보이지 않아요.",
                       "report_result"),
}


@router.post("/lines/{line_id}/{action}")
def moderate_line(line_id: str, action: Literal["hide", "restore"], request: Request,
                  db: Session = Depends(get_db)):
    """hide: take it down for everyone. restore: looked at, and it stays (or comes back).
    Reporters not told yet hear the outcome once."""
    line = db.get(StarlightLine, line_id)
    if line is None:
        raise ApiError(404, "not_found", "별빛을 찾지 못했어요.")
    line.hidden = action == "hide"
    pending = db.scalars(select(LineReport).where(LineReport.line_id == line_id,
                                                  LineReport.notified_at.is_(None))).all()
    for r in pending:
        r.notified_at = datetime.now(timezone.utc)
    _log(db, f"{action}_line", line_id)
    sent = notify(db, request.app.state.push, [r.user_id for r in pending], REPORT_RESULT[action])
    return {"line_id": line_id, "hidden": line.hidden, "reporters_told": len(pending), "push": sent}


SHARE_RESULT_TITLE = {"star": "신고하신 별을 살펴봤어요", "nebula": "신고하신 성운을 살펴봤어요"}


@router.post("/shares/{kind}/{share_id}/{action}")
def moderate_share(kind: Literal["star", "nebula"], share_id: str, action: Literal["hide", "restore"],
                   request: Request, db: Session = Depends(get_db)):
    """The same as for lines, for a plaza star or nebula. A reporter keeps not seeing it after a restore."""
    row = db.get(StarShare if kind == "star" else NebulaShare, share_id)
    if row is None:
        raise ApiError(404, "not_found", "찾지 못했어요.")
    row.hidden = action == "hide"
    pending = db.scalars(select(ShareReport).where(ShareReport.kind == kind, ShareReport.target_id == share_id,
                                                   ShareReport.notified_at.is_(None))).all()
    for r in pending:
        r.notified_at = datetime.now(timezone.utc)
    _log(db, f"{action}_{kind}", share_id)
    message = Message(SHARE_RESULT_TITLE[kind], REPORT_RESULT[action].body, "report_result")
    sent = notify(db, request.app.state.push, [r.user_id for r in pending], message)
    return {"kind": kind, "id": share_id, "hidden": row.hidden, "reporters_told": len(pending), "push": sent}


class AnnouncementIn(BaseModel):
    title: str = Field(..., min_length=1, max_length=40, description="Without (광고): the server adds it")
    body: str = Field(..., min_length=1, max_length=150)
    dry_run: bool = Field(True, description="Count the recipients without sending")


@router.post("/announcements")
def announce(body: AnnouncementIn, request: Request, db: Session = Depends(get_db)):
    """새 기능·혜택 알림, only to users who opted in (11, 87).
    정보통신망법 50조: the title starts with (광고), the body ends with how to opt out,
    and nothing goes out between 21:00 and 08:00 KST."""
    if not body.dry_run and is_night_kst():
        raise ApiError(409, "night_time", "밤 9시부터 아침 8시까지는 광고 알림을 보낼 수 없어요.")
    if not body.dry_run and marketing.ads_this_month(db) >= marketing.ADS_PER_MONTH:  # 14.3
        raise ApiError(409, "monthly_limit", f"광고 알림은 한 달에 {marketing.ADS_PER_MONTH}번까지 보낼 수 있어요.")
    users = list(db.scalars(select(User.id).where(User.marketing_opt_in.is_(True))))
    message = Message(f"(광고) {body.title}", f"{body.body}\n수신거부: 설정 › 알림", "announcement")
    if body.dry_run:
        return {"recipients": len(users), "title": message.title, "sent": None}
    _log(db, "announce")
    return {"recipients": len(users), "title": message.title, "sent": notify(db, request.app.state.push, users, message)}


@router.get("/inquiries")
def inquiries(db: Session = Depends(get_db), cipher: Cipher = Depends(get_cipher)):
    rows = db.scalars(select(Inquiry).order_by(Inquiry.created_at.desc()).limit(200)).all()
    _log(db, "list_inquiries")
    return {"items": [{"id": r.id, "kind": r.kind, "email": r.email, "body": cipher.dec(r.body_enc),
                       "created_at": iso(r.created_at)} for r in rows]}


@router.get("/logs")
def logs(db: Session = Depends(get_db)):
    rows = db.scalars(select(AdminLog).order_by(AdminLog.created_at.desc()).limit(500)).all()
    return {"items": [{"action": r.action, "target_id": r.target_id, "at": iso(r.created_at)} for r in rows]}
