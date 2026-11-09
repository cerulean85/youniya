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

A-01 sign-in, the sidebar, A-03 report list, A-04 report detail with actions (reason required), A-13 audit
log. The other screens are placeholders that name their Figma frame.

## Deploy

Not deployed yet. Plan: Vercel project `youniya-admin` (CLI deploys only, no Git connection), domain
`admin.youniya.dycdyp.com` (Route 53 CNAME), Vercel deployment protection or an IP allowlist on top of the
sign-in. Ask the user before connecting the domain or deploying.
