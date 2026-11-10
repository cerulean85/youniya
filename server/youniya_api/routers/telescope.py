"""마음 망원경: removed (2026-11-10, 기획서 19장). Every old path answers 410 feature_removed, and nothing is
charged or used up. Reports already made stay in the database: they are in 93 내보내기 and go with the account.
(The 월간 마음 리포트 still uses youniya_api/telescope.py; that is not this feature.)"""

from fastapi import APIRouter

from ..deps import ApiError

router = APIRouter(prefix="/v1/telescope", tags=["telescope"])


@router.api_route("/{path:path}", methods=["GET", "POST", "PUT", "PATCH", "DELETE"], include_in_schema=False)
def removed(path: str):
    raise ApiError(410, "feature_removed", "마음 망원경은 이제 없어요. 코인과 무료 횟수는 그대로예요.")
