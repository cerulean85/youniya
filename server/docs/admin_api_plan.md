# 관리자 API 계획 (7단계, 기획서 18장 · Figma Admin A-01~A-14)

The console (admin.youniya.dycdyp.com, webapp `admin/lib/api.ts`, types in `admin/lib/types.ts`)
is built against these shapes with mock data. Agreed with the Web Dev Session, 2026-11-09.

## 원칙 (18.1)
- Operators never see unshared writing, starlight numbers or telescope results; only what the plaza shows and operating data.
- Every action needs a reason, notifies the keeper by app notice, and goes to an append-only audit log kept 1 year.
- Operator accounts by invitation only; password + TOTP; 5 failures → 15 min lock. Roles owner | moderator.
- moderator may: reports (restore, take down, rename request, plaza restriction), keeper detail and restriction, inquiry replies.
  moderator may not: grant coins, prism version tests/deploys, invite accounts, maintenance/min version, deletion requests, operators.
- The current ADMIN_TOKEN API keeps working for a while alongside.

## 인증
- POST /v1/admin/auth/login {email, password} → {challenge}
- POST /v1/admin/auth/totp {challenge, code} → {token, expires_at, operator:{id, email, role}}; then Authorization: Bearer
- 423 locked {until}; 401 → sign in again; 403 forbidden_role; POST /v1/admin/auth/logout
- Built (step 7-1): also GET /v1/admin/auth/me; 401 invalid_credentials | challenge_expired | invalid_code
  (with a fresh `challenge`) | session_expired. Sessions last 12 hours; a TOTP code works once.
- Invitation: POST /v1/admin/operators/invite {email, role, reason} → {operator, setup_token, expires_at} (3 days,
  shown once; no email yet, the console shows a link). POST /v1/admin/auth/setup {invite_token, password (12+)}
  → {totp_secret, otpauth_uri}; POST /v1/admin/auth/setup/confirm {invite_token, code} → operator (active).
  The first owner: tools/admin_operator.py invite EMAIL.
- GET /v1/admin/operators → {items:[{id, email, role, status, totp, last_seen_at, created_at}]};
  PATCH /v1/admin/operators/{id} {role?, status?: active|disabled, reason} (409 last_owner; disabling ends sessions).
- GET /v1/admin/audit?from=&to=&operator=&action=&format=json|csv → {items:[{id, at, operator, operator_id, action,
  target, reason, detail}]} (owner). No route changes or deletes it.
- The ADMIN_TOKEN header still works, as an owner. Existing /v1/admin routes: reports, lines/shares actions and
  inquiries are for both roles; status, push-test, error-test, announcements and logs are owner-only.

## 신고 (A-03·04)
- GET /v1/admin/reports?status=pending|hidden|done&kind=star|star_line|line|nickname
  → {items:[{id, kind, target_id, preview, reasons:{reason:n}, reports, first_reported_at, status}], counts:{pending, hidden, done}}
- GET /v1/admin/reports/{kind}/{target_id} → {kind, target_id, status, auto_hidden, content:{…public only, shared_at},
  keeper:{id, nickname}, reports:[{reporter_no, reason, at, note}], actions:[audit]}
- POST /v1/admin/reports/{kind}/{target_id}/actions {action: restore|take_down|request_rename|restrict_7d|restrict_30d|note,
  reason, note?} → {status, action_id}
- 18.3: personal_info / self_harm hide at the first report and push the operators (done in step 1); others at 3.

