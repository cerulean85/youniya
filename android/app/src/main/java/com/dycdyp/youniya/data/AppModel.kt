package com.dycdyp.youniya.data

import android.app.Application
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
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
)

@Serializable private data class IdTokenIn(val idToken: String)
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
    }

    fun refreshMe() = viewModelScope.launch {
        runCatching { api.get<Me>("/v1/me") }
            .onSuccess(::apply)
            .onFailure(::handle)
        // The star list and the draft need consent (403 consent_required before it).
        if (hasConsented) {
            loadStars()
            loadDraft()
        }
    }

    private fun apply(me: Me) {
        hasConsented = !me.needsConsent
        // Keep the saved session in step, so the next launch doesn't flash 11 before /v1/me answers.
        api.session?.let { if (it.needsConsent != me.needsConsent) api.store(it.copy(needsConsent = me.needsConsent)) }
        nickname = me.nickname
        nicknameNextChange = me.nicknameNextChange
        nicknameRenameRequired = me.nicknameRenameRequired
        provider = me.provider
        coins = me.coins
        freeStarToday = me.freeStarToday
        marketingOptIn = me.marketingOptIn
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
        // Only a lost session signs out; a refused sign-in (401 invalid_id_token) says why.
        if (err.status == 401 && err.code in setOf("token_expired", "signed_out", "unauthorized", "invalid_token")) {
            api.store(null); isSignedIn = false
        } else {
            message = err.message
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
}
