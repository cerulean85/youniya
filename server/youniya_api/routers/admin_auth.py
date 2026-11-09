"""관리자 콘솔 인증·운영자·운영 기록 (기획서 18장, A-01 · A-13 · A-14).

Sign-in: POST /v1/admin/auth/login → {challenge}; POST /v1/admin/auth/totp → {token}; then
"Authorization: Bearer <token>" on every /v1/admin call (12 hours). The ADMIN_TOKEN header keeps
working as an owner for scripts. Operators are invited: the setup token sets a password and the
authenticator app, once."""

import csv
import io
from datetime import datetime
from typing import Literal

from fastapi import APIRouter, Depends, Header, Query, Request, Response
from pydantic import BaseModel, Field
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from .. import operators as ops
from ..deps import ApiError, get_cipher, get_db
from ..models import AdminAudit, Operator
from ..ratelimit import per_ip
from ..security import Cipher
from ..views import iso

import hmac

Role = Literal["owner", "moderator"]


def admin_operator(request: Request, authorization: str | None = Header(None),
                   x_admin_token: str | None = Header(None), db: Session = Depends(get_db)) -> Operator:
    """The signed-in operator, or the ADMIN_TOKEN as an owner. Anything else: the same 404 as an unknown path,
    except an expired or unknown session token: 401 (the console signs in again)."""
    expected = request.app.state.settings.admin_token
    if expected and x_admin_token and hmac.compare_digest(expected, x_admin_token):
        return Operator(email="admin-token", role="owner", status="active")
    if authorization and authorization.lower().startswith("bearer "):
        row = ops.session_operator(db, authorization[7:].strip())
        if row is None:
            raise ApiError(401, "session_expired", "다시 로그인해 주세요.")
        return row
    raise ApiError(404, "not_found", "찾지 못했어요.")


def require(*roles: str):
    def check(op: Operator = Depends(admin_operator)) -> Operator:
        if op.role not in roles:
            raise ApiError(403, "forbidden_role", "이 작업을 할 권한이 없어요.", role=op.role)
        return op
    return check


owner = require("owner")
anyone = require("owner", "moderator")

auth = APIRouter(prefix="/v1/admin/auth", tags=["admin"])
router = APIRouter(prefix="/v1/admin", tags=["admin"])


class LoginIn(BaseModel):
    email: str = Field(..., max_length=254)
    password: str = Field(..., max_length=200)


class TotpIn(BaseModel):
    challenge: str = Field(..., max_length=100)
    code: str = Field(..., max_length=10)


class SetupIn(BaseModel):
    invite_token: str = Field(..., max_length=100)
    password: str = Field(..., min_length=12, max_length=200)


class SetupConfirmIn(BaseModel):
    invite_token: str = Field(..., max_length=100)
    code: str = Field(..., max_length=10)


def _locked(until: datetime):
    return ApiError(423, "locked", "로그인을 5번 잘못해서 15분 동안 잠겼어요.", until=iso(until))


@auth.post("/login", dependencies=[per_ip("admin_login", 20, 60)])
def login(body: LoginIn, db: Session = Depends(get_db)):
    """A-01 step 1. A wrong email and a wrong password give the same answer."""
    row = db.scalar(select(Operator).where(Operator.email == body.email.strip().lower()))
    if row is not None and (until := ops.locked(row)):
        raise _locked(until)
    if not ops.password_ok(row, body.password) or row.status != "active":
        if row is not None and row.status == "active" and (until := ops.failed(db, row)):
            raise _locked(until)
        raise ApiError(401, "invalid_credentials", "이메일이나 비밀번호가 맞지 않아요.")
    return {"challenge": ops.challenge(db, row)}


@auth.post("/totp", dependencies=[per_ip("admin_login", 20, 60)])
def totp(body: TotpIn, db: Session = Depends(get_db), cipher: Cipher = Depends(get_cipher)):
    """A-01 step 2: the authenticator app's six digits. Failures count toward the same lock."""
    row = ops.take_challenge(db, body.challenge)
    if row is None or row.status != "active":
        db.commit()
        raise ApiError(401, "challenge_expired", "처음부터 다시 로그인해 주세요.")
    if until := ops.locked(row):
        db.commit()
        raise _locked(until)
    step = ops.check_totp(cipher.dec(row.totp_secret_enc), body.code, row.totp_last_step)
    if step is None:
        if until := ops.failed(db, row):
            raise _locked(until)
        raise ApiError(401, "invalid_code", "인증 코드가 맞지 않아요.", challenge=ops.challenge(db, row))
    row.totp_last_step = step
    token, expires = ops.start_session(db, row)
    ops.audit(db, row, "sign_in")
    db.commit()
    return {"token": token, "expires_at": iso(expires), "operator": ops.view(row)}


@auth.post("/logout", status_code=204)
def logout(authorization: str | None = Header(None), db: Session = Depends(get_db)):
    if authorization and authorization.lower().startswith("bearer "):
        ops.end_session(db, authorization[7:].strip())


@auth.get("/me")
def me(op: Operator = Depends(anyone)):
    return ops.view(op) if op.id else {"email": op.email, "role": op.role, "status": "active", "totp": False}


