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

- 50 characters to float a star (1,000 until 20261108).
- Floating a star is free once a Korean day, then 5 coins.
- The telescope costs 20 coins; one a month and one at sign-up are free.
- 성운 이야기 is free: each star's sentence in time order. 서사 다듬기 was removed on 20261108.
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

- **Project:** Set the Vercel project's root directory to `server`. `index.py` is the entry point; Vercel detects it and routes every request to its `app`, with the path unchanged (no rewrites). Dependencies come from `requirements.txt`, which a test keeps equal to `pyproject.toml`.
- **Environment:** Copy every variable from `.env.production` into the Vercel project. `APPSTORE_PRIVATE_KEY_PATH` is not needed there.
- **Migrations:** Vercel never runs them. Before a deploy that adds a migration, run `deploy/migrate-production.sh` here.
- **Time limit:** `maxDuration` is 120 seconds, for the three model calls per star once the real model is on.
- **Error reports:** With `SENTRY_DSN` set, unhandled errors go to Sentry without any writing (`youniya_api/monitoring.py`). `POST /v1/admin/error-test` sends one on purpose.

### Backups

- **Daily copy:** The user timer `youniya-backup.timer` (04:00 KST, from `deploy/`) runs `deploy/backup-production.sh` on home-desktop. It writes every table of the production database as CSV from one snapshot to `~/backups/youniya/`, keeping 14. A failure is reported to Sentry.
- **Install:** `cp deploy/youniya-backup.* ~/.config/systemd/user/ && systemctl --user enable --now youniya-backup.timer`.
- **Restore:** Create an empty database, run `alembic upgrade <revision in meta.json>`, then `python tools/backup_db.py restore <url> <archive>`. `check` restores into a scratch schema and compares every row without touching the data.
- **Key:** Writing stays encrypted in the copy. Without the same `DATA_ENCRYPTION_KEY` a restore cannot be read.

The same spec is checked in as [`openapi.json`](openapi.json) for the iOS side. A test fails when it falls behind the code; refresh it with `.venv/bin/python -m tests.dump_openapi`.

Run the tests with `.venv/bin/python -m pytest`. They need no API key or network.

### Environment

