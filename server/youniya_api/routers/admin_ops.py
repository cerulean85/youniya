"""관리자 콘솔: 신고 (A-03·04), 별지기 (A-05·06), 문의 (A-07). 기획서 18장.

Operators see only what the plaza shows (shared sentences and writing, lines, names) and
operating data; never unshared writing, starlight numbers or telescope results. Every action
needs a reason, goes to the audit log, and the keeper hears of it by an app notice."""

import csv
import io
import re
from datetime import datetime, timedelta, timezone
from typing import Literal

from fastapi import APIRouter, Depends, Query, Request, Response
from pydantic import BaseModel, Field
from sqlalchemy import func, select, update
from sqlalchemy.orm import Session

from .. import coins, marketing, mailer, nickname
from .. import operators as ops
from ..deps import ApiError, get_cipher, get_db
from ..models import (CoinEntry, Inquiry, InquiryReply, LineReport, NebulaShare, Operator, ShareReport, Star,
                      StarLine, StarLineReport, StarlightLine, StarShare, TossOrder, User)
from ..push import Message, notify
from ..security import Cipher
from ..views import aware, iso
from .admin_auth import anyone, owner
from . import payments

router = APIRouter(prefix="/v1/admin", tags=["admin"])

Kind = Literal["star", "nebula", "line", "star_line", "nickname"]
Status = Literal["pending", "hidden", "done"]


def _now() -> datetime:
    return datetime.now(timezone.utc)


# --- 신고 -----------------------------------------------------------------------------------------

def _report_rows(db: Session, kind: str, target_id: str | None = None) -> list:
    """(target_id, reporter_id, reason, created_at, notified_at) for one kind."""
    if kind in ("star", "nebula"):
        q = select(ShareReport.target_id, ShareReport.user_id, ShareReport.reason, ShareReport.created_at,
                   ShareReport.notified_at).where(ShareReport.kind == kind)
        q = q.where(ShareReport.reason != "nickname") if kind == "star" else q
        if target_id:
            q = q.where(ShareReport.target_id == target_id)
    elif kind == "line":
        q = select(LineReport.line_id, LineReport.user_id, LineReport.reason, LineReport.created_at,
                   LineReport.notified_at)
        if target_id:
            q = q.where(LineReport.line_id == target_id)
    elif kind == "star_line":
        q = select(StarLineReport.line_id, StarLineReport.user_id, StarLineReport.reason, StarLineReport.created_at,
                   StarLineReport.notified_at)
        if target_id:
            q = q.where(StarLineReport.line_id == target_id)
    else:  # nickname: reports of a plaza star for its keeper's name; the target is the keeper
        q = (select(StarShare.user_id, ShareReport.user_id, ShareReport.reason, ShareReport.created_at,
                    ShareReport.notified_at)
             .join(StarShare, StarShare.id == ShareReport.target_id)
             .where(ShareReport.kind == "star", ShareReport.reason == "nickname"))
        if target_id:
            q = q.where(StarShare.user_id == target_id)
    return db.execute(q).all()


def _target(db: Session, kind: str, target_id: str):
    model = {"star": StarShare, "nebula": NebulaShare, "line": StarlightLine, "star_line": StarLine,
             "nickname": User}[kind]
    return db.get(model, target_id)


def _keeper_of(row, kind: str) -> str | None:
    return row.id if kind == "nickname" else getattr(row, "user_id", None)


def _content(db: Session, kind: str, row, cipher: Cipher) -> dict:
    """What the plaza shows of it, nothing more."""
    if kind == "star":
        return {"name": row.name, "quote": row.quote, "full_text": row.full_text,
                "body_masked": cipher.dec(row.body_masked_enc) if row.full_text and row.body_masked_enc else None,
                "shared_at": iso(row.created_at)}
    if kind == "nebula":
        return {"name": row.name, "quote": row.quote, "shared_at": iso(row.created_at)}
    if kind in ("line", "star_line"):
        return {"text": row.text, "chip": getattr(row, "chip", None), "shared_at": iso(row.created_at)}
    return {"nickname": row.nickname, "shared_at": None}


