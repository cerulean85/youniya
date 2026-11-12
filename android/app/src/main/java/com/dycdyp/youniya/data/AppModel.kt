package com.dycdyp.youniya.data

import android.app.Application
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.launch
import kotlinx.serialization.Serializable

@Serializable
data class Me(
    val id: String,
    val provider: String = "",
    val joinedAt: String? = null,
    val needsConsent: Boolean = false,
    val marketingOptIn: Boolean = false,
    val coins: Int = 0,
    val freeStarToday: Int = 0,
    val nickname: String? = null,
    val nicknameNextChange: String? = null,
    val nicknameRenameRequired: Boolean = false,
    val plazaRestrictedUntil: String? = null,
    val settings: MeSettings? = null,
)

/** The synced settings in /v1/me (the reminder's time stays on the device, as on iOS). */
@Serializable
data class MeSettings(
    val reduceAnimations: Boolean = false,
    val starReminder: Boolean = false,
    val sky: String = "violet",
)

@Serializable private data class IdTokenIn(val idToken: String)
@Serializable private data class AppleExchangeIn(val code: String, val codeVerifier: String)
@Serializable private data class DeleteMeIn(val appleHandoffCode: String, val appleHandoffVerifier: String)
@Serializable private data class DevIn(val name: String)
@Serializable private data class InviteIn(val login: String, val password: String)
@Serializable private data class ConsentIn(val terms: Boolean = true, val privacy: Boolean = true, val sensitive: Boolean = true, val marketing: Boolean)
@Serializable private data class ConsentOut(val needsConsent: Boolean, val marketingOptIn: Boolean = false)
@Serializable private data class NicknameCheck(val available: Boolean, val reason: String? = null, val message: String? = null)
@Serializable private data class NicknameIn(val name: String)
@Serializable private data class NicknameOut(val nickname: String, val nextChange: String? = null)
@Serializable private data class LogoutIn(val refreshToken: String)
@Serializable private data class StarPatch(val title: String, val body: String? = null, val mood: Mood? = null)

sealed interface NicknameResult {
    data object Ok : NicknameResult
    data class Problem(val why: String) : NicknameResult
}

/** App state shared by the screens (iOS AppModel): session, consent, nickname, coins. */
class AppModel(app: Application) : AndroidViewModel(app) {
    val api = ApiClient(TokenStore(app))
    private val prefs = app.getSharedPreferences("youniya_draft", 0)

    var userId by mutableStateOf<String?>(api.session?.userId)
        private set
    var pendingTarget by mutableStateOf<com.dycdyp.youniya.ui.screens.NotificationTarget?>(null)
    val playBilling by lazy {
        PlayBilling(
            context = app,
            scope = viewModelScope,
            api = api,
            onCoinsUpdated = { coins = it },
            showToast = { message = it },
        )
    }

    var isSignedIn by mutableStateOf(api.isSignedIn)
        private set
    var hasConsented by mutableStateOf(api.session?.needsConsent == false)
        private set
    /** Set only right after 11 so 21-1 follows once; never stored. */
    var justConsented by mutableStateOf(false)
        private set
    var nickname by mutableStateOf<String?>(null)
        private set
    var nicknameNextChange by mutableStateOf<String?>(null)
        private set
    var nicknameRenameRequired by mutableStateOf(false)
        private set
    var provider by mutableStateOf<String?>(null)
        private set
    var coins by mutableIntStateOf(0)
        private set
    var freeStarToday by mutableIntStateOf(0)
        private set
    var marketingOptIn by mutableStateOf(false)
        private set
    var plazaRestrictedUntil by mutableStateOf<String?>(null)
        private set
    var showPlazaRestricted by mutableStateOf(false)

    val isPlazaRestricted: Boolean
        get() {
            val until = plazaRestrictedUntil ?: return false
            return try {
                (parseServerInstant(until)?.isAfter(java.time.Instant.now()) == true)
            } catch (_: Exception) {
                false
            }
        }

    fun restrictedText(withTime: Boolean): String = formatRestrictedUntil(plazaRestrictedUntil, withTime)

    fun plazaAllowed(): Boolean {
        if (isPlazaRestricted) {
            showPlazaRestricted = true
            return false
        }
        return true
    }

    var plazaStarsLive by mutableStateOf<List<PlazaNebula>>(emptyList())
        private set
    var plazaStarsBeside by mutableStateOf<List<PlazaNebula>>(emptyList())
        private set
    var resonated by mutableStateOf<Set<String>>(emptySet())
        private set
    var tonightCount by mutableStateOf<Int?>(null)
        private set
    var tonightMine by mutableStateOf<Int?>(null)
        private set
    val sentStarLines = androidx.compose.runtime.mutableStateMapOf<String, String>()
    var blockedKeepers by mutableStateOf<Set<String>>(emptySet())
        private set

    val plazaStarItems: List<PlazaNebula>
        get() = if (isSignedIn && plazaStarsLive.isNotEmpty()) {
            plazaStarsLive.filter { it.name !in blockedKeepers && it.serverID !in blockedKeepers }
        } else {
            PlazaNebula.samples.filter { it.name !in blockedKeepers }
        }

    val isFloatFree: Boolean get() = freeStarToday > 0
    val floatNeedsCharge: Boolean get() = !isFloatFree && coins < floatCost

    var stars by mutableStateOf<List<StarItem>>(emptyList())
        private set
    var starsLoaded by mutableStateOf(false)
        private set
    /** null until the first list loads (the home tab waits on it). */
    val starCount: Int?
        get() = if (starsLoaded) stars.size else null

    var draft by mutableStateOf(loadLocalDraft())
        private set
    val reviseDrafts = mutableMapOf<String, StarDraft>()

    var message by mutableStateOf<String?>(null)

    val floatButtonTitle = "별빛 받고 띄우기"

    companion object {
        const val minFloatLength = 50
        const val floatCost = 5
        const val starlightTimeout = 60L
    }

    init {
        api.onSignedOut = { isSignedIn = false }
        if (isSignedIn) refreshMe()
        // 87: a star written today skips today's reminder.
        viewModelScope.launch {
            snapshotFlow { stars }.collect { list ->
                StarReminder.setWroteToday(
                    getApplication(), list.any { it.parsedDate?.toLocalDate() == java.time.LocalDate.now() },
                )
            }
        }
    }

