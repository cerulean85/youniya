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

## Deploy

```sh
vercel deploy --prod   # from this folder, linked to youniya-app
```

`app.youniya.dycdyp.com` is a Route 53 CNAME to Vercel (`dycdyp.com` zone).

## Plan

1. Foundation: design tokens, fonts, sidebar, page frames, login screen. **Done.**
2. Sign-in: Apple and Google on the web. The server already verifies ID tokens against
   `APPLE_CLIENT_IDS` and `GOOGLE_CLIENT_IDS`, so the web Services ID and web client ID only need to be
   added there. Tokens live in httpOnly cookies; API calls go through the Next.js server.
3. Home, writing (drafts in the database), floating, star detail, records.
4. Plaza, nebulae, mind telescope, settings, contact, states.
5. Coins through Toss Payments: new server endpoints (order, confirm, webhook, refund) and the policy
   updates that come with a PG.
