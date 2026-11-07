from datetime import datetime, timezone

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from sqlalchemy.orm import sessionmaker

from .config import Settings
from .db import make_engine
from .deps import ApiError
from .monitoring import init_sentry
from .prism import PrismEngine
from .push import ApnsClient
from .ratelimit import RateLimiter
from .routers import account, admin, auth, coins, nebulae, plaza, stars, telescope
from .security import Cipher, IdTokenVerifier
from .storekit import AppStoreClient, StoreKitVerifier


def _version(v: str) -> tuple[int, ...]:
    return tuple(int(p) for p in v.split(".") if p.isdigit())


def in_maintenance(settings: Settings, at: datetime | None = None) -> bool:
    start, end = settings.maintenance_start, settings.maintenance_end
    at = at or datetime.now(timezone.utc)
    return bool(start and end and start <= at < end)


def create_app(settings: Settings | None = None) -> FastAPI:
    settings = settings or Settings()
    if len(settings.jwt_secret) < 32 or not settings.data_key:
        raise RuntimeError("JWT_SECRET (32+ characters) and DATA_ENCRYPTION_KEY must be set")

    init_sentry(settings.sentry_dsn, settings.sentry_environment)

    # The schema comes from the migrations (`alembic upgrade head`), not from here.
    engine = make_engine(settings.database_url)

    app = FastAPI(title="YOUNIYA API", version="0.1.0")
    app.state.settings = settings
    app.state.sessions = sessionmaker(engine, expire_on_commit=False)
    app.state.cipher = Cipher(settings.data_key)
    app.state.limiter = RateLimiter(app.state.sessions)
    app.state.verifier = IdTokenVerifier({"apple": settings.apple_client_ids, "google": settings.google_client_ids})
    app.state.storekit = (StoreKitVerifier(settings.apple_bundle_id, settings.allow_sandbox_purchases)
                          if settings.apple_bundle_id else None)
    appstore_key = settings.appstore_private_key()
    app.state.appstore = (
        AppStoreClient(settings.appstore_issuer_id, settings.appstore_key_id, appstore_key, settings.apple_bundle_id)
        if settings.apple_bundle_id and settings.appstore_issuer_id and settings.appstore_key_id and appstore_key
        else None)
    apns_key = settings.apns_private_key()
    app.state.push = (ApnsClient(settings.apns_team_id, settings.apns_key_id, apns_key, settings.apple_bundle_id)
                      if settings.apple_bundle_id and settings.apns_team_id and settings.apns_key_id and apns_key
                      else None)
    app.state.prism = PrismEngine(settings.gemini_api_key, settings.prism_model, settings.prism_samples,
                                  thinking=settings.prism_thinking)

    @app.exception_handler(ApiError)
    async def api_error(_: Request, e: ApiError):
        headers = {"Retry-After": str(e.extra["retry_after"])} if "retry_after" in e.extra else None
        return JSONResponse({"error": {"code": e.code, "message": e.message, **e.extra}}, status_code=e.status,
                            headers=headers)

    @app.exception_handler(RequestValidationError)
    async def invalid(_: Request, e: RequestValidationError):
        return JSONResponse(
            {"error": {"code": "invalid_request", "message": "요청 형식이 올바르지 않아요.",
                       "details": jsonable_errors(e)}},
            status_code=422,
        )

    @app.middleware("http")
    async def app_gate(request: Request, call_next):
        if request.url.path != "/v1/app/status":
            # 41 잠시 점검 중이에요
            if in_maintenance(settings):
                return JSONResponse({"error": {"code": "maintenance", "message": "잠시 점검 중이에요.",
                                               "until": settings.maintenance_end.isoformat()}}, status_code=503)
            # 40 새 버전이 필요해요
            version = request.headers.get("x-app-version")
            if version and _version(version) < _version(settings.min_app_version):
                return JSONResponse({"error": {"code": "update_required", "message": "새 버전이 필요해요."}},
                                    status_code=426)
        return await call_next(request)

    @app.get("/v1/app/status", tags=["app"])
    def status(version: str | None = None):
        return {
            "min_version": settings.min_app_version,
            "update_required": bool(version and _version(version) < _version(settings.min_app_version)),
            "maintenance": {"start": settings.maintenance_start.isoformat(), "end": settings.maintenance_end.isoformat()}
            if settings.maintenance_start and settings.maintenance_end else None,
            "in_maintenance": in_maintenance(settings),
        }

    for router in (auth.router, account.router, stars.router, telescope.router, coins.router, coins.notifications,
                   nebulae.router, plaza.router, admin.router):
        app.include_router(router)
    return app


def jsonable_errors(e: RequestValidationError) -> list[dict]:
    return [{"loc": list(err["loc"]), "msg": err["msg"]} for err in e.errors()]