    fun refreshMe() = viewModelScope.launch {
        runCatching { api.get<Me>("/v1/me") }
            .onSuccess(::apply)
            .onFailure(::handle)
        // The star list and the draft need consent (403 consent_required before it).
        if (hasConsented) {
            loadStars()
            loadDraft()
            PushRegistration.register(getApplication(), api)
            playBilling.checkUnconsumedPurchases()
        }
    }

    private fun apply(me: Me) {
        userId = me.id
        hasConsented = !me.needsConsent
        // Keep the saved session in step, so the next launch doesn't flash 11 before /v1/me answers.
        api.session?.let { if (it.needsConsent != me.needsConsent) api.store(it.copy(needsConsent = me.needsConsent)) }
        nickname = me.nickname
        nicknameNextChange = me.nicknameNextChange
        nicknameRenameRequired = me.nicknameRenameRequired
        provider = me.provider
        joinedAt = me.joinedAt?.let { parseKstDate(it)?.let { z -> "${z.year}년 ${z.monthValue}월 ${z.dayOfMonth}일" } } ?: me.joinedAt
        coins = me.coins
        freeStarToday = me.freeStarToday
        marketingOptIn = me.marketingOptIn
        plazaRestrictedUntil = me.plazaRestrictedUntil
        me.settings?.let {
            reduceAnimations = it.reduceAnimations
            skyThemeKey = it.sky
            starReminder = it.starReminder
            StarReminder.save(getApplication(), it.starReminder, reminderMinutes)
        }
    }

    private fun signedIn(s: AuthSession) {
        api.store(s)
        hasConsented = !s.needsConsent
        isSignedIn = true
        refreshMe()
    }

    suspend fun signInWithIdToken(providerName: String, idToken: String): Boolean = try {
        signedIn(api.send<IdTokenIn, AuthSession>("POST", "/v1/auth/$providerName", IdTokenIn(idToken), authorized = false))
        true
    } catch (e: Exception) {
        handle(e); false
    }

    /** AN-02-1: the Custom Tab came back on youniya://auth/apple (sign-in or the 계정 삭제 re-check). */
    fun appleReturned(r: AppleSignIn.Return) = viewModelScope.launch {
        when (r) {
            is AppleSignIn.Return.Failed ->
                if (!r.cancelled) message = "Apple 로그인을 마치지 못했어요. 다시 시도해 주세요."
            is AppleSignIn.Return.Code -> when (r.purpose) {
                AppleSignIn.Purpose.SignIn -> try {
                    signedIn(api.send<AppleExchangeIn, AuthSession>("POST", "/v1/auth/apple/exchange", AppleExchangeIn(r.code, r.verifier), authorized = false))
                } catch (e: Exception) {
                    handle(e)
                }
                AppleSignIn.Purpose.Delete -> deleteAccount(DeleteMeIn(r.code, r.verifier))
            }
        }
    }

    /** Debug only: the dev server's `DEV_LOGIN` sign-in (same name = same account). */
    suspend fun devSignIn(name: String): Boolean = try {
        signedIn(api.send<DevIn, AuthSession>("POST", "/v1/auth/dev", DevIn(name), authorized = false))
        true
    } catch (e: Exception) {
        handle(e); false
    }

    /** 02-1: an account the team handed out. */
    suspend fun inviteSignIn(login: String, password: String): Boolean = try {
        signedIn(api.send<InviteIn, AuthSession>("POST", "/v1/auth/invite", InviteIn(login, password), authorized = false))
        true
    } catch (e: ApiError) {
        if (e.status == 0) handle(e)
        false
    }

    fun acceptConsent(marketing: Boolean) = viewModelScope.launch {
        runCatching { api.send<ConsentIn, ConsentOut>("POST", "/v1/me/consent", ConsentIn(marketing = marketing)) }
            .onSuccess {
                marketingOptIn = it.marketingOptIn
                justConsented = true
                hasConsented = !it.needsConsent
                api.session?.let { s -> api.store(s.copy(needsConsent = it.needsConsent)) }
                // The star list needs consent, so it loads only now for a new account.
                refreshMe()
            }
            .onFailure(::handle)
    }

    fun signOut() = viewModelScope.launch {
        PushRegistration.unregister(getApplication(), api)
        api.session?.refreshToken?.let { r -> runCatching { api.sendNoContent("POST", "/v1/auth/logout", LogoutIn(r), authorized = false) } }
        api.store(null)
        isSignedIn = false
        hasConsented = false
        justConsented = false
        nickname = null
        stars = emptyList()
        starsLoaded = false
        draft = StarDraft()
        prefs.edit().remove("current_draft").apply()
        starReminder = false
        StarReminder.save(getApplication(), false, reminderMinutes)
    }

    fun nicknameFormProblem(name: String): String? {
        if (name.length < 2 || name.length > 12) return "2~12자로 정해 주세요"
        if (!Regex("^[가-힣A-Za-z0-9]+$").matches(name)) return "한글·영문·숫자만 쓸 수 있어요"
        val reserved = listOf("운영자", "관리자", "youniya", "유니야", "admin")
        if (reserved.any { name.lowercase().contains(it) }) return "쓸 수 없는 이름이에요"
        return null
    }

    suspend fun checkNickname(name: String): NicknameResult {
        nicknameFormProblem(name)?.let { return NicknameResult.Problem(it) }
        if (name == nickname) return NicknameResult.Ok
        return try {
            val r = api.get<NicknameCheck>("/v1/me/nickname/check", mapOf("name" to name))
            if (r.available) NicknameResult.Ok
            else NicknameResult.Problem(r.message ?: if (r.reason == "taken") "이미 다른 별지기가 쓰고 있는 이름이에요" else "쓸 수 없는 이름이에요")
        } catch (e: Exception) {
            NicknameResult.Problem("이름을 확인하지 못했어요. 잠시 뒤에 다시 해 주세요")
        }
    }

    suspend fun setNickname(name: String): NicknameResult = try {
        val r = api.send<NicknameIn, NicknameOut>("PUT", "/v1/me/nickname", NicknameIn(name))
        nickname = r.nickname
        nicknameNextChange = r.nextChange
        nicknameRenameRequired = false
        justConsented = false
        NicknameResult.Ok
    } catch (e: ApiError) {
        when (e.code) {
            "nickname_too_soon" -> NicknameResult.Problem("아직 바꿀 수 없어요. 30일에 한 번 바꿀 수 있어요")
            "nickname_taken" -> NicknameResult.Problem("이미 다른 별지기가 쓰고 있는 이름이에요")
            else -> NicknameResult.Problem(e.message)
        }
    }