@auth.post("/setup", dependencies=[per_ip("admin_login", 20, 60)])
def setup(body: SetupIn, db: Session = Depends(get_db), cipher: Cipher = Depends(get_cipher)):
    """From the invitation: set the password, then add the returned secret to an authenticator app."""
    row = ops.by_invite(db, body.invite_token)
    if row is None:
        raise ApiError(404, "invite_not_found", "초대가 없거나 기한이 지났어요.")
    secret = ops.new_totp_secret()
    row.password_hash, row.totp_secret_enc = ops.hash_password(body.password), cipher.enc(secret)
    db.commit()
    return {"totp_secret": secret, "otpauth_uri": ops.otpauth_uri(row.email, secret)}


@auth.post("/setup/confirm", dependencies=[per_ip("admin_login", 20, 60)])
def setup_confirm(body: SetupConfirmIn, db: Session = Depends(get_db), cipher: Cipher = Depends(get_cipher)):
    """The first code from the app turns the account on; the invitation is used up."""
    row = ops.by_invite(db, body.invite_token)
    if row is None or row.totp_secret_enc is None:
        raise ApiError(404, "invite_not_found", "초대가 없거나 기한이 지났어요.")
    step = ops.check_totp(cipher.dec(row.totp_secret_enc), body.code, None)
    if step is None:
        raise ApiError(401, "invalid_code", "인증 코드가 맞지 않아요.")
    row.status, row.invite_hash, row.invite_expires_at, row.totp_last_step = "active", None, None, step
    ops.audit(db, row, "operator_activated", target=f"operator:{row.id}")
    db.commit()
    return ops.view(row)


# --- A-14 운영자·권한 -----------------------------------------------------------------------------

class InviteIn(BaseModel):
    email: str = Field(..., min_length=3, max_length=254, pattern=r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
    role: Role
    reason: str = Field(..., min_length=1, max_length=500)


class OperatorPatch(BaseModel):
    role: Role | None = None
    status: Literal["active", "disabled"] | None = None
    reason: str = Field(..., min_length=1, max_length=500)


@router.get("/operators")
def list_operators(op: Operator = Depends(owner), db: Session = Depends(get_db)):
    return {"items": [ops.view(r) for r in db.scalars(select(Operator).order_by(Operator.created_at))]}


@router.post("/operators/invite", status_code=201)
def invite_operator(body: InviteIn, op: Operator = Depends(owner), db: Session = Depends(get_db)):
    """Returns the setup token once; the console makes the link from it (no email is sent yet)."""
    try:
        row, token = ops.invite(db, body.email, body.role, op.id)
    except ValueError:
        raise ApiError(409, "operator_exists", "이미 있는 운영자예요.")
    ops.audit(db, op, "operator_invite", target=f"operator:{row.id}", reason=body.reason, role=body.role)
    db.commit()
    return {"operator": ops.view(row), "setup_token": token, "expires_at": iso(row.invite_expires_at)}


@router.patch("/operators/{operator_id}")
def change_operator(operator_id: str, body: OperatorPatch, op: Operator = Depends(owner),
                    db: Session = Depends(get_db)):
    row = db.get(Operator, operator_id)
    if row is None:
        raise ApiError(404, "not_found", "운영자를 찾지 못했어요.")
    losing_owner = row.role == "owner" and row.status == "active" and (
        body.role == "moderator" or body.status == "disabled")
    owners = db.scalar(select(func.count()).select_from(Operator).where(Operator.role == "owner",
                                                                        Operator.status == "active"))
    if losing_owner and owners <= 1:
        raise ApiError(409, "last_owner", "마지막 owner는 바꿀 수 없어요.")
    before = {"role": row.role, "status": row.status}
    if body.role:
        row.role = body.role
    if body.status and row.status != "invited":
        row.status = body.status
        if body.status == "disabled":
            ops.end_all_sessions(db, row.id)
    ops.audit(db, op, "operator_change", target=f"operator:{row.id}", reason=body.reason,
              before=before, after={"role": row.role, "status": row.status})
    db.commit()
    return ops.view(row)


# --- A-13 운영 기록 -------------------------------------------------------------------------------

@router.get("/audit")
def audit_log(op: Operator = Depends(owner), db: Session = Depends(get_db),
              start: datetime | None = Query(None, alias="from"), end: datetime | None = Query(None, alias="to"),
              operator: str | None = None, action: str | None = None,
              format: Literal["json", "csv"] = "json", limit: int = Query(500, ge=1, le=5000)):
    stmt = select(AdminAudit).order_by(AdminAudit.at.desc())
    if start:
        stmt = stmt.where(AdminAudit.at >= start)
    if end:
        stmt = stmt.where(AdminAudit.at < end)
    if operator:
        stmt = stmt.where(AdminAudit.operator_id == operator)
    if action:
        stmt = stmt.where(AdminAudit.action == action)
    rows = db.scalars(stmt.limit(limit)).all()
    items = [{"id": r.id, "at": iso(r.at), "operator": r.operator_email or "admin-token", "operator_id": r.operator_id,
              "action": r.action, "target": r.target, "reason": r.reason, "detail": r.detail} for r in rows]
    if format == "csv":
        out = io.StringIO()
        w = csv.writer(out)
        w.writerow(["at", "operator", "action", "target", "reason"])
        for i in items:
            w.writerow([i["at"], i["operator"], i["action"], i["target"] or "", i["reason"] or ""])
        return Response("﻿" + out.getvalue(), media_type="text/csv; charset=utf-8",
                        headers={"Content-Disposition": 'attachment; filename="youniya-audit.csv"'})
    return {"items": items}
