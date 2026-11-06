# YOUNIYA API

The server behind the YOUNIYA iOS app: stars, the starlight prism, the mind telescope, nebulae, coins and the plaza.

The screens come from the Figma `YOUNIYA` file (Mobile page). The scoring engine, data policy and coin rules come from the Protoss specs (`~/apps/protoss`).

## How YOUNIYA maps to Protoss

| YOUNIYA (screen) | Protoss (spec) |
| :--- | :--- |
| 별 띄우기 → 별빛 프리즘 (06, 07) | 심리 펀칭 머신 (`psy-punch-machine/design.md`) |
| 별빛 0–999 | 타격 점수 0–999 |
| 별의 깊이 · 빛의 선명함 · 마음의 무게 | 직면 깊이(400) · 명명 정확도(300) · 귀인 소유권(300) |
| 깊이 N단계 | 경험 깊이 7단계 |
| 초신성 (별빛 900 이상) | CRITICAL HIT (900–999) |
| 조용히 간직하기 | 드롭 모드 |
| 마음 망원경 (10, 24–27, 88) | 인지 레이더 (`psy-cognitive-radar`) |
| 성운 · 성운 이야기 (51–55, 70, 83) | 서사 돔 (`psy-narrative-dome`) |
| 우주 광장 · 공명 | 광장 · 공명(Echo) |

The prism keeps the Protoss pipeline:

1. Pre-validation
2. Safety interlock
3. Three independent model calls
4. The median of each measure
5. `min(999, D + N + O)`

YOUNIYA-only rules come from the screens and `ios/Youniya/App/AppModel.swift`:

- 1,000 characters to float a star.
- Floating a star is free.
- The telescope costs 30 coins, and the first one is free.
- Story polish costs 20 coins.
- 별빛 한 줄 is 60 characters, one per nebula, and fades after a day.

## Run

```sh
uv venv .venv && uv pip install --python .venv/bin/python -r pyproject.toml --extra dev

export JWT_SECRET=$(python -c "import secrets; print(secrets.token_urlsafe(48))")
export DATA_ENCRYPTION_KEY=$(python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())")
.venv/bin/alembic upgrade head
.venv/bin/uvicorn --factory youniya_api.main:create_app --reload
```

The API docs are served at `http://localhost:8000/docs`.

### Database and migrations

- **Schema:** The schema comes only from the Alembic migrations in `migrations/`. The server does not create tables.
- **Upgrading:** Run `.venv/bin/alembic upgrade head` before starting. `dev.sh` does this for you.
- **Changing a model:** Add a migration with `.venv/bin/alembic revision --autogenerate -m "…"` and review it. A test fails when the models and the migrations disagree.
- **Postgres URLs:** `postgresql://` URLs (Neon gives these) use psycopg 3. Prepared statements are off and connections are pinged, so a transaction pooler like Neon's works.
- **Quoting:** In `.env`, quote a URL that contains `&`.

### Development server

For the app on another machine, `./dev.sh` serves on every interface at port 8000.
- On its first run it writes `server/.env` with fresh secrets. Keep that file: without it the stored stars can't be read.
- It turns on `DEV_LOGIN` and `TRUST_PURCHASES`.
- With `DEV_LOGIN=1`, `POST /v1/auth/dev {"name": "…"}` signs in without Apple or Google. The same name is always the same account.
- To keep it running across reboots, install `deploy/youniya-api.service` as a systemd user service. The steps are in the file.

### Development and production

The two never share a database or secrets.

| | Development (this Linux machine) | Production (Vercel) |
| :--- | :--- | :--- |
| Settings | `server/.env` | `server/.env.production`, copied into Vercel's environment variables |
| Database | Neon `dev` branch | Neon main branch |
| `DEV_LOGIN`, `TRUST_PURCHASES` | on | never |
| `MIN_APP_VERSION` | `0.1` | `1.0.0` |

Both files are gitignored. Keep a copy of the production `DATA_ENCRYPTION_KEY` somewhere safe.

### Deploying to Vercel

- **Project:** Set the Vercel project's root directory to `server`. `api/index.py` is the entry point and `vercel.json` sends every path to it. Dependencies come from `requirements.txt`, which a test keeps equal to `pyproject.toml`.
- **Environment:** Copy every variable from `.env.production` into the Vercel project. `APPSTORE_PRIVATE_KEY_PATH` is not needed there.
- **Migrations:** Vercel never runs them. Before a deploy that adds a migration, run `deploy/migrate-production.sh` here.
- **Time limit:** `maxDuration` is 120 seconds, for the three model calls per star once the real model is on.

The same spec is checked in as [`openapi.json`](openapi.json) for the iOS side. A test fails when it falls behind the code; refresh it with `.venv/bin/python -m tests.dump_openapi`.

