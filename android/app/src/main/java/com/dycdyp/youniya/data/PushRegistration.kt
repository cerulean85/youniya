package com.dycdyp.youniya.data

import android.content.Context
import com.google.firebase.messaging.FirebaseMessaging
import kotlinx.coroutines.tasks.await
import kotlinx.serialization.Serializable

@Serializable
data class DeviceRegisterIn(
    val platform: String = "android",
    val token: String,
)

object PushRegistration {
    private const val PREFS_NAME = "youniya_push"
    private const val KEY_TOKEN = "fcm_token"

    fun getSavedToken(context: Context): String? {
        return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString(KEY_TOKEN, null)
    }

    fun saveToken(context: Context, token: String) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_TOKEN, token)
            .apply()
    }

    fun clearToken(context: Context) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .remove(KEY_TOKEN)
            .apply()
    }

    /**
     * FCM 토큰을 서버에 등록 (PUT /v1/me/devices).
     */
    suspend fun register(context: Context, api: ApiClient, explicitToken: String? = null) {
        if (!api.isSignedIn) return
        val token = explicitToken
            ?: getSavedToken(context)
            ?: runCatching { FirebaseMessaging.getInstance().token.await() }.getOrNull()
            ?: return

        saveToken(context, token)
        try {
            api.sendNoContent("PUT", "/v1/me/devices", DeviceRegisterIn(platform = "android", token = token))
            android.util.Log.i("PushRegistration", "device registered")
        } catch (e: Exception) {
            // Retried on the next launch or token refresh.
            android.util.Log.w("PushRegistration", "device registration failed: ${e.message}")
        }
    }

    /**
     * 로그아웃 / 계정 삭제 시 기기 토큰 해제 (DELETE /v1/me/devices/{token}).
     */
    suspend fun unregister(context: Context, api: ApiClient) {
        val token = getSavedToken(context) ?: return
        if (!api.isSignedIn) {
            clearToken(context)
            return
        }
        try {
            api.call("DELETE", "/v1/me/devices/$token", null, emptyMap(), authorized = true)
        } catch (_: Exception) {
        } finally {
            clearToken(context)
        }
    }
}
