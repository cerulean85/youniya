package com.dycdyp.youniya.data

import kotlinx.serialization.Serializable
import java.time.Instant
import java.time.ZoneId
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit
import java.util.Locale
import kotlin.random.Random

// MARK: - Server Payloads

@Serializable
data class PlazaShapeOut(
    val points: Int,
    val sharpness: String,
) {
    fun toSpec(): StarShapeSpec {
        val s = when (sharpness) {
            "sharp" -> StarShapeSpec.Sharpness.sharp
            "soft" -> StarShapeSpec.Sharpness.soft
            else -> StarShapeSpec.Sharpness.normal
        }
        return StarShapeSpec(points = points, sharpness = s)
    }
}

@Serializable
data class PlazaStarItem(
    val id: String,
    val name: String,
    val quote: String? = null,
    val mood: String = "calm",
    val moods: List<String> = emptyList(),
    val depthLevel: Int? = null,
    val shape: PlazaShapeOut? = null,
    val resonated: Boolean = false,
    val beside: Boolean = false,
    val createdAt: String? = null,
    val fullText: Boolean? = null,
    val nickname: String? = null,
    val title: String? = null,
    val hasStarlight: Boolean? = null,
    val receiveLines: Boolean? = null,
    val lineLeft: Boolean? = null,
)

@Serializable
data class PlazaStarDetail(
    val id: String,
    val name: String,
    val quote: String? = null,
    val mood: String = "calm",
    val moods: List<String> = emptyList(),
    val depthLevel: Int? = null,
    val shape: PlazaShapeOut? = null,
    val resonated: Boolean = false,
    val beside: Boolean = false,
    val createdAt: String? = null,
    val fullText: Boolean? = null,
    val nickname: String? = null,
    val title: String? = null,
    val hasStarlight: Boolean? = null,
    val receiveLines: Boolean? = null,
    val lineLeft: Boolean? = null,
    val titleMasked: String? = null,
    val bodyMasked: String? = null,
)

@Serializable
data class PlazaItemsResponse<T>(
    val items: List<T> = emptyList(),
)

@Serializable
data class PlazaTonightResponse(
    val count: Int = 0,
    val mine: Int = 0,
)

@Serializable
data class StarShareIn(
    val quote: String,
    val fullText: Boolean = true,
    val receiveLines: Boolean = true,
)

@Serializable
data class StarShareOut(
    val shareId: String,
    val name: String,
    val quote: String,
    val fullText: Boolean,
    val receiveLines: Boolean,
)

@Serializable
data class ScanIn(
    val text: String,
    val mode: String = "all",
)

@Serializable
data class ScanCounts(
    val names: Int = 0,
    val contacts: Int = 0,
    val places: Int = 0,
)

@Serializable
data class ScanOut(
    val masked: String,
    val counts: ScanCounts = ScanCounts(),
    val total: Int = 0,
)

@Serializable
data class StarLineIn(
    val text: String? = null,
    val chip: String? = null,
)

@Serializable
data class StarLineOut(
    val id: String,
    val text: String? = null,
    val chip: String? = null,
    val createdAt: String? = null,
)

@Serializable
data class ReceivedLineItem(
    val id: String,
    val text: String? = null,
    val chip: String? = null,
    val nickname: String? = null,
    val createdAt: String? = null,
)

@Serializable
data class ReceivedLinesResponse(
    val items: List<ReceivedLineItem> = emptyList(),
    val count: Int? = null,
)

@Serializable
data class LineReportIn(
    val reason: String,
    val block: Boolean = false,
)

@Serializable
data class ReportOut(
    val reported: Boolean = true,
    val blocked: Boolean? = null,
)

@Serializable
data class BlockIn(
    val lineId: String? = null,
    val starId: String? = null,
    val nebulaId: String? = null,
)

@Serializable
data class BlockOut(
    val id: String,
    val createdAt: String,
    val source: String,
)

@Serializable
data class KeeperResponse(
    val nickname: String,
    val mine: Boolean = false,
    val items: List<PlazaStarItem> = emptyList(),
)

@Serializable
data class MyShareStarItem(
    val id: String,
    val starId: String,
    val name: String,
    val title: String,
    val writtenAt: String? = null,
    val starlight: Int = 0,
    val createdAt: String? = null,
    val resonances: Int = 0,
    val hidden: Boolean = false,
    val quoteMissing: Boolean = false,
    val receiveLines: Boolean = true,
    val lines: Int = 0,
)

@Serializable
data class MySharesResponse(
    val stars: List<MyShareStarItem> = emptyList(),
)

// MARK: - UI Models