Run the tests with `.venv/bin/python -m pytest`. They need no API key or network.

### Environment

| Variable | Default | Meaning |
| :--- | :--- | :--- |
| `JWT_SECRET` | (required, 32+ chars) | Signs access tokens |
| `DATA_ENCRYPTION_KEY` | (required) | Fernet key. Writing, analyses and inquiries are encrypted at rest. **Losing it loses every star.** |
| `DATABASE_URL` | `sqlite:///./youniya.db` | SQLite or Postgres (`postgresql://…`, e.g. Neon) |
| `GEMINI_API_KEY` | (none) | Without it, a deterministic offline evaluator stands in (Protoss mock mode) |
| `PRISM_MODEL` | `gemini-2.5-flash` | Star scoring (fast, called 3× per star) |
| `TELESCOPE_MODEL` | `gemini-2.5-pro` | Telescope reports and story polish |
| `PRISM_SAMPLES` | `3` | Independent scoring calls per star |
| `APPLE_CLIENT_IDS`, `GOOGLE_CLIENT_IDS` | (none) | Comma-separated audiences for Sign in with Apple / Google |
| `MIN_APP_VERSION` | `1.0.0` | Below this, requests with `X-App-Version` get 426 (40) |
| `MAINTENANCE_START`, `MAINTENANCE_END` | (none) | ISO times; without an offset they are read as KST. Every request gets 503 in between (41) |
| `APPLE_BUNDLE_ID` | (none) | The app's bundle id. Required for verified coin purchases; without it purchases are refused |
| `APPSTORE_ISSUER_ID`, `APPSTORE_KEY_ID`, `APPSTORE_PRIVATE_KEY_PATH` | (none) | App Store Server API key (`.p8`). Used to answer CONSUMPTION_REQUEST refund requests. Without it they go unanswered, and Apple decides alone |
| `APPSTORE_PRIVATE_KEY_BASE64` | (none) | The same `.p8` file (whole PEM) as one base64 line (`base64 -w0 AuthKey_XXX.p8`), for hosts without files such as Vercel. Used instead of `APPSTORE_PRIVATE_KEY_PATH` when set |
| `ALLOW_SANDBOX_PURCHASES` | `1` | Accept sandbox transactions. App Review and TestFlight buy in the sandbox, so keep this on in production |
| `ADMIN_TOKEN` | (none) | `X-Admin-Token` for `/v1/admin`. Without it the operator API answers 404 |
| `TRUST_PROXY` | on when `VERCEL=1` | Take the caller's IP from `X-Forwarded-For` for per-IP limits. Only behind a proxy that sets it |
| `TRUST_PURCHASES` | off | `1` adds coins from `product_id` + `transaction_id` without a store. **Development only** |

## Conventions

- **Authentication:** `Authorization: Bearer <access token>`. Access tokens last 1 hour. Refresh tokens last 30 days and rotate on every use.
- **Consent:** Every endpoint that stores or reads writing requires the 11 consent first (`403 consent_required`).
- **Errors:** `{"error": {"code": "...", "message": "..."}}`. The message is Korean copy the app can show as is.
- **Times:** ISO 8601 in UTC. Months, calendar days and "tonight" follow Korean time.

## Endpoints

| Area | Endpoints | Screens |
| :--- | :--- | :--- |
| App | `GET /v1/app/status` | 40, 41 |
| Auth | `POST /v1/auth/{apple,google}`, `/refresh`, `/logout` | 02, 39 |
| Account | `GET /v1/me`, `POST /v1/me/consent`, `PATCH /v1/me/settings`, `DELETE /v1/me`, `GET /v1/me/export?format=text\|pdf`, `GET·DELETE /v1/me/shares`, `POST /v1/inquiries` | 11, 87, 91–94, 113, 114, 32 |
| Stars | `POST /v1/stars` (`mode: float \| keep`), `GET /v1/stars` (`state`, `mood`, `q`, `month`, `before`), `GET /v1/stars/summary`, `GET·DELETE /v1/stars/{id}`, `POST /v1/stars/{id}/float` | 05, 07, 12–16, 36, 104, 105, 115–119 |
| Draft | `GET·PUT·DELETE /v1/drafts/current` | 34 |
| Growth | `GET /v1/starlight/trend`, `GET /v1/growth` | 08, 65, 66, 82, 86, 109 |
| Telescope | `GET /v1/telescope/offer`, `POST·GET /v1/telescope/reports`, `GET /v1/telescope/reports/{id}`, `POST …/save` | 10, 24–27, 29, 88, 98 |
| Coins | `GET /v1/coins`, `GET /v1/coins/history`, `POST /v1/coins/purchases` | 28, 33, 38, 102, 108 |
| Nebulae | `POST·GET /v1/nebulae`, `GET /v1/nebulae/guest-candidates`, `GET /v1/nebulae/{id}`, `GET /v1/nebulae/{id}/story`, `POST …/story/polish`, `PUT·DELETE …/share` | 51–55, 70, 71, 80, 83–85, 96 |
| Refunds | `POST /v1/storekit/notifications` (App Store Server Notifications V2 URL) | — |
| Operator | `GET /v1/admin/reports`, `POST /v1/admin/lines/{id}/hide·restore`, `GET /v1/admin/inquiries`, `GET /v1/admin/logs` | — |
| Plaza | `POST /v1/plaza/privacy-scan`, `PUT·DELETE /v1/stars/{id}/share`, `GET /v1/plaza/stars[/{id}]`, `GET /v1/plaza/nebulae[/{id}]`, `PUT·DELETE /v1/plaza/{star\|nebula}/{id}/resonance` and `…/beside`, `GET·POST /v1/plaza/nebulae/{id}/lines`, `POST /v1/plaza/lines/{id}/report`, `GET /v1/plaza/tonight` | 09, 19–22, 55, 69, 72–75, 79, 99–101, 103, 106, 107 |

