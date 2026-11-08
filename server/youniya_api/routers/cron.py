"""Jobs Vercel Cron runs (server/vercel.json `crons`). Vercel calls each path with GET and
"Authorization: Bearer <CRON_SECRET>"; anything else gets the same 404 as an unknown path."""

import hmac

from fastapi import APIRouter, Depends, Header, Request
from sqlalchemy.orm import Session

from .. import coins
from ..deps import ApiError, get_db
from ..models import AdminLog


def vercel_cron(request: Request, authorization: str | None = Header(None)) -> None:
    secret = request.app.state.settings.cron_secret
    if not secret or not authorization or not hmac.compare_digest(f"Bearer {secret}", authorization):
        raise ApiError(404, "not_found", "찾지 못했어요.")


router = APIRouter(prefix="/v1/cron", tags=["cron"], dependencies=[Depends(vercel_cron)])


@router.get("/purge-purchase-records")
def purge_purchase_records(db: Session = Depends(get_db)):
    """Daily: deleted accounts' purchase records go once they are 5 years old (개인정보 처리방침 3)."""
    deleted = coins.purge_detached(db)
    db.add(AdminLog(action="cron_purge_purchase_records", target_id=str(deleted)))
    db.commit()
    return {"deleted": deleted}