- Built (step 7-2): kinds star | nebula | line (성운 한 줄) | star_line (별에 남긴 한 줄) | nickname (target = the
  keeper's user id; from star reports with reason "nickname"). Status: done once every report is answered,
  else hidden (auto_hidden: true) or pending. take_down/restore answer the reporters by push; request_rename,
  take_down and restrict_* tell the keeper. 422 wrong_action for take_down/restore on a nickname.
  Plaza restriction: users.plaza_restricted_until → 403 plaza_restricted {until} on sharing, 공명, 곁에 두기 and
  별빛 한 줄; writing is not restricted. A rename request lifts the 30-day wait (/v1/me nickname_rename_required).

## 별지기 (A-05·06)
- GET /v1/admin/keepers?q=&filter=all|restricted|reported|invite → {items:[{id, no, nickname, joined_at, provider, stars,
  shared, reports, coins, status: active|restricted, restricted_until}]}; format=csv owner only (numbers only)
- GET /v1/admin/keepers/{id} → + {last_seen_at, star_counts:{lit, unlit}, consents:{terms_at, terms_version, sensitive_at,
  marketing:{opt_in, at}}, nickname_next_change, deletion_requested_at, history}
- POST /v1/admin/keepers/{id}/actions {action: lift_restriction|extend_restriction|request_rename|grant_coins|process_deletion,
  reason, amount? (1–10000), days? (7|30)}; moderator only the first three

- Built (step 7-2): `no` is users.keeper_no (numbered in joining order); last_seen_at updates at most every
  10 minutes; terms_version and deletion_requested_at are null (no such records yet). process_deletion keeps
  store purchase records detached for 5 years, as a keeper's own deletion does.

## 문의 (A-07)
- GET /v1/admin/inquiries?status=new|answered → {items:[{id, kind, title, created_at, status}], counts:{new, answered}}
- GET /v1/admin/inquiries/{id} → {…, body, email_masked, keeper|null, app:{platform, version, device}|null,
  purchase:{transaction_id, status}|null, replies:[{at, operator, body}]}
- POST /v1/admin/inquiries/{id}/reply {body} → email to the address given, status answered
- Built (step 7-2): mail through Resend (RESEND_API_KEY, MAIL_FROM); without the key 503 mail_unavailable, a
  refusal 502 mail_failed, and nothing is marked answered. `app` comes from X-App-Platform, X-App-Version and
  X-Device-Model on POST /v1/inquiries; `purchase` is the latest store purchase of a payment inquiry.

## owner 화면 (A-02, A-08~A-12, A-14; owner only, every change needs a reason; console f7d29f4)
- GET /v1/admin/dashboard?range=today|week|month
- GET /v1/admin/coins?month= — App Store, Toss and operator grants in one ledger
- GET /v1/admin/ai?month= — per feature calls, tokens, cost, cache hits, failure rate (ai_usage: prism_reading
  attempts/failures since 20261109), members over the ₩2,000 alert
- GET /v1/admin/prism · POST /v1/admin/prism/{key}/test · POST /v1/admin/prism/{key}/deploy (409 before a passed test;
  the test is tools/compare_prism.py and costs model calls)
- GET /v1/admin/invites · PUT /v1/admin/invites/settings {enabled} · POST /v1/admin/invites {login_id, memo} → {password}
  (shown once) · PATCH /v1/admin/invites/{id} {enabled} · POST /v1/admin/invites/{id}/reseed
- GET /v1/admin/notices · PUT /v1/admin/maintenance {on} · PUT /v1/admin/min-version {ios} · POST /v1/admin/notices
- GET /v1/admin/operators · POST /v1/admin/operators/invite {email, role} · PATCH /v1/admin/operators/{id} {role|status}
  (409 for the last owner)
- Built (step 7-3, routers/admin_owner.py):
  - dashboard → {range, since, stars:{lit, unlit, total}, new_keepers, reports_pending, inquiries_new,
    ai_cost_month_krw, crisis_stars (a count only), alerts:[{kind, target_id, at}], payments:{count, coins, krw_estimate}}
  - coins?month= → {month, totals:{purchase|refund|grant|spend: {count, coins, krw_estimate}}, items:[{id, at, kind,
    source: app_store|server, keeper_no, title, coins, transaction_id, krw_estimate}]}. krw_estimate is the package
    price; Toss comes with web payments.
  - ai?month= → {month, total_krw, features:[{feature: prism|prism_reading|telescope|monthly_report, requests, calls,
    krw, krw_per_request, avg_input_tokens, avg_output_tokens, cache_hit_rate, attempts, failures, failure_rate}],
    alert_krw, over_alert:[{user_id, keeper_no, nickname, krw, calls}]}. Counted from 20261109.
  - prism → {current, versions:[{key, stars, first_at, last_at, status}], tests:[…], limits}. POST …/test and …/deploy
    are 409 manual_only: a test calls the model ~120 times (tools/compare_prism.py --record) and a version ships
    with the code.
  - invites → {enabled, items:[{id, login_id, memo, enabled, created_at, last_seen_at, keeper_no, stars}]};
    PUT invites/settings {enabled, reason}; POST invites {login_id, memo, reason} → … + password (once);
    PATCH invites/{login_id} {enabled?, reset_password?, reason} (→ password when reset); POST …/reseed is
    409 manual_only (tools/seed_review.py --reset).
  - notices → {maintenance:{on, start, end}, min_version:{ios}, items:[{id, title, body, publish_at, push, pushed_at,
    created_by, created_at, published}]}; PUT maintenance {on, until?, reason} (default two hours; operators and
    cron pass); PUT min-version {ios, reason}; POST notices {title, body, publish_at?, push?, reason} (push only when
    it is published now). The app reads GET /v1/notices. These live in the database (runtime_settings) over the
    environment, read through a 20-second cache.
- Audit: GET /v1/admin/audit?from=&to=&operator=&format=json|csv → {items:[{at, operator, action, target, reason}]}