data class PlazaNebula(
    val name: String,
    val line: String,
    val pattern: Pattern = Pattern.A,
    val similarity: Double = 0.5,
    val order: Int = 0,
    val serverID: String? = null,
    val starShape: StarShapeSpec? = null,
    val mood: Mood? = null,
    val depthLevel: Int? = null,
    val sharedAt: String? = null,
    val fullText: Boolean = false,
    val fullTitle: String? = null,
    val fullBody: String? = null,
    val nickname: String? = null,
    val starTitle: String? = null,
    val hasStarlight: Boolean = true,
    val receiveLines: Boolean = true,
    val lineLeft: Boolean = false,
) {
    enum class Pattern { A, B }

    val id: String get() = serverID ?: name

    val cardShape: StarShapeSpec
        get() {
            if (starShape != null) return starShape
            val rng = Random(name.hashCode())
            val sharp = StarShapeSpec.Sharpness.entries
            val pts = 4 + rng.nextInt(4)
            val sh = sharp[rng.nextInt(sharp.size)]
            return StarShapeSpec(points = pts, sharpness = sh)
        }

    val cardMood: Mood
        get() {
            if (mood != null) return mood
            val rng = Random(("mood-$name").hashCode())
            return Mood.entries[rng.nextInt(Mood.entries.size)]
        }

    val cardDepth: Int
        get() = depthLevel ?: 3

    companion object {
        fun fromItem(s: PlazaStarItem, order: Int, similarity: Double): PlazaNebula {
            val rng = Random(s.id.hashCode())
            val m = try { Mood.valueOf(s.mood) } catch (_: Exception) { Mood.calm }
            return PlazaNebula(
                name = s.name,
                line = s.quote ?: "",
                pattern = if (rng.nextBoolean()) Pattern.A else Pattern.B,
                similarity = similarity,
                order = order,
                serverID = s.id,
                starShape = s.shape?.toSpec(),
                mood = m,
                depthLevel = s.depthLevel,
                sharedAt = s.createdAt,
                fullText = s.fullText ?: false,
                nickname = s.nickname,
                starTitle = s.title,
                hasStarlight = s.hasStarlight ?: true,
                receiveLines = s.receiveLines ?: true,
                lineLeft = s.lineLeft ?: false,
            )
        }

        val samples: List<PlazaNebula> = listOf(
            PlazaNebula(
                name = "고요한 새벽의 별",
                line = "괜찮다는 말 뒤에 숨는 건 이제 그만하고 싶다.",
                pattern = Pattern.A,
                similarity = 0.62,
                order = 0,
                fullText = true,
                fullTitle = "새벽에 깬 날",
                fullBody = "새벽 네 시에 눈이 떠졌다. 다시 잠들려고 애쓰다가 그냥 창가에 앉았다. 민지가 보낸 메시지를 몇 번이나 다시 읽었다. 괜찮다는 말 뒤에 숨는 건 이제 그만하고 싶다. 내일은 서울숲에 가서 천천히 걸어 볼 생각이다. 연락은 ●●●로 주면 된다고 적어 두었다.",
                nickname = "고요한새벽",
                starTitle = "그 말을 삼킨 저녁",
            ),
            PlazaNebula(
                name = "늦은 밤의 등대별",
                line = "오늘도 여기까지 왔어요.",
                pattern = Pattern.B,
                similarity = 0.91,
                order = 1,
                fullText = true,
                fullTitle = "퇴근길 버스 창가",
                fullBody = "아침부터 일이 겹쳐서 점심도 제대로 못 먹었다. 집에 오는 길에 편의점 불빛이 유난히 따뜻해 보였다. 오늘도 여기까지 왔어요. 그걸로 됐다고 말해 주고 싶다.",
                nickname = "밤바다",
                starTitle = "퇴근길 버스 창가",
            ),
            PlazaNebula(
                name = "비를 기다리는 별",
                line = "느려도 괜찮은 밤이에요.",
                pattern = Pattern.B,
                similarity = 0.78,
                order = 2,
                nickname = "느린고래",
                starTitle = "괜찮은 척한 하루",
            ),
            PlazaNebula(
                name = "천천히 날아오른 별",
                line = "당신의 별빛이 닿았어요.",
                pattern = Pattern.A,
                similarity = 0.45,
                order = 3,
                nickname = "바람결",
                starTitle = "오랜만에 웃은 날",
            ),
            PlazaNebula(
                name = "창가에 앉은 별",
                line = "잠깐 멈춰도 괜찮다는 말을 들었어요.",
                pattern = Pattern.B,
                similarity = 0.7,
                order = 4,
                nickname = "창가고양이",
                starTitle = "잠깐 멈춘 오후",
                hasStarlight = false,
            ),
            PlazaNebula(
                name = "첫눈을 기다리는 별",
                line = "말끝을 흐려도 마음은 남아 있었어요.",
                pattern = Pattern.A,
                similarity = 0.55,
                order = 5,
                nickname = "첫눈사슴",
                starTitle = "첫눈 오기 전날",
                hasStarlight = false,
            ),
        )
    }
}

