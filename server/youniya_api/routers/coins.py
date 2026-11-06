"""28 코인 충전, 102 충전 완료, 38 결제 미완료, 33/108 코인 사용 내역."""

from fastapi import APIRouter, Depends, Request
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.orm import Session

from .. import coins
from ..deps import ApiError, consented_user, get_db
from ..models import CoinEntry, User
from ..rules import COIN_PACKAGES
from ..storekit import PurchaseInvalid
from ..views import iso

router = APIRouter(prefix="/v1/coins", tags=["coins"])


class PurchaseIn(BaseModel):
    # StoreKit 2 `Transaction.jwsRepresentation`. Buy with `appAccountToken` = the user id.
    signed_transaction: str | None = Field(None, max_length=20000)
    # Development only (TRUST_PURCHASES=1), without a store.
    product_id: str | None = None
    transaction_id: str | None = Field(None, max_length=128)


@router.get("")
def balance(user: User = Depends(consented_user)):
    return {
        "coins": user.coins,
        "free_telescope_available": not user.free_telescope_used,
        "packages": [{"product_id": k, **v} for k, v in COIN_PACKAGES.items()],
    }


@router.get("/history")
def history(user: User = Depends(consented_user), db: Session = Depends(get_db)):
    rows = db.scalars(select(CoinEntry).where(CoinEntry.user_id == user.id)
                      .order_by(CoinEntry.created_at.desc())).all()
    return {"items": [{"id": r.id, "title": r.title, "delta": r.delta, "created_at": iso(r.created_at)}
                      for r in rows]}


@router.post("/purchases")
def purchase(body: PurchaseIn, request: Request, user: User = Depends(consented_user),
             db: Session = Depends(get_db)):
    verifier = request.app.state.storekit
    if body.signed_transaction and verifier:
        try:
            tx = verifier.verify(body.signed_transaction)
        except PurchaseInvalid:
            raise ApiError(422, "purchase_invalid", "결제를 확인하지 못했어요. 코인은 지급되지 않았어요.")
        token = tx.get("appAccountToken")
        if token and token.lower() != user.id:
            raise ApiError(409, "transaction_used", "이미 처리된 결제예요.")
        product_id, transaction_id, quantity = tx["productId"], str(tx["transactionId"]), int(tx.get("quantity", 1))
    elif request.app.state.settings.trust_purchases and body.product_id and body.transaction_id:
        product_id, transaction_id, quantity = body.product_id, body.transaction_id, 1
    else:
        # 38 결제가 끝나지 않았어요: nothing is added until the store confirms it.
        raise ApiError(503, "purchase_unverified", "결제를 확인하지 못했어요. 코인은 지급되지 않았어요.")

    package = COIN_PACKAGES.get(product_id)
    if package is None:
        raise ApiError(422, "unknown_product", "알 수 없는 상품이에요.")
    # Retried requests for the same store transaction add coins once.
    seen = db.scalar(select(CoinEntry).where(CoinEntry.transaction_id == transaction_id))
    if seen:
        if seen.user_id != user.id:
            raise ApiError(409, "transaction_used", "이미 처리된 결제예요.")
        return {"coins": user.coins, "added": 0, "already_processed": True}
    added = package["coins"] * quantity
    coins.add(db, user, added, "코인 충전", transaction_id=transaction_id)
    db.commit()
    return {"coins": user.coins, "added": added, "already_processed": False}