    /** 21-1 can be left for later (back): the plaza asks again. */
    fun skipNickname() { justConsented = false }

    val providerName: String?
        get() = when (provider) {
            "apple" -> "Apple"
            "google" -> "Google"
            "invite" -> "초대 계정"
            "dev" -> "개발"
            null -> null
            else -> provider
        }

    fun handle(e: Throwable) {
        val err = e as? ApiError ?: return
        // As on iOS, the full-screen notices go by the server's error code, not the status alone:
        // 503 is also purchase_unverified and 429 also unlit_daily_limit, which are messages.
        when {
            err.status == 401 && err.code in setOf("token_expired", "signed_out", "unauthorized", "invalid_token") -> {
                api.store(null)
                isSignedIn = false
                appNotice = com.dycdyp.youniya.ui.screens.AppNotice.LoginExpired
            }
            err.code == "update_required" -> {
                appNotice = com.dycdyp.youniya.ui.screens.AppNotice.UpdateRequired
            }
            err.code == "maintenance" -> {
                val window = err.until?.let { parseKstDate(it)?.let { z -> "${z.monthValue}월 ${z.dayOfMonth}일 ${z.hour}:${"%02d".format(z.minute)}까지" } } ?: "곧 다시 열어요"
                appNotice = com.dycdyp.youniya.ui.screens.AppNotice.Maintenance(window)
            }
            err.code == "rate_limited" -> {
                retryAvailableAt = System.currentTimeMillis() + (err.retryAfter ?: 60) * 1000L
                appNotice = com.dycdyp.youniya.ui.screens.AppNotice.RateLimited
            }
            else -> message = err.message
        }
    }

    fun loadStars() = viewModelScope.launch {
        if (!isSignedIn) return@launch
        try {
            val list = api.get<StarList>("/v1/stars", mapOf("limit" to "200"))
            val details = kotlinx.coroutines.coroutineScope {
                list.items.map { item ->
                    async(Dispatchers.IO) {
                        runCatching { api.get<ServerStar>("/v1/stars/${item.id}") }.getOrNull()
                    }
                }.awaitAll().filterNotNull().associateBy { it.id }
            }
            val previous = stars.associateBy { it.id }
            stars = list.items.map { item ->
                val s = details[item.id] ?: item
                s.toItem(local = previous[s.id])
            }
            starsLoaded = true
        } catch (e: Exception) {
            handle(e)
        }
    }

    private fun loadLocalDraft(): StarDraft {
        val json = prefs.getString("current_draft", null) ?: return StarDraft()
        return runCatching { ApiJson.decodeFromString(StarDraft.serializer(), json) }.getOrDefault(StarDraft())
    }

    fun saveDraft(d: StarDraft) {
        draft = d
        if (d.isEmpty) {
            prefs.edit().remove("current_draft").apply()
        } else {
            val json = ApiJson.encodeToString(StarDraft.serializer(), d)
            prefs.edit().putString("current_draft", json).apply()
        }
        syncDraft(d)
    }

    fun syncDraft(d: StarDraft) {
        if (!isSignedIn) return
        viewModelScope.launch(Dispatchers.IO) {
            if (d.isEmpty) {
                runCatching { api.call("DELETE", "/v1/drafts/current", null, emptyMap(), authorized = true) }
            } else {
                runCatching {
                    api.sendNoContent("PUT", "/v1/drafts/current", DraftIn(mood = d.mood, moods = d.moods, title = d.title, body = d.body))
                }
            }
        }
    }

    fun loadDraft() = viewModelScope.launch {
        if (!isSignedIn || !draft.isEmpty) return@launch
        try {
            val resText = api.call("GET", "/v1/drafts/current", null, emptyMap(), authorized = true)
            if (resText.isBlank() || resText.trim() == "null") return@launch
            val d = api.decode(ServerDraft.serializer(), resText)
            val extra = if ((d.moods?.size ?: 0) > 1) d.moods?.drop(1) else null
            saveDraft(StarDraft(mood = d.mood, extraMoods = extra, title = d.title, body = d.body))
        } catch (_: Exception) {}
    }

    fun loadCoins() = viewModelScope.launch {
        if (!isSignedIn) return@launch
        runCatching { api.get<Me>("/v1/me") }
            .onSuccess(::apply)
    }

    suspend fun publishLit(
        d: StarDraft,
        attemptId: String,
        rewriteOf: String? = null,
        linkTo: List<String> = emptyList(),
    ): Pair<StarItem, Boolean> {
        val starIn = StarIn(
            mood = d.mood,
            moods = d.moods,
            title = d.title.trim(),
            body = d.body,
            mode = "lit",
            rewriteOf = rewriteOf,
            linkTo = linkTo.ifEmpty { null },
            attemptId = attemptId,
        )
        val r = api.send<StarIn, StarCreated>("POST", "/v1/stars", starIn, timeoutSeconds = starlightTimeout)
        r.coins?.let { coins = it }
        freeStarToday = 0
        val item = r.star.toItem()
        stars = listOf(item) + stars
        if (rewriteOf == null) {
            saveDraft(StarDraft())
        }
        return Pair(item, r.crisis != null)
    }

    suspend fun publish(
        d: StarDraft,
        floated: Boolean = false,
        attemptId: String? = null,
        rewriteOf: String? = null,
        linkTo: List<String> = emptyList(),
    ): Pair<StarItem, Boolean>? = try {
        if (floated) {
            publishLit(d, attemptId ?: java.util.UUID.randomUUID().toString().lowercase(), rewriteOf, linkTo)
        } else {
            val starIn = StarIn(
                mood = d.mood,
                moods = d.moods,
                title = d.title.trim(),
                body = d.body,
                mode = "unlit",
                rewriteOf = rewriteOf,
                linkTo = linkTo.ifEmpty { null },
            )
            val r = api.send<StarIn, StarCreated>("POST", "/v1/stars", starIn)
            val item = r.star.toItem()
            stars = listOf(item) + stars
            if (rewriteOf == null) {
                saveDraft(StarDraft())
            }
            Pair(item, r.crisis != null)
        }
    } catch (e: Exception) {
        handle(e)
        null
    }