def _preview(content: dict) -> str:
    return (content.get("quote") or content.get("text") or content.get("nickname") or content.get("name") or "")[:80]


def _hidden(kind: str, row) -> bool:
    return bool(getattr(row, "hidden", False))


def _status(kind: str, row, rows: list) -> tuple[str, bool]:
    pending = any(r[4] is None for r in rows)
    if not pending:
        return "done", False
    return ("hidden", True) if _hidden(kind, row) else ("pending", False)


@router.get("/reports")
def reports(status: Status | None = None, kind: Kind | None = None, op: Operator = Depends(anyone),
            db: Session = Depends(get_db), cipher: Cipher = Depends(get_cipher)):
    """A-03: everything reported, longest waiting first. `counts` per status for the tabs."""
    items, counts = [], {"pending": 0, "hidden": 0, "done": 0}
    for k in ([kind] if kind else ["star", "star_line", "line", "nebula", "nickname"]):
        by: dict[str, list] = {}
        for r in _report_rows(db, k):
            by.setdefault(r[0], []).append(r)
        for target_id, rows in by.items():
            row = _target(db, k, target_id)
            if row is None:
                continue
            st, _ = _status(k, row, rows)
            counts[st] += 1
            if status and st != status:
                continue
            reasons: dict[str, int] = {}
            for r in rows:
                reasons[r[2]] = reasons.get(r[2], 0) + 1
            items.append({"id": f"{k}:{target_id}", "kind": k, "target_id": target_id,
                          "preview": _preview(_content(db, k, row, cipher)), "reasons": reasons, "reports": len(rows),
                          "first_reported_at": iso(min(aware(r[3]) for r in rows)), "status": st})
    items.sort(key=lambda i: i["first_reported_at"])
    return {"items": items, "counts": counts}


@router.get("/reports/{kind}/{target_id}")
def report(kind: Kind, target_id: str, op: Operator = Depends(anyone), db: Session = Depends(get_db),
           cipher: Cipher = Depends(get_cipher)):
    """A-04. Reporters are numbers, never names."""
    row = _target(db, kind, target_id)
    rows = _report_rows(db, kind, target_id)
    if row is None or not rows:
        raise ApiError(404, "not_found", "신고를 찾지 못했어요.")
    st, auto = _status(kind, row, rows)
    keeper_id = _keeper_of(row, kind)
    keeper = db.get(User, keeper_id) if keeper_id else None
    numbers: dict[str, int] = {}
    reports = []
    for r in sorted(rows, key=lambda r: aware(r[3])):
        numbers.setdefault(r[1], len(numbers) + 1)
        reports.append({"reporter_no": numbers[r[1]], "reason": r[2], "at": iso(r[3]), "note": None})
    history = db.scalars(select(ops.AdminAudit).where(ops.AdminAudit.target == f"{kind}:{target_id}")
                         .order_by(ops.AdminAudit.at.desc())).all()
    return {"kind": kind, "target_id": target_id, "status": st, "auto_hidden": auto,
            "content": _content(db, kind, row, cipher),
            "keeper": {"id": keeper.id, "no": keeper.keeper_no, "nickname": keeper.nickname} if keeper else None,
            "reports": reports, "actions": [_audit_view(a) for a in history]}


class ReportAction(BaseModel):
    action: Literal["restore", "take_down", "request_rename", "restrict_7d", "restrict_30d", "note"]
    reason: str = Field(..., min_length=1, max_length=500)
    note: str | None = Field(None, max_length=1000)


