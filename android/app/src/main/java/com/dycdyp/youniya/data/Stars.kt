package com.dycdyp.youniya.data

import androidx.compose.ui.graphics.Color
import com.dycdyp.youniya.ui.theme.YColor
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonObject
import java.time.Instant
import java.time.OffsetDateTime
import java.time.ZoneId
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import java.util.Locale

@Serializable
enum class Mood(val label: String) {
    @SerialName("calm") calm("평온"),
    @SerialName("sorrow") sorrow("슬픔"),
    @SerialName("anger") anger("분노"),
    @SerialName("insight") insight("통찰");

    val color: Color
        get() = when (this) {
            calm -> YColor.emotionCalm
            sorrow -> YColor.emotionSorrow
            anger -> YColor.emotionAnger
            insight -> YColor.emotionInsight
        }

    val tint: Color
        get() = color.copy(alpha = 0.16f)
}

@Serializable
data class StarShapeSpec(
    val points: Int,
    val sharpness: Sharpness,
) {
    @Serializable
    enum class Sharpness(val label: String, val inner: Float) {
        @SerialName("soft") soft("둥근", 0.55f),
        @SerialName("normal") normal("보통 뾰족함", 0.418f),
        @SerialName("sharp") sharp("아주 뾰족함", 0.3f);
    }

    val label: String get() = "꼭짓점 ${points}개 · ${sharpness.label}"
}

