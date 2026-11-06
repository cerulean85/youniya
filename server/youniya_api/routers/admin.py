"""Operator API: reported 별빛 한 줄 and inquiries. Every call is written to admin_logs."""

import hmac
from typing import Literal

from fastapi import APIRouter, Depends, Header, Request
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from ..deps import ApiError, get_cipher, get_db
from ..models import AdminLog, Inquiry, LineReport, NebulaShare, StarlightLine
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


@router.get("/reports")
def reported_lines(db: Session = Depends(get_db)):
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
    _log(db, "list_reports")
    return {"items": sorted(items, key=lambda i: -i["reports"])}


@router.post("/lines/{line_id}/{action}")
def moderate_line(line_id: str, action: Literal["hide", "restore"], db: Session = Depends(get_db)):
    line = db.get(StarlightLine, line_id)
    if line is None:
        raise ApiError(404, "not_found", "별빛을 찾지 못했어요.")
    line.hidden = action == "hide"
    _log(db, f"{action}_line", line_id)
    return {"line_id": line_id, "hidden": line.hidden}


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
