package com.dycdyp.youniya.data

import android.content.Context
import android.net.Uri
import android.util.Base64
import androidx.browser.customtabs.CustomTabsIntent
import com.dycdyp.youniya.BuildConfig
import java.security.MessageDigest
import java.security.SecureRandom

/**
 * AN-02-1 Sign in with Apple on Android (docs/server-contracts-5b-6.md): the server's Apple web
 * flow in a Custom Tab with PKCE, back to the app on `youniya://auth/apple?code=…&purpose=…`.
 * The verifier waits in prefs, since the app's process can die while the tab is open.
 */
object AppleSignIn {
    enum class Purpose(val wire: String) { SignIn("signin"), Delete("delete") }

    /** What came back on the deep link. */
    sealed interface Return {
        data class Code(val purpose: Purpose, val code: String, val verifier: String) : Return
        data class Failed(val purpose: Purpose, val cancelled: Boolean) : Return
    }

    private const val PREFS = "youniya_apple"
    private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun start(context: Context, purpose: Purpose) {
        val bytes = ByteArray(48).also { SecureRandom().nextBytes(it) }
        val verifier = b64url(bytes)  // 64 chars of [A-Za-z0-9_-]
        val challenge = b64url(MessageDigest.getInstance("SHA-256").digest(verifier.toByteArray(Charsets.US_ASCII)))
        prefs(context).edit().putString(purpose.wire, verifier).apply()
        val url = Uri.parse(BuildConfig.API_BASE_URL + "/v1/auth/apple/web/start").buildUpon()
            .appendQueryParameter("code_challenge", challenge)
            .appendQueryParameter("code_challenge_method", "S256")
            .appendQueryParameter("purpose", purpose.wire)
            .apply {
                // The dev server has no Apple Services ID; its DEV_LOGIN skips Apple for a dev account
                // (sign-in only), to try the deep link and the exchange.
                if (BuildConfig.DEBUG && purpose == Purpose.SignIn) appendQueryParameter("dev_name", BuildConfig.DEV_NAME)
            }
            .build()
        CustomTabsIntent.Builder().setShowTitle(true).build().launchUrl(context, url)
    }

    /** null when [uri] is not the Apple return link. */
    fun handle(context: Context, uri: Uri?): Return? {
        if (uri == null || uri.scheme != "youniya" || uri.host != "auth" || uri.path != "/apple") return null
        val purpose = Purpose.entries.firstOrNull { it.wire == uri.getQueryParameter("purpose") } ?: Purpose.SignIn
        val verifier = prefs(context).getString(purpose.wire, null)
        prefs(context).edit().remove(purpose.wire).apply()
        val code = uri.getQueryParameter("code")
        if (code.isNullOrEmpty() || verifier == null) {
            return Return.Failed(purpose, cancelled = uri.getQueryParameter("error") == "cancelled")
        }
        return Return.Code(purpose, code, verifier)
    }

    private fun b64url(b: ByteArray) = Base64.encodeToString(b, Base64.URL_SAFE or Base64.NO_PADDING or Base64.NO_WRAP)
}
