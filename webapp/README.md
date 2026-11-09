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

Point the app at the dev API on home-desktop (over Tailscale; it has `DEV_LOGIN=1` and gets new endpoints
first) in `webapp/.env.development.local` (gitignored):

```
YOUNIYA_API_URL=http://100.126.111.107:8000
DEV_LOGIN=1
```

Or run `server/` yourself with `DEV_LOGIN=1` and use its address.

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
   **Done** (both checked on production, 2026-11-08).
3. Home, writing (drafts in the database), floating, star detail, records (list, search, filters,
   calendar): **done**.
4. Plaza stars (grid, new or similar, the other person's star with resonance, keep beside, report
   with optional block, block; sharing one masked sentence from a star): **done**.
   Nebulae: my nebula (W-41, W-42 before the first), detail with the story (sentences only; 서사 다듬기 was removed 2026-11-08), sharing to the
   sky, drawing (W-27 flow), reshaping (W-43 with PATCH), plaza nebula tab and another person's nebula
   with 별빛 한 줄: **done**. Drawn like iOS NebulaFigure (`lib/nebula.ts`).
   Next: mind telescope, coins, settings, contact, states.
   Nebula rules (server, 2026-11-08): at least 3 floated stars (the next button stays off until then;
   subtitle "N개 골랐어요 · 3개 이상이면 돼요"), names up to 20 characters, and `PATCH /v1/nebulae/{id}`
   reshapes a drawn nebula (`plaza_updated` when it is shared). Mobile designs: 08-1, 08-2, 84-2; ask the Figma session for the desktop version.
   Writing rules: a star floats from 50 characters (`MIN_FLOAT_LENGTH`); `PATCH /v1/stars/{id}` edits
   (a floated star's mood is fixed: 409 `mood_fixed`); `POST /v1/stars/{id}/float` floats a kept star.
5. Coins through Toss Payments: new server endpoints (order, confirm, webhook, refund) and the policy
   updates that come with a PG.

## 2026-11-09 plan (기획서 16–17장)

1. Terms, sidebar, removed screens. **Done.**
2. Writing (several moods), 별빛 받기 / 별빛 없이 띄우기, result (W-24), 별빛 풀이. **Done.**
3. Monthly constellations (`lib/constellation.ts`, 12 shapes from Figma), 별자리 이야기, home preview. Stars fill
   slots in date order on the web until `GET /v1/constellations` ships. **Done.**
4. Star detail: 마음 망원경 inside it (W-54, one-star report), 이어진 별 chips (`linked_stars`, cut with ×),
   별 잇기 (W-47; new writing with `link_to`, or pick written stars: W-51 list, W-52 calendar, W-53 preview,
   `POST /v1/stars/{id}/links`), 고쳐 쓰기 (`/write?rewrite=`, W-46, `rewrite_of`; its draft carries
   `source_star_id`), stars without starlight (W-32, W-56 confirm, `POST /v1/stars/{id}/starlight`, 글 수정 W-33
   with PATCH), 내보내기 as a text file. A lit star's writing and moods are locked; its title isn't. **Done.**
5. Plaza, nickname, 별빛 한 줄.
6. Settings and intro-site wording.