    suspend fun editStar(id: String, mood: Mood?, title: String, body: String?): Boolean? {
        val t = title.trim()
        val finalTitle = t.ifEmpty { "제목 없는 별" }
        fun applyLocally() {
            val idx = stars.indexOfFirst { it.id == id }
            if (idx >= 0) {
                val m = stars.toMutableList()
                var current = m[idx].copy(title = finalTitle)
                if (body != null) current = current.copy(body = body)
                if (mood != null) current = current.copy(mood = mood)
                m[idx] = current
                stars = m
            }
        }
        return try {
            val patch = StarPatch(title = finalTitle, body = body, mood = mood)
            val r = api.send<StarPatch, StarCreated>("PATCH", "/v1/stars/$id", patch)
            val local = stars.firstOrNull { it.id == id }
            val updated = r.star.toItem(local).let {
                if (r.quoteMissing == true && it.isShared) it.copy(shareQuoteMissing = true) else it
            }
            val idx = stars.indexOfFirst { it.id == id }
            if (idx >= 0) {
                val m = stars.toMutableList()
                m[idx] = updated
                stars = m
            } else {
                applyLocally()
            }
            r.crisis != null
        } catch (e: Exception) {
            handle(e)
            null
        }
    }

    suspend fun deleteStar(id: String) {
        try {
            api.call("DELETE", "/v1/stars/$id", null, emptyMap(), authorized = true)
            stars = stars.filterNot { it.id == id }
        } catch (e: ApiError) {
            if (e.code == "not_found") {
                stars = stars.filterNot { it.id == id }
            } else {
                handle(e)
            }
        } catch (e: Exception) {
            handle(e)
        }
    }

    fun linkedStars(id: String): List<StarItem> {
        val ids = stars.firstOrNull { it.id == id }?.linkedIds?.toSet() ?: emptySet()
        return stars.filter { ids.contains(it.id) }.sortedByDescending { it.parsedDate ?: java.time.ZonedDateTime.now() }
    }

    fun linkLocally(id: String, others: List<String>) {
        val m = stars.toMutableList()
        for (other in others) {
            if (other == id) continue
            val i = m.indexOfFirst { it.id == id }
            if (i >= 0) {
                val current = m[i].linkedIds ?: emptyList()
                m[i] = m[i].copy(linkedIds = (current + other).distinct())
            }
            val j = m.indexOfFirst { it.id == other }
            if (j >= 0) {
                val current = m[j].linkedIds ?: emptyList()
                m[j] = m[j].copy(linkedIds = (current + id).distinct())
            }
        }
        stars = m
    }

    fun unlinkLocally(id: String, other: String) {
        val m = stars.toMutableList()
        val i = m.indexOfFirst { it.id == id }
        if (i >= 0) {
            val current = m[i].linkedIds ?: emptyList()
            m[i] = m[i].copy(linkedIds = current.filter { it != other })
        }
        val j = m.indexOfFirst { it.id == other }
        if (j >= 0) {
            val current = m[j].linkedIds ?: emptyList()
            m[j] = m[j].copy(linkedIds = current.filter { it != id })
        }
        stars = m
    }

    suspend fun linkStars(id: String, others: List<String>): Boolean = try {
        val r = api.send<LinksIn, LinksOut>("POST", "/v1/stars/$id/links", LinksIn(starIds = others))
        val serverIds = r.linkedStars.map { it.id }
        val idx = stars.indexOfFirst { it.id == id }
        if (idx >= 0) {
            val m = stars.toMutableList()
            m[idx] = m[idx].copy(linkedIds = serverIds)
            stars = m
        }
        for (other in others) {
            linkLocally(other, listOf(id))
        }
        true
    } catch (e: Exception) {
        handle(e)
        false
    }

    suspend fun unlinkStar(id: String, other: String) {
        try {
            api.call("DELETE", "/v1/stars/$id/links/$other", null, emptyMap(), authorized = true)
            unlinkLocally(id, other)
        } catch (e: Exception) {
            handle(e)
        }
    }

    suspend fun starDetail(id: String): StarItem? = try {
        val s = api.get<ServerStar>("/v1/stars/$id")
        val local = stars.firstOrNull { it.id == s.id }
        val item = s.toItem(local)
        val idx = stars.indexOfFirst { it.id == item.id }
        if (idx >= 0) {
            val m = stars.toMutableList()
            m[idx] = item
            stars = m
        } else {
            stars = listOf(item) + stars
        }
        item
    } catch (e: Exception) {
        handle(e)
        null
    }

    suspend fun stopStarlight(attemptId: String): Pair<Boolean, StarItem?> = try {
        val r = api.sendEmpty<CancelOut>("POST", "/v1/starlight/attempts/$attemptId/cancel")
        r.coins?.let { coins = it }
        val s = r.star?.let { serverStar ->
            val local = stars.firstOrNull { it.id == serverStar.id }
            serverStar.toItem(local)
        }
        if (s != null) {
            val idx = stars.indexOfFirst { it.id == s.id }
            if (idx >= 0) {
                val m = stars.toMutableList()
                m[idx] = s
                stars = m
            } else {
                stars = listOf(s) + stars
            }
        }
        Pair(true, s)
    } catch (e: ApiError) {
        if (e.code == "not_found") {
            Pair(true, null)
        } else {
            Pair(false, null)
        }
    } catch (_: Exception) {
        Pair(false, null)
    }

    suspend fun starAfterStop(id: String): StarItem? = try {
        val s = api.get<ServerStar>("/v1/stars/$id")
        val local = stars.firstOrNull { it.id == s.id }
        val star = s.toItem(local)
        val idx = stars.indexOfFirst { it.id == star.id }
        if (idx >= 0) {
            val m = stars.toMutableList()
            m[idx] = star
            stars = m
        } else {
            stars = listOf(star) + stars
        }
        star
    } catch (_: Exception) {
        null
    }

