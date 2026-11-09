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

## 신고 (A-03·04)
- GET /v1/admin/reports?status=pending|hidden|done&kind=star|star_line|line|nickname
  → {items:[{id, kind, target_id, preview, reasons:{reason:n}, reports, first_reported_at, status}], counts:{pending, hidden, done}}
- GET /v1/admin/reports/{kind}/{target_id} → {kind, target_id, status, auto_hidden, content:{…public only, shared_at},
  keeper:{id, nickname}, reports:[{reporter_no, reason, at, note}], actions:[audit]}
- POST /v1/admin/reports/{kind}/{target_id}/actions {action: restore|take_down|request_rename|restrict_7d|restrict_30d|note,
  reason, note?} → {status, action_id}
- 18.3: personal_info / self_harm hide at the first report and push the operators (done in step 1); others at 3.

## 별지기 (A-05·06)
- GET /v1/admin/keepers?q=&filter=all|restricted|reported|invite → {items:[{id, no, nickname, joined_at, provider, stars,
  shared, reports, coins, status: active|restricted, restricted_until}]}; format=csv owner only (numbers only)
- GET /v1/admin/keepers/{id} → + {last_seen_at, star_counts:{lit, unlit}, consents:{terms_at, terms_version, sensitive_at,
  marketing:{opt_in, at}}, nickname_next_change, deletion_requested_at, history}
- POST /v1/admin/keepers/{id}/actions {action: lift_restriction|extend_restriction|request_rename|grant_coins|process_deletion,
  reason, amount? (1–10000), days? (7|30)}; moderator only the first three

## 문의 (A-07)
- GET /v1/admin/inquiries?status=new|answered → {items:[{id, kind, title, created_at, status}], counts:{new, answered}}
- GET /v1/admin/inquiries/{id} → {…, body, email_masked, keeper|null, app:{platform, version, device}|null,
  purchase:{transaction_id, status}|null, replies:[{at, operator, body}]}
- POST /v1/admin/inquiries/{id}/reply {body} → email to the address given, status answered

## 나머지 (shapes to propose when built)
- A-02 dashboard, A-08 coin ledger (App Store + Toss), A-09 AI usage/cost, A-10 prism versions and tests,
  A-11 invite accounts, A-12 notices/maintenance/min version, A-13 audit (CSV), A-14 operators and roles.
- Audit: GET /v1/admin/audit?from=&to=&operator=&format=json|csv → {items:[{at, operator, action, target, reason}]}