REPORTER_TOLD = {
    "take_down": "운영 정책에 어긋나 광장에서 내렸어요. 알려 주셔서 고마워요.",
    "restore": "운영 정책에 어긋나지 않아 그대로 두었어요. 내게는 계속 보이지 않아요.",
}
KEEPER_TOLD = {
    "take_down": ("나눈 글이 광장에서 내려갔어요", "운영 정책에 맞지 않는 부분이 있어 광장에서 내렸어요. 글은 내 기록에 그대로 있어요."),
    "request_rename": ("별지기 이름을 바꿔 주세요", "지금 이름이 운영 정책에 맞지 않아요. 설정에서 새 이름을 지어 주세요."),
    "restrict": ("우주 광장 이용이 잠시 제한됐어요", "{days}일 동안 광장에 나누거나 한 줄을 남길 수 없어요. 기록은 그대로 쓸 수 있어요."),
}


def _tell(db: Session, request: Request, user_ids: list[str], title: str, body: str, target: dict | None = None) -> None:
    notify(db, request.app.state.push, [u for u in user_ids if u], Message(title, body, "report_result", target))


def _restrict(user: User, days: int) -> None:
    start = max(_now(), aware(user.plaza_restricted_until)) if user.plaza_restricted_until else _now()
    user.plaza_restricted_until = start + timedelta(days=days)


def _mark_looked_at(db: Session, kind: str, target_id: str) -> list[str]:
    """Reports not answered yet become answered; returns their reporters."""
    now, rows = _now(), _report_rows(db, kind, target_id)
    reporters = [r[1] for r in rows if r[4] is None]
    if kind in ("star", "nebula", "nickname"):
        share_ids = [target_id] if kind != "nickname" else list(db.scalars(
            select(StarShare.id).where(StarShare.user_id == target_id)))
        q = update(ShareReport).where(ShareReport.target_id.in_(share_ids), ShareReport.notified_at.is_(None))
        q = q.where(ShareReport.reason == "nickname") if kind == "nickname" else q.where(ShareReport.kind == kind)
        db.execute(q.values(notified_at=now))
    elif kind == "line":
        db.execute(update(LineReport).where(LineReport.line_id == target_id, LineReport.notified_at.is_(None))
                   .values(notified_at=now))
    else:
        db.execute(update(StarLineReport).where(StarLineReport.line_id == target_id,
                                                StarLineReport.notified_at.is_(None)).values(notified_at=now))
    return reporters


@router.post("/reports/{kind}/{target_id}/actions")
def report_action(kind: Kind, target_id: str, body: ReportAction, request: Request, op: Operator = Depends(anyone),
                  db: Session = Depends(get_db)):
    """restore · take_down (광장에서 내리기) · request_rename · restrict_7d / restrict_30d · note."""
    row = _target(db, kind, target_id)
    if row is None or not _report_rows(db, kind, target_id):
        raise ApiError(404, "not_found", "신고를 찾지 못했어요.")
    keeper = db.get(User, _keeper_of(row, kind)) if _keeper_of(row, kind) else None
    a = body.action
    if a in ("restore", "take_down"):
        if kind == "nickname":
            raise ApiError(422, "wrong_action", "별지기 이름은 이름 바꾸기 요청으로 처리해 주세요.")
        row.hidden = a == "take_down"
    if a == "request_rename" and keeper:
        keeper.nickname_rename_requested_at = _now()
    if a in ("restrict_7d", "restrict_30d") and keeper:
        _restrict(keeper, 7 if a == "restrict_7d" else 30)
    reporters = [] if a == "note" else _mark_looked_at(db, kind, target_id)
    entry = ops.audit(db, op if op.id else None, f"report_{a}", target=f"{kind}:{target_id}", reason=body.reason,
                      note=body.note, keeper=keeper.id if keeper else None)
    db.commit()
    if a in REPORTER_TOLD and kind != "star_line":  # a star line's reporter is its star's owner
        _tell(db, request, reporters, "신고하신 내용을 살펴봤어요", REPORTER_TOLD[a], {"screen": "notifications"})
    if keeper and a == "take_down":
        star = {"screen": "star", "star_id": row.star_id} if kind == "star" else {"screen": "notifications"}
        _tell(db, request, [keeper.id], *KEEPER_TOLD[a], star)
    if keeper and a == "request_rename":
        _tell(db, request, [keeper.id], *KEEPER_TOLD[a], {"screen": "nickname"})
    if keeper and a.startswith("restrict"):
        title, text = KEEPER_TOLD["restrict"]
        _tell(db, request, [keeper.id], title, text.format(days=7 if a == "restrict_7d" else 30),
              {"screen": "plaza_restricted", "until": iso(keeper.plaza_restricted_until)})
    st, _ = _status(kind, row, _report_rows(db, kind, target_id))
    return {"status": st, "action_id": entry.id}