@Serializable
data class ShapeOut(
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
data class LinkedOut(val id: String)

@Serializable
data class ServerStar(
    val id: String,
    val title: String = "",
    val mood: Mood = Mood.calm,
    val moods: List<Mood>? = null,
    val state: String = "kept", // "floated" | "kept"
    val createdAt: String? = null,
    val updatedAt: String? = null,
    val starlight: Int? = null,
    val rewriteOf: String? = null,
    val starlightCancelled: Boolean? = null,
    val shape: ShapeOut? = null,
    val analysisFailed: Boolean = false,
    val shared: Boolean = false,
    val lineCount: Int? = null,
    val linkedStars: List<LinkedOut>? = null,
    val body: String? = null,
    val analysis: ServerAnalysis? = null,
    val prismVersion: String? = null,
)

@Serializable
data class ServerAnalysis(
    val starlight: Int = 0,
    val depth: Double = 0.0,
    val clarity: Double = 0.0,
    val weight: Double = 0.0,
    val depthLevel: Int? = null,
    val moods: List<Share> = emptyList(),
    val observation: String = "",
    val telescopeTeaser: String? = null,
    val rewriteQuestion: String? = null,
    val depthReason: String? = null,
    val clarityReason: String? = null,
    val weightReason: String? = null,
    val interpretation: String? = null,
    val shape: ShapeOut? = null,
    val prismVersion: String? = null,
) {
    @Serializable
    data class Share(val mood: Mood, val share: Int)

    val depthScore: Int get() = kotlin.math.round(depth * 400).toInt()
    val clarityScore: Int get() = kotlin.math.round(clarity * 300).toInt()
    val weightScore: Int get() = kotlin.math.round(weight * 300).toInt()
    val tones: List<Mood> get() = moods.sortedByDescending { it.share }.map { it.mood }
}

@Serializable
data class StarCreated(
    val star: ServerStar,
    val crisis: JsonObject? = null,
    val charged: Int? = null,
    val coins: Int? = null,
    val quoteMissing: Boolean? = null,
)

@Serializable
data class CancelOut(
    val status: String? = null,
    val star: ServerStar? = null,
    val refunded: Boolean? = null,
    val coins: Int? = null,
)

@Serializable
data class FloatIn(val attemptId: String)

@Serializable
data class StarList(
    val items: List<ServerStar> = emptyList(),
    val nextBefore: String? = null,
)

@Serializable
data class DraftIn(
    val mood: Mood,
    val moods: List<Mood>,
    val title: String,
    val body: String,
)

@Serializable
data class ServerDraft(
    val mood: Mood = Mood.calm,
    val moods: List<Mood>? = null,
    val title: String = "",
    val body: String = "",
)

@Serializable
data class StarIn(
    val mood: Mood,
    val moods: List<Mood>,
    val title: String,
    val body: String,
    val mode: String,
    val rewriteOf: String? = null,
    val linkTo: List<String>? = null,
    val attemptId: String? = null,
)

private val KST = ZoneId.of("Asia/Seoul")
private val DateFormatKst = DateTimeFormatter.ofPattern("M월 d일 · HH:mm", Locale.KOREAN)

fun formatKstDate(iso: String?): String {
    if (iso.isNullOrBlank()) {
        return DateFormatKst.format(ZonedDateTime.now(KST))
    }
    return try {
        val instant = Instant.parse(iso)
        DateFormatKst.format(instant.atZone(KST))
    } catch (_: Exception) {
        try {
            val odt = OffsetDateTime.parse(iso)
            DateFormatKst.format(odt.atZoneSameInstant(KST))
        } catch (_: Exception) {
            iso
        }
    }
}

fun ServerStar.toItem(local: StarItem? = null): StarItem {
    val isFloated = state == "floated"
    val shapeSpec = shape?.toSpec() ?: analysis?.shape?.toSpec() ?: local?.shape
    val extra = if ((moods?.size ?: 0) > 1) moods?.drop(1) else local?.extraMoods
    val formattedPrism = prismVersion?.let { v ->
        val parts = v.split("-")
        if (parts.size > 1) "별빛 프리즘 ${parts[1]}" else "별빛 프리즘"
    }
    val finalAnalysis = (analysis ?: local?.analysis)?.let { a ->
        if (a.prismVersion == null && formattedPrism != null) a.copy(prismVersion = formattedPrism) else a
    }
    return StarItem(
        id = id,
        title = title.ifBlank { "제목 없는 별" },
        dateText = formatKstDate(createdAt),
        floated = isFloated,
        starlight = starlight ?: finalAnalysis?.starlight ?: local?.starlight,
        mood = mood,
        extraMoods = extra,
        body = body ?: local?.body ?: "",
        analysis = finalAnalysis,
        createdAt = createdAt ?: local?.createdAt,
        rewriteOf = rewriteOf ?: local?.rewriteOf,
        shared = shared,
        linkedIds = linkedStars?.map { it.id } ?: local?.linkedIds,
        shape = shapeSpec,
    )
}

@Serializable
data class StarItem(
    val id: String,
    val title: String,
    val dateText: String,
    val floated: Boolean,
    val starlight: Int? = null,
    val mood: Mood = Mood.calm,
    val extraMoods: List<Mood>? = null,
    val body: String = "",
    val analysis: ServerAnalysis? = null,
    val createdAt: String? = null,
    val rewriteOf: String? = null,
    val shared: Boolean = false,
    val linkedIds: List<String>? = null,
    val shape: StarShapeSpec? = null,
) {
    val isFloated: Boolean get() = floated

    val allMoods: List<Mood>
        get() = listOf(mood) + (extraMoods ?: emptyList())
}

@Serializable
data class StarDraft(
    val mood: Mood = Mood.calm,
    val extraMoods: List<Mood>? = null,
    val title: String = "",
    val body: String = "",
) {
    val moods: List<Mood>
        get() = listOf(mood) + (extraMoods ?: emptyList())

    fun toggle(m: Mood): StarDraft {
        val all = moods.toMutableList()
        if (all.contains(m)) {
            if (all.size <= 1) return this
            all.remove(m)
        } else {
            all.add(m)
        }
        val newMood = all[0]
        val newExtra = if (all.size > 1) all.drop(1) else null
        return copy(mood = newMood, extraMoods = newExtra)
    }

    val isEmpty: Boolean
        get() = title.trim().isEmpty() && body.trim().isEmpty()
}