    suspend fun floatAgain(id: String, attemptId: String = java.util.UUID.randomUUID().toString().lowercase()): StarItem {
        val r = api.send<FloatIn, StarCreated>(
            "POST",
            "/v1/stars/$id/starlight",
            FloatIn(attemptId),
            timeoutSeconds = starlightTimeout,
        )
        r.coins?.let { coins = it }
        val local = stars.firstOrNull { it.id == id }
        val star = r.star.toItem(local)
        val idx = stars.indexOfFirst { it.id == id }
        if (idx >= 0) {
            val m = stars.toMutableList()
            m[idx] = star
            stars = m
        } else {
            stars = listOf(star) + stars
        }
        return star
    }

    fun keepInstead(id: String): StarItem? = stars.firstOrNull { it.id == id }

    var liveConstellations = androidx.compose.runtime.mutableStateMapOf<String, MonthConstellation>()
    var constellationsOverview by mutableStateOf<ServerConstellationsOverview?>(null)
    var liveStories = androidx.compose.runtime.mutableStateMapOf<String, ServerStory>()

    fun constellation(key: String): MonthConstellation {
        liveConstellations[key]?.let { return it }
        val c = MonthConstellation.local(key, stars)
        val updatedSlots = c.slots.map { slot ->
            val s = slot.star
            if (s != null) {
                val star = stars.firstOrNull { it.id == s.id }
                val isDeep = (star?.analysis?.depthScore ?: 0) >= 280
                slot.copy(star = s.copy(isDeep = isDeep))
            } else slot
        }
        return c.copy(slots = updatedSlots)
    }

    val firstConstellationMonth: String
        get() {
            val earliest = stars.mapNotNull { it.parsedDate }.minOrNull()
            return MonthConstellation.monthKey(earliest)
        }

    suspend fun loadConstellation(key: String): MonthConstellation? {
        if (!isSignedIn) return null
        return try {
            val r = api.get<ServerConstellation>("/v1/constellations/$key")
            val slots = r.slots.sortedBy { it.index }.map { slotOut ->
                val star = slotOut.star?.let { s ->
                    val shape = s.shape?.toSpec() ?: stars.firstOrNull { it.id == s.id }?.shape
                    MonthConstellation.Star(
                        id = s.id,
                        title = s.title,
                        mood = s.mood,
                        hasStarlight = s.hasStarlight,
                        starlight = s.starlight,
                        createdAt = s.createdAt,
                        shape = shape,
                        isDeep = (stars.firstOrNull { it.id == s.id }?.analysis?.depthScore ?: 0) >= 280,
                    )
                }
                MonthConstellation.Slot(
                    point = ConstellationPoint(slotOut.x.toFloat(), slotOut.y.toFloat()),
                    star = star,
                )
            }
            val extraStars = (r.extra ?: emptyList()).map { s ->
                val shape = s.shape?.toSpec() ?: stars.firstOrNull { it.id == s.id }?.shape
                MonthConstellation.Star(
                    id = s.id,
                    title = s.title,
                    mood = s.mood,
                    hasStarlight = s.hasStarlight,
                    starlight = s.starlight,
                    createdAt = s.createdAt,
                    shape = shape,
                    isDeep = (stars.firstOrNull { it.id == s.id }?.analysis?.depthScore ?: 0) >= 280,
                )
            }
            val name = if (r.name.endsWith("자리")) r.name else "${r.name}자리"
            val c = MonthConstellation(
                month = r.month,
                name = name,
                slots = slots,
                lines = r.lines,
                extra = extraStars,
                deep = r.deep,
            )
            liveConstellations[key] = c
            c
        } catch (e: ApiError) {
            if (e.status == 404) {
                null
            } else {
                handle(e)
                null
            }
        } catch (e: Exception) {
            handle(e)
            null
        }
    }

    suspend fun loadConstellationStory(key: String): ServerStory? {
        if (!isSignedIn) return null
        return try {
            val story = api.get<ServerStory>("/v1/constellations/$key/story")
            liveStories[key] = story
            story
        } catch (_: Exception) {
            null
        }
    }

    suspend fun loadConstellationsOverview(): ServerConstellationsOverview? {
        if (!isSignedIn) return null
        return try {
            val overview = api.get<ServerConstellationsOverview>("/v1/constellations")
            constellationsOverview = overview
            overview
        } catch (e: Exception) {
            handle(e)
            null
        }
    }

    // MARK: - 우주 광장 (Plaza)

    suspend fun loadPlaza() {
        if (!isSignedIn) return
        try {
            val newResp = viewModelScope.async(Dispatchers.IO) {
                api.get<PlazaItemsResponse<PlazaStarItem>>("/v1/plaza/stars", mapOf("sort" to "new"))
            }
            val similarResp = viewModelScope.async(Dispatchers.IO) {
                api.get<PlazaItemsResponse<PlazaStarItem>>("/v1/plaza/stars", mapOf("sort" to "similar"))
            }
            val besideResp = viewModelScope.async(Dispatchers.IO) {
                api.get<PlazaItemsResponse<PlazaStarItem>>("/v1/plaza/stars", mapOf("sort" to "beside"))
            }
            val ns = newResp.await().items
            val ss = similarResp.await().items
            val bs = besideResp.await().items

            val starRank = ss.mapIndexed { idx, item -> item.id to idx }.toMap()
            val totalSimilar = ss.size.coerceAtLeast(1).toDouble()

            plazaStarsLive = ns.mapIndexed { i, s ->
                val rank = starRank[s.id] ?: ss.size
                val sim = 1.0 - (rank.toDouble() / totalSimilar)
                PlazaNebula.fromItem(s, order = i, similarity = sim)
            }
            plazaStarsBeside = bs.mapIndexed { i, s ->
                PlazaNebula.fromItem(s, order = i, similarity = 0.0)
            }

            val newResonated = resonated.toMutableSet()
            for (s in ns) {
                if (s.resonated) newResonated.add(s.name)
            }
            resonated = newResonated
        } catch (e: Exception) {
            handle(e)
        }
    }

    suspend fun loadTonight() {
        if (!isSignedIn) return
        try {
            val r = api.get<PlazaTonightResponse>("/v1/plaza/tonight")
            tonightCount = r.count
            tonightMine = r.mine
        } catch (e: Exception) {
            handle(e)
        }
    }