def _audit_view(a) -> dict:
    return {"id": a.id, "at": iso(a.at), "operator": a.operator_email or "admin-token", "action": a.action,
            "target": a.target, "reason": a.reason, "detail": a.detail}


# --- 별지기 ---------------------------------------------------------------------------------------

def _restricted(u: User) -> bool:
    return bool(u.plaza_restricted_until and aware(u.plaza_restricted_until) > _now())


def _keeper_row(db: Session, u: User) -> dict:
    stars = db.scalar(select(func.count()).select_from(Star).where(Star.user_id == u.id))
    shared = db.scalar(select(func.count()).select_from(StarShare).where(StarShare.user_id == u.id))
    reports = db.scalar(select(func.count()).select_from(ShareReport).join(StarShare, StarShare.id == ShareReport.target_id)
                        .where(StarShare.user_id == u.id))
    return {"id": u.id, "no": u.keeper_no, "nickname": u.nickname, "joined_at": iso(u.created_at), "provider": u.provider,
            "stars": stars, "shared": shared, "reports": reports, "coins": u.coins,
            "status": "restricted" if _restricted(u) else "active", "restricted_until": iso(u.plaza_restricted_until)}


@router.get("/keepers")
def keepers(q: str | None = Query(None, max_length=40), filter: Literal["all", "restricted", "reported", "invite"] = "all",
            format: Literal["json", "csv"] = "json", limit: int = Query(100, ge=1, le=1000),
            op: Operator = Depends(anyone), db: Session = Depends(get_db)):
    """A-05: by 별지기 이름 or #번호. CSV (numbers only, no writing) for owners."""
    stmt = select(User).order_by(User.created_at.desc())
    if q:
        if m := re.fullmatch(r"#?(\d+)", q.strip()):
            stmt = stmt.where(User.keeper_no == int(m.group(1)))
        else:
            stmt = stmt.where(User.nickname_key.contains(nickname.key(q)))
    if filter == "restricted":
        stmt = stmt.where(User.plaza_restricted_until > _now())
    elif filter == "invite":
        stmt = stmt.where(User.provider == "invite")
    rows = [_keeper_row(db, u) for u in db.scalars(stmt.limit(limit))]
    if filter == "reported":
        rows = [r for r in rows if r["reports"]]
    if format == "csv":
        if op.role != "owner":
            raise ApiError(403, "forbidden_role", "이 작업을 할 권한이 없어요.", role=op.role)
        out = io.StringIO()
        w = csv.writer(out)
        keys = ["no", "nickname", "joined_at", "provider", "stars", "shared", "reports", "coins", "status"]
        w.writerow(keys)
        for r in rows:
            w.writerow([r[k] for k in keys])
        return Response("﻿" + out.getvalue(), media_type="text/csv; charset=utf-8",
                        headers={"Content-Disposition": 'attachment; filename="youniya-keepers.csv"'})
    return {"items": rows}


