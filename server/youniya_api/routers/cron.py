"""Jobs Vercel Cron runs (server/vercel.json `crons`). Vercel calls each path with GET and
"Authorization: Bearer <CRON_SECRET>"; anything else gets the same 404 as an unknown path."""

import hmac
import logging
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, Header, Request
from sqlalchemy import delete
from sqlalchemy.orm import Session

from .. import coins, marketing
from ..deps import ApiError, get_db
from ..google_api import PlayPurchaseInvalid, PlayUnavailable
from ..models import AdminLog, AuthHandoff, UserNotification


def vercel_cron(request: Request, authorization: str | None = Header(None)) -> None:
    secret = request.app.state.settings.cron_secret
    if not secret or not authorization or not hmac.compare_digest(f"Bearer {secret}", authorization):
        raise ApiError(404, "not_found", "찾지 못했어요.")


log = logging.getLogger(__name__)

router = APIRouter(prefix="/v1/cron", tags=["cron"], dependencies=[Depends(vercel_cron)])


@router.get("/marketing-reconfirm")
def marketing_reconfirm(request: Request, db: Session = Depends(get_db)):
    """Daily: users whose 새 기능·혜택 알림 consent turned two years old hear that it is still on (14.3)."""
    sent = marketing.remind_due(db, request.app.state.push)
    db.add(AdminLog(action="cron_marketing_reconfirm", target_id=str(sent)))
    db.commit()
    return {"reminded": sent}


@router.get("/purge-purchase-records")
def purge_purchase_records(request: Request, db: Session = Depends(get_db)):
    """Daily: deleted accounts' purchase records go once they are 5 years old (개인정보 처리방침 3).
    Also takes back Google Play refunds (Voided Purchases API)."""
    deleted = coins.purge_detached(db)
    db.add(AdminLog(action="cron_purge_purchase_records", target_id=str(deleted)))
    # 알림함 keeps 90 days.
    gone = db.execute(delete(UserNotification).where(
        UserNotification.created_at < datetime.now(timezone.utc) - timedelta(days=90))).rowcount
    db.add(AdminLog(action="cron_purge_notifications", target_id=str(gone)))
    db.execute(delete(AuthHandoff).where(AuthHandoff.expires_at < datetime.now(timezone.utc) - timedelta(days=1)))
    db.commit()
    # Google Play refunds ride on this daily job (the hobby plan allows two crons).
    refunded = None
    play = request.app.state.play
    if play is not None:
        try:
            refunded = coins.take_back_play_voided(db, play)
            db.add(AdminLog(action="cron_play_refunds", target_id=str(refunded)))
            db.commit()
        except (PlayPurchaseInvalid, PlayUnavailable):
            log.exception("checking Google Play refunds failed")
    return {"deleted": deleted, "play_refunds": refunded}
