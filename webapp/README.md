# YOUNIYA web app

The desktop web version of YOUNIYA, at https://app.youniya.dycdyp.com (Vercel project `youniya-app`).
Screens come from the Figma `YOUNIYA` file, Web page (W-10 onward). It talks to the same API as the
iOS app, https://youniya-api.dycdyp.com (`server/`).

The intro site and policies are a separate static site in `web/` (https://youniya.dycdyp.com).

## Run

```sh
npm install
npm run dev      # http://localhost:3000
npm run build && npm run lint
```

Next.js 16 with Cache Components (`next.config.ts`): anything that reads cookies sits behind a
`<Suspense>` boundary, and the bundled docs in `node_modules/next/dist/docs/` are the reference.

## Local development

Run the API from `server/` with `DEV_LOGIN=1` on port 8077 (8000 is often taken), and put this in
`webapp/.env.development.local` (gitignored):

```
YOUNIYA_API_URL=http://localhost:8077
DEV_LOGIN=1
```

The login page then shows a 테스트 로그인 form (`/auth/dev`). Production never sets `DEV_LOGIN`, so the
route is 404 there. Apple sign-in only works on app.youniya.dycdyp.com (Apple needs the HTTPS return URL).

## Deploy

```sh
vercel deploy --prod   # from this folder, linked to youniya-app
```

`app.youniya.dycdyp.com` is a Route 53 CNAME to Vercel (`dycdyp.com` zone).

## Plan

1. Foundation: design tokens, fonts, sidebar, page frames, login screen. **Done.**
2. Sign-in: Apple (redirect flow, `/auth/apple/start` → Apple → `/auth/apple/callback`, state and nonce
   checked) and Google (Google Identity Services button → `/auth/google`). The API verifies the ID tokens:
   `com.dycdyp.youniya.web` is in `APPLE_CLIENT_IDS` and the web client ID in `GOOGLE_CLIENT_IDS`.
   Tokens live in httpOnly cookies; `proxy.ts` refreshes them and sends signed-out visits to `/login`.
   **Done**, except Apple, which waits on the Services ID's return URL.
3. Home, writing (drafts in the database), floating, star detail: **done**. Records: next.
4. Plaza, nebulae, mind telescope, settings, contact, states.
5. Coins through Toss Payments: new server endpoints (order, confirm, webhook, refund) and the policy
   updates that come with a PG.