    fun toggleResonance(star: PlazaNebula) {
        val key = star.name
        val on = key !in resonated
        resonated = if (on) resonated + key else resonated - key
        val id = star.serverID ?: return
        viewModelScope.launch {
            try {
                val method = if (on) "PUT" else "DELETE"
                api.call(method, "/v1/plaza/star/$id/resonance", null, emptyMap(), true)
                api.call(method, "/v1/plaza/star/$id/beside", null, emptyMap(), true)
            } catch (e: Exception) {
                resonated = if (on) resonated - key else resonated + key
                handle(e)
            }
        }
    }

    suspend fun shareStarLive(starId: String, quote: String? = null, fullText: Boolean = true): Boolean {
        val star = stars.firstOrNull { it.id == starId } ?: return false
        val chosenQuote = quote ?: splitShareSentences(star.body).maxByOrNull { it.length } ?: star.body.take(300)
        return try {
            api.send<StarShareIn, StarShareOut>(
                "PUT",
                "/v1/stars/$starId/share",
                StarShareIn(quote = chosenQuote, fullText = fullText, receiveLines = true),
            )
            stars = stars.map { if (it.id == starId) it.copy(shared = true, shareQuoteMissing = false) else it }
            true
        } catch (e: Exception) {
            handle(e)
            false
        }
    }

    suspend fun unshareStarLive(starId: String) {
        try {
            api.call("DELETE", "/v1/stars/$starId/share", null, emptyMap(), true)
            stars = stars.map { if (it.id == starId) it.copy(shared = false) else it }
        } catch (e: Exception) {
            handle(e)
        }
    }

    suspend fun plazaStarText(shareId: String): Pair<String, String>? = try {
        val d = api.get<PlazaStarDetail>("/v1/plaza/stars/$shareId")
        val body = d.bodyMasked
        if (body != null) Pair(d.titleMasked ?: "", body) else null
    } catch (_: Exception) {
        null
    }

    suspend fun keeperStars(nickname: String): List<PlazaNebula>? = try {
        val r = api.get<KeeperResponse>("/v1/keepers/$nickname")
        r.items.mapIndexed { i, s -> PlazaNebula.fromItem(s, order = i, similarity = 0.0) }
    } catch (e: ApiError) {
        if (e.status == 404) null else { handle(e); null }
    } catch (e: Exception) {
        handle(e)
        null
    }

    suspend fun sendStarLine(star: PlazaNebula, text: String?, chip: String?): LineSendResult {
        val id = star.serverID
        val chipLabel = when (chip) {
            "empathize" -> "공감해요"
            "me_too" -> "저도 그랬어요"
            "thanks" -> "고마워요"
            else -> ""
        }
        if (id == null) {
            if (sentStarLines[star.name] != null) return LineSendResult.Already
            val t = text
            if (t != null) {
                if (listOf("한심", "바보", "멍청", "꺼져").any { t.contains(it) }) {
                    return LineSendResult.Rejected("상처가 될 수 있는 말이 있어 건네지 못했어요")
                }
                if (PrivacyScan(t, contactsOnly = true).contacts > 0) {
                    return LineSendResult.Rejected("연락처는 별빛 한 줄에 담을 수 없어요")
                }
                if (listOf("해야 해", "하세요", "하지 마").any { t.contains(it) }) {
                    return LineSendResult.Rejected("조언 대신 마음을 건네 주세요")
                }
            }
            sentStarLines[star.name] = text ?: chipLabel
            return LineSendResult.Sent
        }
        return try {
            api.send<StarLineIn, StarLineOut>(
                "POST",
                "/v1/plaza/stars/$id/lines",
                StarLineIn(text = text, chip = chip),
            )
            sentStarLines[star.name] = text ?: chipLabel
            plazaStarsLive = plazaStarsLive.map { if (it.serverID == id) it.copy(lineLeft = true) else it }
            LineSendResult.Sent
        } catch (e: ApiError) {
            when (e.code) {
                "already_left" -> LineSendResult.Already
                "plaza_restricted" -> {
                    handle(e)
                    LineSendResult.Rejected("광장 이용이 잠시 멈춰 있어요")
                }
                "lines_closed" -> LineSendResult.Closed
                "hurtful" -> LineSendResult.Rejected("상처가 될 수 있는 말이 있어 건네지 못했어요")
                "contact" -> LineSendResult.Rejected("연락처는 별빛 한 줄에 담을 수 없어요")
                "judging", "advice" -> LineSendResult.Rejected("판단이나 조언 대신 마음을 건네 주세요")
                "too_long" -> LineSendResult.Rejected("60자 안으로 줄여 주세요")
                else -> LineSendResult.Rejected(e.message)
            }
        } catch (e: Exception) {
            handle(e)
            LineSendResult.Rejected("건네지 못했어요. 잠시 뒤에 다시 해 주세요")
        }
    }

    suspend fun receivedLines(starId: String): List<ReceivedLine> = try {
        val r = api.get<ReceivedLinesResponse>("/v1/stars/$starId/lines")
        r.items.map { item ->
            val content = item.text ?: when (item.chip) {
                "empathize" -> "공감해요"
                "me_too" -> "저도 그랬어요"
                "thanks" -> "고마워요"
                else -> ""
            }
            ReceivedLine(id = item.id, text = content, nickname = item.nickname, createdAt = item.createdAt)
        }
    } catch (e: Exception) {
        handle(e)
        emptyList()
    }

    suspend fun deleteLine(starId: String, lineId: String): Boolean = try {
        api.call("DELETE", "/v1/stars/$starId/lines/$lineId", null, emptyMap(), true)
        true
    } catch (e: Exception) {
        handle(e)
        false
    }

    suspend fun reportLine(starId: String, lineId: String, reason: String, block: Boolean): Boolean = try {
        api.send<LineReportIn, ReportOut>(
            "POST",
            "/v1/stars/$starId/lines/$lineId/report",
            LineReportIn(reason = reason, block = block),
        )
        true
    } catch (e: Exception) {
        handle(e)
        false
    }

    suspend fun reportShare(targetId: String, reason: String, block: Boolean): Boolean = try {
        api.send<LineReportIn, ReportOut>(
            "POST",
            "/v1/plaza/star/$targetId/report",
            LineReportIn(reason = reason, block = block),
        )
        if (block) blockedKeepers = blockedKeepers + targetId
        loadPlaza()
        true
    } catch (e: Exception) {
        handle(e)
        false
    }