@router.get("/keepers/{user_id}")
def keeper(user_id: str, op: Operator = Depends(anyone), db: Session = Depends(get_db)):
    """A-06: the account, its consents and what operators did, never its writing."""
    u = db.get(User, user_id)
    if u is None:
        raise ApiError(404, "not_found", "별지기를 찾지 못했어요.")
    lit = db.scalar(select(func.count()).select_from(Star).where(Star.user_id == u.id, Star.state == "floated"))
    total = db.scalar(select(func.count()).select_from(Star).where(Star.user_id == u.id))
    history = db.scalars(select(ops.AdminAudit).where(ops.AdminAudit.target == f"keeper:{u.id}")
                         .order_by(ops.AdminAudit.at.desc())).all()
    return _keeper_row(db, u) | {
        "last_seen_at": iso(u.last_seen_at), "star_counts": {"lit": lit, "unlit": total - lit},
        "consents": {"terms_at": iso(u.consented_at), "terms_version": None, "sensitive_at": iso(u.consented_at),
                     "marketing": {"opt_in": u.marketing_opt_in, "at": marketing.view(u)["consented_at"]}},
        "nickname_next_change": iso(nickname.next_change(u)),
        "nickname_rename_requested_at": iso(u.nickname_rename_requested_at),
        "deletion_requested_at": None, "history": [_audit_view(a) for a in history]}


class KeeperAction(BaseModel):
    action: Literal["lift_restriction", "extend_restriction", "request_rename", "grant_coins", "revoke_coins",
                    "process_deletion"]
    reason: str = Field(..., min_length=1, max_length=500)
    amount: int | None = Field(None, ge=1, le=10000)
    days: Literal[7, 30] | None = None


OWNER_ONLY = ("grant_coins", "revoke_coins", "process_deletion")


@router.post("/keepers/{user_id}/actions")
def keeper_action(user_id: str, body: KeeperAction, request: Request, op: Operator = Depends(anyone),
                  db: Session = Depends(get_db)):
    u = db.get(User, user_id)
    if u is None:
        raise ApiError(404, "not_found", "별지기를 찾지 못했어요.")
    a = body.action
    if a in OWNER_ONLY and op.role != "owner":
        raise ApiError(403, "forbidden_role", "이 작업을 할 권한이 없어요.", role=op.role)
    actor = op if op.id else None
    tell: tuple | None = None
    if a == "lift_restriction":
        u.plaza_restricted_until = None
        tell = ("우주 광장 이용 제한이 풀렸어요", "다시 광장에 나누고 한 줄을 남길 수 있어요.", {"screen": "plaza"})
    elif a == "extend_restriction":
        if body.days is None:
            raise ApiError(422, "days_required", "며칠 동안 제한할지 골라 주세요.")
        _restrict(u, body.days)
        tell = (KEEPER_TOLD["restrict"][0], KEEPER_TOLD["restrict"][1].format(days=body.days),
                {"screen": "plaza_restricted", "until": iso(u.plaza_restricted_until)})
    elif a == "request_rename":
        u.nickname_rename_requested_at = _now()
        tell = (*KEEPER_TOLD["request_rename"], {"screen": "nickname"})
    elif a == "grant_coins":
        if body.amount is None:
            raise ApiError(422, "amount_required", "지급할 코인 수를 적어 주세요.")
        coins.add(db, u, body.amount, "운영자 지급")
        tell = ("코인이 지급됐어요", f"{body.amount}코인을 받았어요.", {"screen": "coin_history"})
    elif a == "revoke_coins":
        if body.amount is None:
            raise ApiError(422, "amount_required", "회수할 코인 수를 적어 주세요.")
        # Never below 0: more than the balance is refused, not cut down.
        if not db.execute(update(User).where(User.id == u.id, User.coins >= body.amount)
                          .values(coins=User.coins - body.amount)).rowcount:
            db.rollback()
            raise ApiError(409, "insufficient_balance", "남은 코인보다 많이 회수할 수 없어요.", coins=u.coins)
        db.add(CoinEntry(user_id=u.id, title="운영자 회수", delta=-body.amount))
        db.refresh(u)
        tell = ("코인이 회수됐어요", f"운영자가 코인 {body.amount}개를 회수했어요. 궁금한 점은 문의하기로 알려 주세요.",
                {"screen": "coin_history"})
    elif a == "process_deletion":
        ops.audit(db, actor, "keeper_process_deletion", target=f"keeper:{u.id}", reason=body.reason, no=u.keeper_no)
        db.execute(update(CoinEntry).where(CoinEntry.user_id == u.id, CoinEntry.transaction_id.is_not(None))
                   .values(user_id=None))  # store records stay 5 years, as when the keeper deletes it
        db.delete(u)
        db.commit()
        return {"deleted": True}
    ops.audit(db, actor, f"keeper_{a}", target=f"keeper:{u.id}", reason=body.reason,
              amount=body.amount, days=body.days)
    db.commit()
    if tell:
        notify(db, request.app.state.push, [u.id], Message(tell[0], tell[1], "report_result", tell[2] if len(tell) > 2 else None))
    return _keeper_row(db, u)