enum class PlazaFilter(val title: String) {
    Newest("새로 뜬 것"),
    Similar("나와 결이 비슷한"),
    Kept("곁에 둔 것"),
}

data class SentenceOption(
    val id: Int,
    val sentence: String,
    val caption: String? = null,
)

data class MaskPreview(
    val masked: String,
    val names: Int = 0,
    val contacts: Int = 0,
    val places: Int = 0,
) {
    val total: Int get() = names + contacts + places
    val note: String?
        get() {
            val parts = listOf("이름" to names, "연락처" to contacts, "장소" to places)
                .filter { it.second > 0 }
                .map { "${it.first} ${it.second}곳" }
            return if (parts.isEmpty()) null else parts.joinToString("·") + "을 가린 채로 올라가요"
        }
}

data class ReceivedLine(
    val id: String,
    val text: String,
    val nickname: String?,
    val createdAt: String?,
)

sealed interface LineSendResult {
    data object Sent : LineSendResult
    data class Rejected(val why: String) : LineSendResult
    data object Already : LineSendResult
    data object Closed : LineSendResult
}

// MARK: - Privacy Scan & String Helpers

class PrivacyScan(text: String, contactsOnly: Boolean = false) {
    var names = 0
        private set
    var contacts = 0
        private set
    var places = 0
        private set
    var masked: String
        private set

    val total: Int get() = names + contacts + places

    val summary: String
        get() = listOf("이름" to names, "연락처" to contacts, "장소" to places)
            .filter { it.second > 0 }
            .joinToString(" · ") { "${it.first} ${it.second}" }

    init {
        var out = text
        for ((kind, pattern) in PATTERNS) {
            if (contactsOnly && kind != "contacts") continue
            val regex = pattern.toRegex()
            val matches = regex.findAll(out).toList()
            when (kind) {
                "contacts" -> contacts += matches.size
                "names" -> names += matches.size
                "places" -> places += matches.size
            }
            out = regex.replace(out, "●●●")
        }
        masked = out
    }

    companion object {
        private val PATTERNS = listOf(
            "contacts" to """(?<!\d)0\d{1,2}[-. ]?\d{3,4}[-. ]?\d{4}(?!\d)|[\w.+-]+@[\w-]+\.[A-Za-z.]+""",
            "names" to """[가-힣]{2,3}(?=\s?(?:씨|님|선배|후배|언니|오빠|누나|형|선생님)(?:이랑|에게|한테|[이가은는을를랑과와도의께])?(?![가-힣]))""",
            "places" to """[가-힣]{2,8}(?:역|구청|공원|학교|대학교|병원|카페|시장|해변|터미널)(?=(?:에서|에|으로|로|은|는|이|가|을|를|과|와|의|도)?(?![가-힣]))""",
        )
    }
}

fun splitShareSentences(body: String): List<String> {
    val out = mutableListOf<String>()
    var current = StringBuilder()
    val ends = setOf('.', '!', '?', '…', '。')
    val chars = body.toCharArray()
    for (i in chars.indices) {
        val c = chars[i]
        if (c == '\n') {
            out.add(current.toString())
            current = StringBuilder()
            continue
        }
        current.append(c)
        val next = if (i + 1 < chars.size) chars[i + 1] else null
        if (c in ends && next != null && (next in ends || next == '"' || next == '”' || next == '\'')) {
            continue
        }
        if (c in ends || ((c == '"' || c == '”' || c == '\'') && i > 0 && chars[i - 1] in ends)) {
            out.add(current.toString())
            current = StringBuilder()
        }
    }
    out.add(current.toString())
    return out.map { it.trim() }.filter { it.length in 2..300 }
}

fun formatPlazaWhen(isoString: String?): String {
    if (isoString == null) return "방금"
    return try {
        val instant = parseServerInstant(isoString) ?: return "방금"
        val now = Instant.now()
        val seconds = ChronoUnit.SECONDS.between(instant, now).coerceAtLeast(0)
        when {
            seconds < 60 -> "방금"
            seconds < 3600 -> "${seconds / 60}분 전"
            seconds < 86400 -> "${seconds / 3600}시간 전"
            else -> "${seconds / 86400}일 전"
        }
    } catch (_: Exception) {
        "방금"
    }
}

fun formatRestrictedUntil(isoString: String?, withTime: Boolean): String {
    if (isoString == null) return ""
    return try {
        val zdt = ZonedDateTime.parse(isoString).withZoneSameInstant(ZoneId.of("Asia/Seoul"))
        val pattern = if (withTime) "M월 d일 a h시" else "M월 d일"
        zdt.format(DateTimeFormatter.ofPattern(pattern, Locale.KOREAN))
    } catch (_: Exception) {
        ""
    }
}