    suspend fun blockKeeper(starShareId: String): Boolean = try {
        api.send<BlockIn, BlockOut>("POST", "/v1/blocks", BlockIn(starId = starShareId))
        blockedKeepers = blockedKeepers + starShareId
        loadPlaza()
        true
    } catch (e: Exception) {
        handle(e)
        false
    }

    suspend fun maskPreview(sentence: String, contactsOnly: Boolean = false): MaskPreview {
        if (!isSignedIn) return MaskPreview(
            masked = PrivacyScan(sentence, contactsOnly).masked,
            names = PrivacyScan(sentence, contactsOnly).names,
            contacts = PrivacyScan(sentence, contactsOnly).contacts,
            places = PrivacyScan(sentence, contactsOnly).places,
        )
        return try {
            val r = api.send<ScanIn, ScanOut>(
                "POST",
                "/v1/plaza/privacy-scan",
                ScanIn(text = sentence, mode = if (contactsOnly) "contacts" else "all"),
            )
            MaskPreview(
                masked = r.masked,
                names = r.counts.names,
                contacts = r.counts.contacts,
                places = r.counts.places,
            )
        } catch (_: Exception) {
            val s = PrivacyScan(sentence, contactsOnly)
            MaskPreview(s.masked, s.names, s.contacts, s.places)
        }
    }

    fun sentenceOptions(starId: String): List<SentenceOption> {
        val star = stars.firstOrNull { it.id == starId } ?: return emptyList()
        return splitShareSentences(star.body).mapIndexed { idx, s ->
            SentenceOption(id = idx, sentence = s)
        }
    }

    suspend fun loadSharedStars(): List<MyShareStarItem> = try {
        val r = api.get<MySharesResponse>("/v1/me/shares")
        r.stars
    } catch (e: Exception) {
        handle(e)
        emptyList()
    }

    // MARK: - 5단계 추가 기능 (기록·설정·알림함·코인·차단)

    var appNotice by mutableStateOf<com.dycdyp.youniya.ui.screens.AppNotice?>(null)
    var retryAvailableAt by mutableStateOf<Long?>(null)
    var starReminder by mutableStateOf(false)
        private set
    var reminderMinutes by mutableIntStateOf(StarReminder.minutes(app)) // 21:30 by default
        private set
    var reduceAnimations by mutableStateOf(false)
        private set
    var skyThemeKey by mutableStateOf("violet")
        private set
    var joinedAt by mutableStateOf<String?>(null)
        private set
    var coinHistory by mutableStateOf<List<CoinEntry>>(emptyList())
        private set
    var blockedList by mutableStateOf<List<BlockedKeeper>>(emptyList())
        private set
    var inbox by mutableStateOf<List<com.dycdyp.youniya.ui.screens.InboxItem>>(emptyList())
        private set
    var notices by mutableStateOf<List<com.dycdyp.youniya.ui.screens.AppNoticeItem>>(emptyList())
        private set

    val nicknameNextChangeText: String?
        get() = nicknameNextChange?.let {
            val z = parseKstDate(it) ?: return null
            if (z.toInstant().isAfter(java.time.Instant.now())) "${z.monthValue}월 ${z.dayOfMonth}일" else null
        }

    fun setStarReminder(on: Boolean) = viewModelScope.launch {
        starReminder = on
        StarReminder.save(getApplication(), on, reminderMinutes)
        runCatching {
            api.send<SettingsPatchIn, Unit>("PATCH", "/v1/me/settings", SettingsPatchIn(starReminder = on))
        }
    }

    fun updateReminderMinutes(minutes: Int) {
        reminderMinutes = minutes
        StarReminder.save(getApplication(), starReminder, minutes)
    }

    fun setReduceAnimations(reduce: Boolean) = viewModelScope.launch {
        reduceAnimations = reduce
        runCatching {
            api.send<SettingsPatchIn, Unit>("PATCH", "/v1/me/settings", SettingsPatchIn(reduceAnimations = reduce))
        }
    }

    fun setSkyThemeKey(theme: String) = viewModelScope.launch {
        skyThemeKey = theme
        runCatching {
            api.send<SettingsPatchIn, Unit>("PATCH", "/v1/me/settings", SettingsPatchIn(sky = theme))
        }
    }

    fun setMarketing(optIn: Boolean) = viewModelScope.launch {
        marketingOptIn = optIn
        runCatching {
            val r = api.send<MarketingIn, MarketingOut>("PUT", "/v1/me/marketing", MarketingIn(optIn))
            marketingOptIn = r.optIn
        }.onFailure(::handle)
    }

    fun loadCoinHistory() = viewModelScope.launch {
        if (!isSignedIn) return@launch
        runCatching {
            val r = api.get<ServerCoinHistoryOut>("/v1/coins/history")
            coinHistory = r.items.map {
                CoinEntry(id = it.id, kind = it.kind, title = it.title, delta = it.delta, source = it.source, createdAt = it.createdAt)
            }
        }.onFailure(::handle)
    }

    fun loadBlocks() = viewModelScope.launch {
        if (!isSignedIn) return@launch
        runCatching {
            val r = api.get<ServerBlocksOut>("/v1/blocks")
            blockedList = r.items.map {
                BlockedKeeper(id = it.id, source = it.source, createdAt = it.createdAt)
            }
        }.onFailure(::handle)
    }

    fun unblock(blockId: String) = viewModelScope.launch {
        if (!isSignedIn) return@launch
        try {
            api.call("DELETE", "/v1/blocks/$blockId", null, emptyMap(), authorized = true)
            blockedList = blockedList.filter { it.id != blockId }
            message = "차단을 풀었어요"
        } catch (e: Exception) {
            handle(e)
        }
    }

    fun loadInbox() = viewModelScope.launch {
        if (!isSignedIn) return@launch
        runCatching {
            val r = api.get<ServerNotificationsOut>("/v1/me/notifications")
            inbox = r.items.map { item ->
                com.dycdyp.youniya.ui.screens.InboxItem(
                    id = item.id,
                    kind = item.kind,
                    title = item.title,
                    body = item.body,
                    target = com.dycdyp.youniya.ui.screens.NotificationTarget.fromJson(item.target),
                    createdAt = item.createdAt,
                    read = item.read,
                )
            }
        }.onFailure(::handle)
    }