# --- 웹 결제 (토스) 환불 ---------------------------------------------------------------------------

def _order_view(o: TossOrder, balance: int) -> dict:
    block = payments.refund_block(o, balance)
    return {"id": o.id, "created_at": iso(o.created_at), "approved_at": iso(o.approved_at), "package_id": o.package_id,
            "coins": o.coins, "amount": o.amount, "method": o.method, "status": o.status,
            "canceled_at": iso(o.canceled_at), "refundable": block is None, "refund_block": block}


@router.get("/keepers/{user_id}/orders")
def keeper_orders(user_id: str, op: Operator = Depends(anyone), db: Session = Depends(get_db)):
    """The keeper's web (Toss) orders, newest first. `refund_block`: why the policy refund can't be done
    (not_done · window_passed · coins_spent), or null."""
    u = db.get(User, user_id)
    if u is None:
        raise ApiError(404, "not_found", "별지기를 찾지 못했어요.")
    rows = db.scalars(select(TossOrder).where(TossOrder.user_id == u.id).order_by(TossOrder.created_at.desc())).all()
    return {"items": [_order_view(o, u.coins) for o in rows]}


class RefundIn(BaseModel):
    reason: str = Field(..., min_length=1, max_length=500)
    force: bool = False


@router.post("/orders/{order_id}/refund")
def refund_order(order_id: str, body: RefundIn, request: Request, op: Operator = Depends(owner),
                 db: Session = Depends(get_db)):
    """A 문의 refund request. By the policy (7 days, coins unspent: 409 refund_window_passed · coins_spent);
    `force` cancels the whole payment anyway and takes back what is left of its coins (min(order, balance))."""
    toss = request.app.state.toss
    if toss is None:
        raise ApiError(503, "payments_unavailable", "토스 결제가 설정되지 않았어요.")
    o = db.get(TossOrder, order_id)
    if o is None:
        raise ApiError(404, "order_not_found", "주문을 찾지 못했어요.")
    if o.status == "canceled":
        raise ApiError(409, "order_canceled", "이미 환불된 주문이에요.")
    taken = payments.refund(db, toss, o, body.reason[:200], title="운영자 환불", force=body.force)
    u = db.get(User, o.user_id) if o.user_id else None
    ops.audit(db, op if op.id else None, "keeper_refund", target=f"keeper:{o.user_id}" if o.user_id else None,
              reason=body.reason, order=o.id, amount=o.amount, coins_taken=taken, force=body.force)
    if not payments.commit_refund(db, o):
        raise ApiError(409, "order_canceled", "이미 환불된 주문이에요.")
    if u is not None:
        db.refresh(u)
        notify(db, request.app.state.push, [u.id], Message(
            "결제가 환불됐어요", f"{o.amount:,}원이 환불되고 코인 {taken}개가 회수됐어요.", "report_result",
            {"screen": "coin_history"}))
    return {"order": _order_view(o, u.coins if u else 0), "coins_taken": taken,
            "keeper": _keeper_row(db, u) if u else None}


# --- 문의 -----------------------------------------------------------------------------------------

def _mask_email(email: str) -> str:
    name, _, domain = email.partition("@")
    return (name[:2] + "●" * max(1, len(name) - 2)) + "@" + domain


def _inquiry_title(body: str) -> str:
    first = body.strip().splitlines()[0] if body.strip() else ""
    return first[:40]


