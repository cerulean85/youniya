# YOUNIYA operator console

The operator console (기획서 18장, Figma `Admin` page A-01~A-14), at admin.youniya.dycdyp.com once
deployed. A separate Next.js app and Vercel project: no code or cookies shared with the user web app
(`webapp/`), `noindex`, and its own `adm_*` cookies (httpOnly, SameSite=Strict).

```sh
npm install
npm run dev      # http://localhost:3100
npm run build && npm run lint
```

## API

It talks to `/v1/admin` in the shape the API Dev Session proposed (2026-11-09; built in its step 7):
operator sign-in with email, password and a TOTP code (`/v1/admin/auth/login`, `/auth/totp`, Bearer token,
5 misses lock 15 minutes), reports (`/v1/admin/reports`, `/reports/{kind}/{id}`, `/actions` with a required
reason) and the audit log (`/v1/admin/audit`). `lib/api.ts` is the only place that calls it.

Until the API exists the console runs on mock data (`lib/mock.ts`, in memory). It does so whenever
`YOUNIYA_API_URL` is unset, or with `ADMIN_MOCK=1`. Mock sign-in:

| Role | Email | Password | Code |
| --- | --- | --- | --- |
| owner | owner@youniya.test | mock-owner-pass | 123456 |
| moderator | moderator@youniya.test | mock-mod-pass | 123456 |

These only exist in the mock; the real console has operator accounts made on the server.

## Roles

Owners see everything. Moderators see 신고 처리, 별지기 and 문의 (`lib/nav.ts`); other pages send them to
`/forbidden`. Operators only ever see what the plaza shows: never unshared writing, starlight numbers or
telescope results.

## Done so far

A-01 sign-in, the sidebar, A-03 report list, A-04 report detail with actions (reason required), A-05 별지기
list (search by name or #번호, filters, CSV for owners), A-06 별지기 detail (counts, consents, sanctions; lift or
extend a restriction, ask for a new name, and for owners grant coins or process a deletion request), A-07 문의
(list and reply; masked email), A-13 audit log, and for owners A-02 대시보드, A-08 코인·결제 (App Store and
Toss in one ledger), A-09 AI 사용량·원가, A-10 별빛 측정 방식 (test first; 배포 stays off until the test passes),
A-11 초대 계정 (INVITE_LOGIN switch, new accounts with a one-time password, reseed the review account),
A-12 공지·점검 (maintenance mode, minimum iOS version, notices) and A-14 운영자·권한 (invite, change role, stop;
the last owner can't be removed). Every change asks for a reason.

The 별지기 and 문의 endpoints were proposed by the web side (2026-11-09): `GET /v1/admin/keepers?q=&filter=`
(`format=csv`), `GET /v1/admin/keepers/{id}`, `POST /v1/admin/keepers/{id}/actions {action, reason, amount?, days?}`,
`GET /v1/admin/inquiries?status=new|answered`, `GET /v1/admin/inquiries/{id}`, `POST /v1/admin/inquiries/{id}/reply
{body}`; shapes in `lib/types.ts`. The owner screens' endpoints (also proposed by the web side, not yet in
the API Dev Session's plan) are in `lib/api.ts`: `/v1/admin/dashboard`, `/coins`, `/ai`, `/prism` (`/test`,
`/deploy`), `/invites` (`/settings`, `/{id}`, `/{id}/reseed`), `/notices`, `/maintenance`, `/min-version`,
`/operators` (`/invite`, `/{id}`).

## Deploy

Not deployed yet. Plan: Vercel project `youniya-admin` (CLI deploys only, no Git connection), domain
`admin.youniya.dycdyp.com` (Route 53 CNAME), Vercel deployment protection or an IP allowlist on top of the
sign-in. Ask the user before connecting the domain or deploying.
