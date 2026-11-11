# Server contracts for Android 5b/6 (from the API Dev Session, 2026-11-11)

Dev server only (100.126.111.107:8000); production deploy waits for the user's approval.

## Google Play coins — POST /v1/coins/purchases
Request: {"platform":"android","product_id":"coin_110|coin_330|coin_1100","purchase_token":"…","order_id":"GPA.…"}
- obfuscatedAccountId = GET /v1/me `id`.
- 200: {"coins": balance, "added": n, "already_processed": bool, "consumed": bool}
  - consumed false → the app calls consumeAsync itself (coins are already given).
  - Sending the same purchase again: added 0, already_processed true, consume retried → safe to resend
    unprocessed purchases from queryPurchases at launch.
- Errors: 422 purchase_invalid · 409 purchase_pending (send again when done) · 409 transaction_used ·
  422 unknown_product · 503 purchase_unverified (no coins; send again later).
- Dev (TRUST_PURCHASES=1): {"platform":"android","product_id":…,"order_id":"any"} without purchase_token
  is credited without Google and returns consumed false. With purchase_token → 503 until Play is set up.
- Refunds: the server checks Voided Purchases daily (App Store rules). /v1/coins/history source "google_play",
  refunds kind "refund".

## FCM
- PUT /v1/me/devices {"platform":"android","token":"<FCM token as is>"} → 204 ([A-Za-z0-9_:-] 32–512).
- DELETE /v1/me/devices/{token} → 204 on sign-out.
- Message: notification {title, body}; data {"kind": "report_result|announcement|notice|consent_result|test",
  "target": "<JSON string, optional>"} (same object as iOS target, e.g. {"screen":"star","star_id":…});
  android.priority high. Inbox GET /v1/me/notifications unchanged. No sending until the FCM key is set.

## Apple sign-in on Android (Custom Tab + PKCE)
1. code_verifier 43–128 chars [A-Za-z0-9._~-]; code_challenge = base64url(sha256(verifier)), no padding.
2. Custom Tab: GET /v1/auth/apple/web/start?code_challenge=…&code_challenge_method=S256&purpose=signin|delete
3. Back to the app: youniya://auth/apple?code=…&purpose=… or youniya://auth/apple?error=cancelled|failed&purpose=…
   (register this deep link).
4. signin: POST /v1/auth/apple/exchange {"code","code_verifier"} → same as POST /v1/auth/apple
   {access_token, refresh_token, user_id, needs_consent}; 400 handoff_invalid (wrong/used/2 min/verifier) → start over.
5. delete: purpose=delete, then DELETE /v1/me {"apple_handoff_code","apple_handoff_verifier"} → 204;
   400 apple_reauth_required keeps the account.
- Dev: …/web/start?code_challenge=…&dev_name=NAME skips Apple and returns a dev account's code (signin only).
  Real Apple only after the production deploy (APPLE_SERVICES_ID; 404 before it).