| Variable | Default | Meaning |
| :--- | :--- | :--- |
| `JWT_SECRET` | (required, 32+ chars) | Signs access tokens |
| `DATA_ENCRYPTION_KEY` | (required) | Fernet key. Writing, analyses and inquiries are encrypted at rest. **Losing it loses every star.** |
| `DATABASE_URL` | `sqlite:///./youniya.db` | SQLite or Postgres (`postgresql://…`, e.g. Neon) |
| `GEMINI_API_KEY` | (none) | Without it, a deterministic offline evaluator stands in (Protoss mock mode) |
| `PRISM_MODEL` | `gemini-3.8-flash` | Star scoring |
| `TELESCOPE_MODEL` | `gemini-3.8-flash` | Telescope reports (no Pro: 20261107 experiment) |
| `TELESCOPE_THINKING` | `low` | Thinking level for telescope reports (`off`, `low`, `high`; empty: the model's default) |
| `FREE_STARS_PER_DAY` | `1` | Free 별 띄우기 per Korean day; after that each costs 5 coins |
| `PRISM_SAMPLES` | `1` | Scoring calls per star (one, tried again once; with 3 the median is used) |
| `PRISM_THINKING` | `low` | Gemini 3 thinking level for scoring; empty = model default (about twice as slow) |
| `APPLE_CLIENT_IDS`, `GOOGLE_CLIENT_IDS` | (none) | Comma-separated audiences for Sign in with Apple / Google |
| `MIN_APP_VERSION` | `1.0.0` | Below this, requests with `X-App-Version` get 426 (40) |
| `MAINTENANCE_START`, `MAINTENANCE_END` | (none) | ISO times; without an offset they are read as KST. Every request gets 503 in between (41) |
| `APPLE_BUNDLE_ID` | (none) | The app's bundle id. Required for verified coin purchases; without it purchases are refused |
| `APPSTORE_ISSUER_ID`, `APPSTORE_KEY_ID`, `APPSTORE_PRIVATE_KEY_PATH` | (none) | App Store Server API key (`.p8`). Used to answer CONSUMPTION_REQUEST refund requests. Without it they go unanswered, and Apple decides alone |
| `APPSTORE_PRIVATE_KEY_BASE64` | (none) | The same `.p8` file (whole PEM) as one base64 line (`base64 -w0 AuthKey_XXX.p8`), for hosts without files such as Vercel. Used instead of `APPSTORE_PRIVATE_KEY_PATH` when set |
| `APNS_TEAM_ID`, `APNS_KEY_ID`, `APNS_PRIVATE_KEY_BASE64` (or `_PATH`) | (none) | APNs auth key (Keys › Apple Push Notifications service), a different key from the In-App Purchase one. Topic is `APPLE_BUNDLE_ID`. Without it no remote notification is sent, and everything else works |
| `ALLOW_SANDBOX_PURCHASES` | `1` | Accept sandbox transactions. App Review and TestFlight buy in the sandbox, so keep this on in production |
| `ADMIN_TOKEN` | (none) | `X-Admin-Token` for `/v1/admin`. Without it the operator API answers 404 |
| `CRON_SECRET` | (none) | Vercel Cron's bearer secret for `/v1/cron/*` (Vercel adds it to cron requests when the variable is set). Without it those routes are 404 |
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
| Auth | `POST /v1/auth/{apple,google}`, `POST /v1/auth/invite` (`INVITE_LOGIN=1`), `/refresh`, `/logout` | 02, 39 |
| Account | `GET /v1/me`, `POST /v1/me/consent`, `PATCH /v1/me/settings`, `PUT /v1/me/devices`, `DELETE /v1/me/devices/{token}`, `DELETE /v1/me`, `GET /v1/me/export?format=text\|pdf`, `GET·DELETE /v1/me/shares`, `POST /v1/inquiries` | 11, 87, 91–94, 113, 114, 32 |
| Stars | `POST /v1/stars` (`mode: float \| keep`), `GET /v1/stars` (`state`, `mood`, `q`, `month`, `before`), `GET /v1/stars/summary`, `GET·PATCH·DELETE /v1/stars/{id}`, `POST /v1/stars/{id}/float` (a kept star, later) | 05, 07, 12–16, 36, 104, 105, 115–119 |
| Draft | `GET·PUT·DELETE /v1/drafts/current` | 34 |
| Growth | `GET /v1/starlight/trend`, `GET /v1/growth` (`stage` 0 below 12 stars, then 1–4) | 08, 65, 66, 82, 86, 109 |
| Telescope | `GET /v1/telescope/offer`, `POST·GET /v1/telescope/reports`, `GET /v1/telescope/reports/{id}`, `POST …/save` | 10, 24–27, 29, 88, 98 |
| Coins | `GET /v1/coins`, `GET /v1/coins/history`, `POST /v1/coins/purchases` | 28, 33, 38, 102, 108 |
| Nebulae | `POST·GET /v1/nebulae`, `GET /v1/nebulae/guest-candidates`, `GET·PATCH /v1/nebulae/{id}` (다시 그리기: same checks as drawing; a shared one updates its plaza snapshot unless a star carries a crisis signal), `GET /v1/nebulae/{id}/story`, `PUT·DELETE …/share` | 51–55, 70, 71, 80, 83–85, 96 |
| Refunds | `POST /v1/storekit/notifications` (App Store Server Notifications V2 URL) | — |
| Operator | `GET /v1/admin/status`, `POST /v1/admin/push-test`, `POST /v1/admin/error-test`, `POST /v1/admin/announcements`, `GET /v1/admin/reports`, `POST /v1/admin/lines/{id}/hide·restore`, `GET /v1/admin/inquiries`, `GET /v1/admin/logs` | — |
| Blocks | `POST·GET /v1/blocks`, `DELETE /v1/blocks/{id}` | 87-3, 100 |
| Plaza | `POST /v1/plaza/privacy-scan`, `PUT·DELETE /v1/stars/{id}/share`, `GET /v1/plaza/stars[/{id}]`, `GET /v1/plaza/nebulae[/{id}]`, `PUT·DELETE /v1/plaza/{star\|nebula}/{id}/resonance` and `…/beside`, `GET·POST /v1/plaza/nebulae/{id}/lines`, `POST /v1/plaza/lines/{id}/report`, `POST /v1/plaza/{star|nebula}/{id}/report`, `GET /v1/plaza/tonight` | 09, 19–22, 55, 69, 72–75, 79, 99–101, 103, 106, 107 |

### Behaviour worth knowing

- **Floating a star** (`POST /v1/stars`, `mode: float`):
  - Text under 50 characters gets `422 too_short` and nothing is stored, so the app keeps the draft (104).
  - If the model fails, the star is stored as kept with `analysis_failed: true`, and `POST /v1/stars/{id}/float` retries it (36).
  - `PATCH /v1/stars/{id}` (글 수정) takes any of `title`, `body`, `mood`. A floated star keeps its mood (`409 mood_fixed`), shape, starlight, analysis and reports; nothing is read again or charged. Plaza shares keep the sentence copied when shared. The crisis check runs again; stars carry `updated_at` (null until edited).
- **Crisis signals:** The writing is saved as written, but it is never scored or shared. The response carries `crisis` with the 109 line (37).
- **Prices and free uses** (1 coin = 10 KRW): floating a star is free once a Korean day, then 5 coins (keeping is always free). The telescope costs 20 coins, free once a calendar month (no carry-over) plus once at sign-up. `GET /v1/me` and `GET /v1/coins` show `free_star_today` and `free_telescope`; a float or report answers `charged` and `coins`. Products on sale: `coin_110` (1,100원), `coin_330` (3,300원), `coin_1100` (9,900원, 100 bonus). `coin_50`, `coin_120` and `coin_300` are no longer listed but are still accepted and refunded.
- **Coins:** Charged only after a result exists. A failed report charges nothing (Protoss 4.4). The balance never goes below zero, even with requests racing.
- **Buying coins** (`POST /v1/coins/purchases`):
  - Send `{"signed_transaction": transaction.jwsRepresentation}` after a verified StoreKit 2 purchase, then call `transaction.finish()` once the server answers 200.
  - Buy with `appAccountToken` set to the user id from `GET /v1/me`. A transaction bought for another account is refused.
  - The server checks the certificate chain up to the pinned Apple Root CA - G3, the Apple purpose OIDs, the signature, the bundle id, revocation, and that the product is a consumable.
  - The App Store Connect product ids must be the package keys: `coin_110`, `coin_330` and `coin_1100` (the older `coin_50`, `coin_120`, `coin_300` are still accepted). `quantity` multiplies the coins.
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
  - One filter for both lists: `GET /v1/plaza/stars?sort=` and `GET /v1/plaza/nebulae?filter=` take `new`, `similar` or `beside`. `beside` lists what I kept 곁에, the most recently kept first, under the same block and hiding rules.
  - A line, star or nebula someone reports disappears for them at once. Three reports hide it for everyone until an operator restores it (`POST /v1/admin/shares/{star|nebula}/{id}/hide|restore`).
  - **Blocks** (App Store 1.2): `POST /v1/blocks` with one of `line_id`, `star_id` or `nebula_id` (the plaza share id) blocks whoever wrote it, also via `"block": true` on a report. Hiding goes both ways: neither sees the other's shares or lines anywhere. `GET /v1/blocks` lists when and where, never who.
- **별지기 멤버십** (v1.1, `MEMBERSHIP=1`; off by default, and then every membership API is 404 and `/v1/me` says nothing of it):
  - Products `membership_monthly` (2,900원) and `membership_yearly` (29,000원), one auto-renewable group with a 7-day trial. `POST /v1/membership/verify {signedTransaction}` after a purchase or restore; App Store Server Notifications keep it current (SUBSCRIBED, DID_RENEW, DID_CHANGE_RENEWAL_STATUS, DID_FAIL_TO_RENEW grace, EXPIRED, GRACE_PERIOD_EXPIRED, REFUND, REVOKE).
  - A member has 10 floats and 10 telescope reports a Korean day, used before the free ones everybody has, then coins; every sky; and a 월간 마음 리포트 (one a month, never remade): `GET /v1/reports/monthly[/{YYYY-MM}]`, `POST /v1/reports/monthly {month?}` (5 stars floated that month). `deploy/youniya-monthly.timer` makes last month's daily from 06:00 KST, so a failed one is tried again the next day.
  - Skies from v1.0: `violet` and `ocean` for everyone; another sky is `403 member_only`, and a member sky shows as `violet` once the membership ends.
- **AI cost:** every model call is priced from its usageMetadata and added to the account's month (`ai_costs`, KRW). Over 2,000원 in a month, an `ai_cost_over` operator log and an error to Sentry, once.
- **Context caching** (`youniya_api/ai_cache.py`): prompts go fixed part first, then the user's part. On gemini-3.8-flash the implicit cache needs 4,096 input tokens, which no feature reaches; an explicit cache needs 1,024, which only the prism's fixed part has (2,774 tokens). After 10 requests in an hour a feature gets an explicit cache for an hour, extended while requests keep coming; a refused or expired cache falls back to a full request. Measured 20261107: prism 7.6 → 4.8원 a star, storage 2.1원 an hour.
- **Invite accounts** (App Review): `tools/invite.py create LOGIN` makes one (argon2id, the password printed once); `POST /v1/auth/invite {login, password}` signs in when `INVITE_LOGIN=1`, 10 tries a minute per IP, the same `401 invalid_credentials` for a wrong login or password. `tools/seed_review.py` fills a review account and the plaza.
- **Deleting an account** (`DELETE /v1/me`, 91): everything goes at once, except the store purchase and refund rows of `coin_entries` (those with a `transaction_id`). They stay with `user_id` NULL for 5 years (전자상거래법; 개인정보 처리방침 3), so a late REFUND or CONSUMPTION_REQUEST is still answered and the same transaction can't pay a new account. Vercel Cron (`crons` in `vercel.json`, 20:00 UTC = 05:00 KST daily) calls `GET /v1/cron/purge-purchase-records`, which deletes them once they are 5 years old (`coins.purge_detached`) and writes an `admin_logs` row with the count. Vercel sends `Authorization: Bearer $CRON_SECRET`; without `CRON_SECRET` the `/v1/cron` routes are 404. `deploy/purge-purchase-records.sh --dry-run` counts the same rows by hand.
- **Refunds:** A REFUND notification takes that purchase's coins back once. Only the coins left are taken: the balance stops at 0 (기획서 11.6).
- **Notifications:** The server sends two kinds through APNs, and never puts writing or analyses in them.
  - **101 신고 결과:** When an operator hides or restores a reported line (`POST /v1/admin/lines/{id}/hide|restore`), each reporter is told once. The line is not quoted.
  - **새 기능·혜택 알림:** `POST /v1/admin/announcements` (dry run by default) goes only to users with `marketing_opt_in`. The title gets `(광고)`, the body ends with how to opt out, and nothing is sent 21:00–08:00 KST (정보통신망법 50조).
  - **Checking a phone:** `POST /v1/admin/push-test {"user_id"}` sends "시험 알림" to that user's devices and returns what APNs answered for each (`devices: []` means the app has not registered). `GET /v1/admin/status` shows whether APNs is set up.
  - **87 별 만들기 알림** is a local notification the app schedules itself; the server only keeps the `star_reminder` setting.
  - The app registers its token with `PUT /v1/me/devices` (`environment`: `sandbox` for Xcode debug builds, `production` for TestFlight and the App Store) and removes it with `DELETE /v1/me/devices/{token}` before signing out. Payloads carry `kind` (`report_result` or `announcement`). Dead tokens are dropped when APNs says so.
- **Rate limits:** `429 rate_limited` with `retry_after` seconds. Limits per user, per hour: floating a star 30, telescope 10, lines 30, reports 30, purchases 30, inquiries 5. The privacy scan allows 60 per minute, and sign-in allows 30 per minute per IP. Counters live in the database (`rate_hits`), so every server instance counts together.
- **Operator API:** Every operator read or action is written to `admin_logs` (Protoss 3장).
- **PDF:** The export embeds NanumGothic (SIL OFL, `youniya_api/fonts/OFL.txt`), so Korean renders anywhere.

## Not done yet

- **Reliability protocol:** `tools/eval_prism.py` runs a scaled-down `design.md` 6장 (22 texts, passed 20261107). The full protocol (30 texts × 20 runs, two human raters on 100 texts) has not been run. The check texts are a few hundred characters; real stars can be as short as 50 characters.
