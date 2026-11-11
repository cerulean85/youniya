package com.dycdyp.youniya.data

import android.os.Build
import com.dycdyp.youniya.BuildConfig
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.KSerializer
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonNamingStrategy
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.serializer
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.IOException
import java.util.concurrent.TimeUnit

/** snake_case JSON like the server and iOS (`keyDecodingStrategy = .convertFromSnakeCase`). */
@OptIn(ExperimentalSerializationApi::class)
val ApiJson = Json {
    namingStrategy = JsonNamingStrategy.SnakeCase
    ignoreUnknownKeys = true
    explicitNulls = false
    encodeDefaults = true
    coerceInputValues = true
}

/** The server's `{"error": {"code", "message", …}}`; `message` is Korean copy that can be shown as is. */
class ApiError(
    val status: Int,
    val code: String,
    override val message: String,
    val until: String? = null,
    val retryAfter: Int? = null,
    val starId: String? = null,
) : Exception(message) {
    companion object {
        fun offline() = ApiError(0, "offline", "서버에 연결하지 못했어요. 잠시 후 다시 시도해 주세요.")
        fun badResponse() = ApiError(0, "bad_response", "응답을 읽지 못했어요.")
        fun signedOut() = ApiError(401, "signed_out", "다시 로그인해 주세요.")
    }
}

@Serializable
private data class ErrorEnvelope(val error: Body, val starId: String? = null) {
    @Serializable
    data class Body(val code: String, val message: String, val until: String? = null, val retryAfter: Int? = null, val starId: String? = null)
}

@Serializable private data class RefreshIn(val refreshToken: String)

/**
 * Talks to the YOUNIYA API (iOS APIClient): Bearer access tokens refreshed once on
 * 401 `token_expired`; the refresh token rotates on every use, so the new one is always saved.
 */
class ApiClient(private val store: TokenStore) {
    private val http = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(60, TimeUnit.SECONDS)
        .build()
    private val baseUrl = BuildConfig.API_BASE_URL
    private val refreshLock = Mutex()

    @Volatile var session: AuthSession? = store.load()
        private set

    /** Called when the session ends on the server's side (refresh refused). */
    var onSignedOut: () -> Unit = {}

    val isSignedIn get() = session != null

    fun store(s: AuthSession?) {
        session = s
        store.save(s)
    }

    suspend inline fun <reified T> get(path: String, query: Map<String, String> = emptyMap()): T =
        decode(serializer(), call("GET", path, null, query, authorized = true))

    suspend inline fun <reified B, reified T> send(method: String, path: String, body: B, authorized: Boolean = true): T =
        decode(serializer(), call(method, path, ApiJson.encodeToString(serializer<B>(), body), emptyMap(), authorized))

    suspend inline fun <reified B> sendNoContent(method: String, path: String, body: B, authorized: Boolean = true) {
        call(method, path, ApiJson.encodeToString(serializer<B>(), body), emptyMap(), authorized)
    }

    fun <T> decode(s: KSerializer<T>, text: String): T =
        try { ApiJson.decodeFromString(s, text.ifEmpty { "{}" }) } catch (e: Exception) { throw ApiError.badResponse() }

    suspend fun call(method: String, path: String, body: String?, query: Map<String, String>, authorized: Boolean, retried: Boolean = false): String {
        val token = if (authorized) (session?.accessToken ?: throw ApiError.signedOut()) else null
        val (status, text) = raw(method, path, body, query, token)
        if (status in 200..299) return text
        val err = parseError(status, text)
        if (authorized && status == 401 && err.code == "token_expired" && !retried) {
            refresh(token)
            return call(method, path, body, query, authorized, retried = true)
        }
        throw err
    }

    private suspend fun refresh(staleAccess: String?) = refreshLock.withLock {
        // Another request may already have refreshed while this one waited.
        if (session?.accessToken != staleAccess) return@withLock
        val refresh = session?.refreshToken ?: throw ApiError.signedOut()
        val (status, text) = raw("POST", "/v1/auth/refresh", ApiJson.encodeToString(RefreshIn.serializer(), RefreshIn(refresh)), emptyMap(), null)
        if (status in 200..299) {
            store(decode(AuthSession.serializer(), text))
        } else {
            store(null)
            onSignedOut()
            throw ApiError(401, "token_expired", "다시 로그인해 주세요.")
        }
    }

    private suspend fun raw(method: String, path: String, body: String?, query: Map<String, String>, token: String?): Pair<Int, String> =
        withContext(Dispatchers.IO) {
            val url = (baseUrl + path).toHttpUrl().newBuilder().apply { query.forEach { (k, v) -> addQueryParameter(k, v) } }.build()
            val req = Request.Builder().url(url)
                .header("Accept", "application/json")
                .header("X-App-Version", BuildConfig.VERSION_NAME)
                .header("X-App-Platform", "android")
                .header("X-Device-Model", "${Build.MANUFACTURER} ${Build.MODEL}")
                .apply { if (token != null) header("Authorization", "Bearer $token") }
                .method(method, body?.toRequestBody(JSON) ?: if (method == "GET" || method == "DELETE") null else "{}".toRequestBody(JSON))
                .build()
            try {
                http.newCall(req).execute().use { it.code to (it.body.string()) }
            } catch (e: IOException) {
                throw ApiError.offline()
            }
        }

    private fun parseError(status: Int, text: String): ApiError = runCatching {
        val e = ApiJson.decodeFromString(ErrorEnvelope.serializer(), text)
        ApiError(status, e.error.code, e.error.message, e.error.until, e.error.retryAfter, e.error.starId ?: e.starId)
    }.getOrElse { ApiError(status, "http_$status", "잠시 후 다시 시도해 주세요.") }

    private companion object {
        val JSON = "application/json".toMediaType()
    }
}

@Suppress("unused") private typealias Raw = JsonObject