@router.get("/inquiries")
def inquiries(status: Literal["new", "answered"] | None = None, op: Operator = Depends(anyone),
              db: Session = Depends(get_db), cipher: Cipher = Depends(get_cipher)):
    """A-07 목록, newest first."""
    stmt = select(Inquiry).order_by(Inquiry.created_at.desc())
    if status:
        stmt = stmt.where(Inquiry.status == status)
    counts = {s: db.scalar(select(func.count()).select_from(Inquiry).where(Inquiry.status == s))
              for s in ("new", "answered")}
    return {"items": [{"id": r.id, "kind": r.kind, "title": _inquiry_title(cipher.dec(r.body_enc)),
                       "created_at": iso(r.created_at), "status": r.status} for r in db.scalars(stmt.limit(300))],
            "counts": counts}


def _inquiry_view(db: Session, r: Inquiry, cipher: Cipher) -> dict:
    u = db.get(User, r.user_id)
    replies = db.scalars(select(InquiryReply).where(InquiryReply.inquiry_id == r.id).order_by(InquiryReply.created_at))
    purchase = db.scalars(select(CoinEntry).where(CoinEntry.user_id == r.user_id, CoinEntry.transaction_id.is_not(None))
                          .order_by(CoinEntry.created_at.desc()).limit(1)).first() if r.kind == "payment" else None
    return {"id": r.id, "kind": r.kind, "title": _inquiry_title(cipher.dec(r.body_enc)), "created_at": iso(r.created_at),
            "status": r.status, "body": cipher.dec(r.body_enc), "email_masked": _mask_email(r.email),
            "keeper": {"id": u.id, "no": u.keeper_no, "nickname": u.nickname} if u else None,
            "app": r.app_info, "purchase": {"transaction_id": purchase.transaction_id, "status": purchase.title}
            if purchase else None,
            "replies": [{"at": iso(x.created_at), "operator": x.operator_email, "body": cipher.dec(x.body_enc),
                         "sent": x.sent} for x in replies]}


@router.get("/inquiries/{inquiry_id}")
def inquiry(inquiry_id: str, op: Operator = Depends(anyone), db: Session = Depends(get_db),
            cipher: Cipher = Depends(get_cipher)):
    r = db.get(Inquiry, inquiry_id)
    if r is None:
        raise ApiError(404, "not_found", "문의를 찾지 못했어요.")
    return _inquiry_view(db, r, cipher)


class ReplyIn(BaseModel):
    body: str = Field(..., min_length=1, max_length=5000)


@router.post("/inquiries/{inquiry_id}/reply")
def reply(inquiry_id: str, body: ReplyIn, request: Request, op: Operator = Depends(anyone),
          db: Session = Depends(get_db), cipher: Cipher = Depends(get_cipher)):
    """Sends the reply to the email the inquiry gave (Resend) and marks it answered. 503 mail_unavailable
    without RESEND_API_KEY, 502 mail_failed when Resend refuses: nothing is marked then."""
    r = db.get(Inquiry, inquiry_id)
    if r is None:
        raise ApiError(404, "not_found", "문의를 찾지 못했어요.")
    settings = request.app.state.settings
    if not settings.resend_api_key:
        raise ApiError(503, "mail_unavailable", "메일 발송이 아직 설정되지 않았어요.")
    text = (f"{body.body}\n\n—\nYOUNIYA 고객 지원\n"
            f"문의하신 내용: {_inquiry_title(cipher.dec(r.body_enc))}")
    try:
        mailer.send(settings.resend_api_key, settings.mail_from, r.email, "[YOUNIYA] 문의하신 내용에 답장드려요", text)
    except mailer.MailError:
        raise ApiError(502, "mail_failed", "메일을 보내지 못했어요. 잠시 뒤 다시 보내 주세요.")
    db.add(InquiryReply(inquiry_id=r.id, operator_email=op.email, body_enc=cipher.enc(body.body), sent=True))
    r.status = "answered"
    ops.audit(db, op if op.id else None, "inquiry_reply", target=f"inquiry:{r.id}")
    db.commit()
    return _inquiry_view(db, r, cipher)
