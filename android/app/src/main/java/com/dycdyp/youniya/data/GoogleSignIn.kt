package com.dycdyp.youniya.data

import android.content.Context
import androidx.credentials.CredentialManager
import androidx.credentials.CustomCredential
import androidx.credentials.GetCredentialRequest
import androidx.credentials.exceptions.GetCredentialCancellationException
import androidx.credentials.exceptions.GetCredentialException
import com.google.android.libraries.identity.googleid.GetSignInWithGoogleOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential

/**
 * AN-02: Google with the Android account sheet (Credential Manager). The ID token's audience
 * is the web client the server already accepts (webapp/lib/config.ts GOOGLE_CLIENT_ID).
 */
object GoogleSignIn {
    private const val SERVER_CLIENT_ID = "226582034976-kek06qkl00oac39jtritop074grh6qte.apps.googleusercontent.com"

    sealed interface Result {
        data class Token(val idToken: String) : Result
        data object Cancelled : Result
        data class Failed(val why: String) : Result
    }

    suspend fun idToken(context: Context): Result {
        // The button flow ("Sign in with Google"): picks an account, or adds one when the phone has none.
        val option = GetSignInWithGoogleOption.Builder(SERVER_CLIENT_ID).build()
        val request = GetCredentialRequest.Builder().addCredentialOption(option).build()
        return try {
            val cred = CredentialManager.create(context).getCredential(context, request).credential
            if (cred is CustomCredential && cred.type == GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL) {
                Result.Token(GoogleIdTokenCredential.createFrom(cred.data).idToken)
            } else {
                Result.Failed("Google 계정 정보를 읽지 못했어요.")
            }
        } catch (e: GetCredentialCancellationException) {
            Result.Cancelled
        } catch (e: GetCredentialException) {
            Result.Failed("Google로 로그인하지 못했어요. 잠시 후 다시 시도해 주세요.")
        }
    }
}