    fun markRead(ids: List<String>) = viewModelScope.launch {
        inbox = inbox.map { if (it.id in ids) it.copy(read = true) else it }
        if (!isSignedIn || ids.isEmpty()) return@launch
        runCatching {
            api.send<ReadIn, Unit>("POST", "/v1/me/notifications/read", ReadIn(ids))
        }
    }

    fun loadNotices() = viewModelScope.launch {
        if (!isSignedIn) return@launch
        runCatching {
            val r = api.get<ServerNoticesOut>("/v1/notices")
            notices = r.items.map {
                com.dycdyp.youniya.ui.screens.AppNoticeItem(id = it.id, title = it.title, body = it.body, publishedAt = it.publishedAt)
            }
        }.onFailure(::handle)
    }

    /**
     * iOS 5.1.1(v): an Apple account confirms with Apple once more first (the settings sheet opens
     * the Custom Tab with purpose=delete, and [appleReturned] lands here with the handoff code).
     */
    fun deleteAccount() = deleteAccount(null)

    private fun deleteAccount(apple: DeleteMeIn?) = viewModelScope.launch {
        if (!isSignedIn) return@launch
        try {
            PushRegistration.unregister(getApplication(), api)
            if (apple != null) api.sendNoContent("DELETE", "/v1/me", apple)
            else api.call("DELETE", "/v1/me", null, emptyMap(), authorized = true)
            api.store(null)
            isSignedIn = false
            appNotice = com.dycdyp.youniya.ui.screens.AppNotice.AccountDeleted
        } catch (e: Exception) {
            handle(e)
        }
    }

    fun withdrawAllShares() = viewModelScope.launch {
        if (!isSignedIn) return@launch
        try {
            api.call("DELETE", "/v1/me/shares", null, emptyMap(), authorized = true)
            stars = stars.map { it.copy(shared = false) }
            message = "우주 광장에서 나눈 별을 모두 거뒀어요."
        } catch (e: Exception) {
            handle(e)
        }
    }

    /** 93 텍스트 파일로 · PDF로: the server's export (every star with its 별빛 풀이 and 별자리 이야기). */
    suspend fun exportFile(pdf: Boolean): ByteArray? = try {
        api.download("/v1/me/export", mapOf("format" to if (pdf) "pdf" else "text"))
    } catch (e: Exception) {
        handle(e)
        null
    }

    fun exportText(): String {
        val sb = StringBuilder("YOUNIYA 기록 내보내기\n\n")
        for (s in stars) {
            sb.append("■ ").append(s.title).append("\n")
            sb.append(s.dateText).append(" · ").append(if (s.isFloated) "별빛 받은 별" else "별빛 없는 별").append("\n")
            if (s.body.isNotEmpty()) {
                sb.append("\n").append(s.body).append("\n")
            }
            sb.append("\n")
        }
        return sb.toString()
    }

    fun sendInquiry(kind: String, email: String, body: String, onDone: (Boolean) -> Unit) = viewModelScope.launch {
        try {
            api.send<InquiryIn, InquiryOut>("POST", "/v1/inquiries", InquiryIn(kind = kind, email = email, body = body))
            message = "문의를 보냈어요."
            onDone(true)
        } catch (e: Exception) {
            handle(e)
            onDone(false)
        }
    }

    // MARK: - 5b 코인 결제(Google Play) & FCM 기기 등록
    fun applyCoins(newCoins: Int) {
        coins = newCoins
    }

    fun checkUnconsumedPurchases() {
        playBilling.checkUnconsumedPurchases()
    }

    fun registerDeviceToken(explicitToken: String? = null) = viewModelScope.launch {
        PushRegistration.register(getApplication(), api, explicitToken)
    }

    fun purchaseCoinsDev(amount: Int, onResult: (BillingOutcome) -> Unit) = viewModelScope.launch {
        val outcome = playBilling.purchaseDev(amount)
        onResult(outcome)
    }
}

@Serializable private data class SettingsPatchIn(val sky: String? = null, val reduceAnimations: Boolean? = null, val starReminder: Boolean? = null)
@Serializable private data class MarketingIn(val optIn: Boolean)
@Serializable private data class MarketingOut(val optIn: Boolean)
@Serializable private data class ServerCoinItem(val id: String, val kind: String, val title: String, val delta: Int, val source: String = "server", val createdAt: String? = null)
@Serializable private data class ServerCoinHistoryOut(val items: List<ServerCoinItem> = emptyList())
@Serializable private data class ServerBlockItem(val id: String, val source: String = "line", val createdAt: String? = null)
@Serializable private data class ServerBlocksOut(val items: List<ServerBlockItem> = emptyList())
@Serializable private data class ServerNotificationItem(val id: String, val kind: String, val title: String, val body: String, val target: kotlinx.serialization.json.JsonObject? = null, val createdAt: String? = null, val read: Boolean = false)
@Serializable private data class ServerNotificationsOut(val items: List<ServerNotificationItem> = emptyList(), val unread: Int = 0, val nextBefore: String? = null)
@Serializable private data class ServerNoticeItem(val id: String, val title: String, val body: String, val publishedAt: String? = null)
@Serializable private data class ServerNoticesOut(val items: List<ServerNoticeItem> = emptyList())
@Serializable private data class ReadIn(val ids: List<String>, val all: Boolean = false)
@Serializable private data class InquiryIn(val kind: String, val email: String, val body: String)
@Serializable private data class InquiryOut(val id: String)

data class CoinEntry(
    val id: String,
    val kind: String = "purchase",
    val title: String,
    val delta: Int,
    val source: String = "server",
    val createdAt: String? = null,
) {
    val displayTitle: String
        get() = when {
            kind == "refund" -> when (source) {
                "google_play" -> "충전 취소 · Google Play 환불"
                "app_store" -> "충전 취소 · App Store 환불"
                else -> "충전 취소 · 환불"
            }
            else -> title
        }
}

data class BlockedKeeper(
    val id: String,
    val source: String = "line",
    val createdAt: String? = null,
) {
    val detail: String
        get() {
            val label = when (source) {
                "star", "nebula" -> "별"
                else -> "별빛 한 줄"
            }
            val dateStr = formatKstShortDate(createdAt) ?: ""
            return if (dateStr.isNotEmpty()) "$label · $dateStr 차단" else label
        }
}

