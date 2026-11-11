package com.dycdyp.youniya.data

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import kotlinx.serialization.Serializable
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

@Serializable
data class AuthSession(
    val accessToken: String,
    val refreshToken: String,
    val userId: String,
    val needsConsent: Boolean,
)

/**
 * Keeps the API session on this device only (iOS: Keychain, this-device-only).
 * The JSON is sealed with an AES-GCM key that lives in the Android Keystore; backups exclude it.
 */
class TokenStore(context: Context) {
    private val prefs = context.getSharedPreferences("session", Context.MODE_PRIVATE)

    fun load(): AuthSession? = runCatching {
        val sealed = prefs.getString(KEY, null) ?: return null
        val bytes = Base64.decode(sealed, Base64.NO_WRAP)
        val cipher = Cipher.getInstance(TRANSFORM)
        cipher.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, bytes, 0, 12))
        val json = cipher.doFinal(bytes, 12, bytes.size - 12).decodeToString()
        ApiJson.decodeFromString(AuthSession.serializer(), json)
    }.getOrNull()

    fun save(session: AuthSession?) {
        if (session == null) {
            prefs.edit().remove(KEY).apply()
            return
        }
        val cipher = Cipher.getInstance(TRANSFORM)
        cipher.init(Cipher.ENCRYPT_MODE, key())
        val body = cipher.doFinal(ApiJson.encodeToString(AuthSession.serializer(), session).encodeToByteArray())
        prefs.edit().putString(KEY, Base64.encodeToString(cipher.iv + body, Base64.NO_WRAP)).apply()
    }

    private fun key(): SecretKey {
        val ks = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (ks.getEntry(ALIAS, null) as? KeyStore.SecretKeyEntry)?.let { return it.secretKey }
        val gen = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        gen.init(
            KeyGenParameterSpec.Builder(ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .build()
        )
        return gen.generateKey()
    }

    private companion object {
        const val KEY = "sealed"
        const val ALIAS = "youniya_session"
        const val TRANSFORM = "AES/GCM/NoPadding"
    }
}