### Behaviour worth knowing

- **Floating a star** (`POST /v1/stars`, `mode: float`):
  - Text under 1,000 characters gets `422 too_short` and nothing is stored, so the app keeps the draft (104).
  - If the model fails, the star is stored as kept with `analysis_failed: true`, and `POST /v1/stars/{id}/float` retries it (36).
- **Crisis signals:** The writing is saved as written, but it is never scored or shared. The response carries `crisis` with the 109 line (37).
- **Coins:** Charged only after a result exists. A failed report or polish charges nothing (Protoss 4.4). The balance never goes below zero, even with requests racing.
- **Buying coins** (`POST /v1/coins/purchases`):
  - Send `{"signed_transaction": transaction.jwsRepresentation}` after a verified StoreKit 2 purchase, then call `transaction.finish()` once the server answers 200.
  - Buy with `appAccountToken` set to the user id from `GET /v1/me`. A transaction bought for another account is refused.
  - The server checks the certificate chain up to the pinned Apple Root CA - G3, the Apple purpose OIDs, the signature, the bundle id, revocation, and that the product is a consumable.
  - The App Store Connect product ids must be the package keys: `coin_50`, `coin_120` and `coin_300`. `quantity` multiplies the coins.
  - The same transaction never pays twice. A retry answers `already_processed: true`.
  - Send `"consumption_consent": true` when the buyer saw and accepted the 28 notice ("쓴 코인은 환불되지 않아요. 환불을 요청하면 코인 사용 내역이 앱 스토어에 전달돼요."). It is stored per purchase.
- **Refund requests** (CONSUMPTION_REQUEST, Figma 46 policy):
  - A refund can be asked within 7 days of purchase. It is granted only if taking back the purchase's coins leaves the balance at 0 or more.
  - For a purchase with consent, the server sends Send Consumption Information V2 to Apple.
  - `refundPreference` is `GRANT_FULL` within 7 days when balance ≥ coins received, and `DECLINE` otherwise.
  - `consumptionPercentage` is the share actually used, in milli-percent: received − min(received, balance), divided by received.
  - Without consent, nothing is sent; Apple requires that.
  - If Apple refunds anyway, the REFUND rule applies: the coins left are taken back, and the balance stops at 0.
- **Quotes:** Every sentence shown back to the user (impact quote, evidence, signals, story) is checked to appear unchanged in their writing.
- **Plaza:**
  - A shared star carries only the one masked sentence its owner chose. A shared nebula carries only its outline, colours, depth and an optional masked sentence.
  - Others never see scores, ranks or 공명 counts. Owners see their counts in `GET /v1/me/shares`.
  - A line someone reports disappears for them at once. Three reports hide it for everyone.
- **Refunds:** A REFUND notification takes that purchase's coins back once, even below zero (the coins were already spent).
- **Rate limits:** `429 rate_limited` with `retry_after` seconds. Limits per user, per hour: floating a star 30, telescope 10, story polish 10, lines 30, reports 30, purchases 30, inquiries 5. The privacy scan allows 60 per minute, and sign-in allows 30 per minute per IP. Counters live in the database (`rate_hits`), so every server instance counts together.
- **Operator API:** Every operator read or action is written to `admin_logs` (Protoss 3장).
- **PDF:** The export embeds NanumGothic (SIL OFL, `youniya_api/fonts/OFL.txt`), so Korean renders anywhere.

## Not done yet

- **Real model:** The server has not been connected to the real model (`GEMINI_API_KEY`). The Protoss reliability protocol (`design.md` 6장) has not been run yet.
