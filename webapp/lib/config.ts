export const API_URL = process.env.YOUNIYA_API_URL ?? "https://youniya-api.dycdyp.com";
export const SITE_URL = "https://youniya.dycdyp.com";
/** /auth/dev and the test sign-in form exist only where DEV_LOGIN=1 (local development). */
export const DEV_LOGIN = process.env.DEV_LOGIN === "1";

/** Web sign-in. Neither is secret: they name the app to Google and Apple. The API must list them in
 * GOOGLE_CLIENT_IDS / APPLE_CLIENT_IDS. */
export const GOOGLE_CLIENT_ID = "226582034976-kek06qkl00oac39jtritop074grh6qte.apps.googleusercontent.com";
export const APPLE_SERVICES_ID = "com.dycdyp.youniya.web";
/** Apple only accepts the registered HTTPS return address, so Apple sign-in works on this host only. */
export const APPLE_REDIRECT_URI = "https://app.youniya.dycdyp.com/auth/apple/callback";
