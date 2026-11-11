package com.dycdyp.youniya.data

import androidx.compose.ui.geometry.Offset
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.time.LocalDate
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import java.util.Locale

/**
 * 16장 월별 별자리: each month has the real constellation of its evening sky;
 * the month's stars fill its places in the order they were floated, and the rest float around it.
 */

data class ConstellationPoint(val x: Float, val y: Float)

data class ConstellationTemplate(
    val key: String,
    val name: String,
    val slots: List<ConstellationPoint>,
    val lines: List<List<Int>>,
) {
    companion object {
        private fun t(
            key: String,
            name: String,
            s: List<Pair<Double, Double>>,
            l: List<List<Int>>,
        ): ConstellationTemplate {
            return ConstellationTemplate(
                key = key,
                name = if (name.endsWith("자리")) name else "${name}자리",
                slots = s.map { ConstellationPoint(it.first.toFloat(), it.second.toFloat()) },
                lines = l.map { line -> line.map { it - 1 } },
            )
        }

        val byMonth: Map<Int, ConstellationTemplate> = mapOf(
            1 to t(
                "orion", "오리온자리",
                listOf(0.439 to 0.117, 0.249 to 0.233, 0.658 to 0.25, 0.38 to 0.5, 0.453 to 0.483, 0.526 to 0.467, 0.292 to 0.8, 0.702 to 0.773),
                listOf(listOf(1, 2), listOf(1, 3), listOf(2, 4), listOf(3, 6), listOf(4, 5), listOf(5, 6), listOf(4, 7), listOf(6, 8)),
            ),
            2 to t(
                "gemini", "쌍둥이자리",
                listOf(0.278 to 0.167, 0.512 to 0.15, 0.292 to 0.417, 0.249 to 0.667, 0.19 to 0.85, 0.512 to 0.433, 0.556 to 0.683, 0.629 to 0.85),
                listOf(listOf(1, 2), listOf(1, 3), listOf(3, 4), listOf(4, 5), listOf(2, 6), listOf(6, 7), listOf(7, 8), listOf(3, 6)),
            ),
            3 to t(
                "ursa_major", "큰곰자리",
                listOf(0.132 to 0.4, 0.292 to 0.333, 0.439 to 0.4, 0.585 to 0.467, 0.76 to 0.433, 0.789 to 0.633, 0.614 to 0.667),
                listOf(listOf(1, 2), listOf(2, 3), listOf(3, 4), listOf(4, 5), listOf(5, 6), listOf(6, 7), listOf(7, 4)),
            ),
            4 to t(
                "leo", "사자자리",
                listOf(0.322 to 0.7, 0.424 to 0.5, 0.38 to 0.35, 0.482 to 0.267, 0.585 to 0.317, 0.687 to 0.45, 0.848 to 0.6, 0.687 to 0.683),
                listOf(listOf(1, 2), listOf(2, 3), listOf(3, 4), listOf(4, 5), listOf(2, 6), listOf(6, 7), listOf(7, 8), listOf(8, 1), listOf(8, 6)),
            ),
            5 to t(
                "bootes", "목동자리",
                listOf(0.439 to 0.833, 0.322 to 0.633, 0.351 to 0.4, 0.482 to 0.233, 0.599 to 0.417, 0.57 to 0.633),
                listOf(listOf(1, 2), listOf(2, 3), listOf(3, 4), listOf(4, 5), listOf(5, 6), listOf(6, 1)),
            ),
            6 to t(
                "scorpius", "전갈자리",
                listOf(0.746 to 0.15, 0.766 to 0.283, 0.731 to 0.407, 0.599 to 0.45, 0.526 to 0.583, 0.503 to 0.717, 0.556 to 0.833, 0.649 to 0.873, 0.731 to 0.817),
                listOf(listOf(1, 2), listOf(2, 3), listOf(2, 4), listOf(4, 5), listOf(5, 6), listOf(6, 7), listOf(7, 8), listOf(8, 9)),
            ),
            7 to t(
                "cygnus", "백조자리",
                listOf(0.5 to 0.193, 0.5 to 0.38, 0.5 to 0.553, 0.5 to 0.807, 0.301 to 0.327, 0.181 to 0.247, 0.699 to 0.447, 0.819 to 0.513),
                listOf(listOf(1, 2), listOf(2, 3), listOf(3, 4), listOf(2, 5), listOf(5, 6), listOf(2, 7), listOf(7, 8)),
            ),
            8 to t(
                "lyra", "거문고자리",
                listOf(0.415 to 0.247, 0.535 to 0.38, 0.444 to 0.5, 0.57 to 0.733, 0.699 to 0.58),
                listOf(listOf(1, 2), listOf(2, 3), listOf(3, 4), listOf(4, 5), listOf(5, 2)),
            ),
            9 to t(
                "aquila", "독수리자리",
                listOf(0.5 to 0.467, 0.444 to 0.407, 0.556 to 0.527, 0.275 to 0.353, 0.725 to 0.58, 0.5 to 0.767, 0.585 to 0.22),
                listOf(listOf(4, 2), listOf(2, 1), listOf(1, 3), listOf(3, 5), listOf(1, 6), listOf(1, 7)).map { line -> line.map { it } },
            ),
            10 to t(
                "cassiopeia", "카시오페이아자리",
                listOf(0.146 to 0.367, 0.325 to 0.647, 0.5 to 0.433, 0.678 to 0.687, 0.854 to 0.313),
                listOf(listOf(1, 2), listOf(2, 3), listOf(3, 4), listOf(4, 5)),
            ),
            11 to t(
                "pegasus", "페가수스자리",
                listOf(0.395 to 0.4, 0.678 to 0.4, 0.678 to 0.667, 0.395 to 0.667, 0.784 to 0.3, 0.854 to 0.22, 0.251 to 0.313, 0.146 to 0.367, 0.287 to 0.767),
                listOf(listOf(1, 2), listOf(2, 3), listOf(3, 4), listOf(4, 1), listOf(2, 5), listOf(5, 6), listOf(1, 7), listOf(7, 8), listOf(4, 9)),
            ),
            12 to t(
                "taurus", "황소자리",
                listOf(0.497 to 0.583, 0.424 to 0.533, 0.351 to 0.467, 0.161 to 0.217, 0.541 to 0.517, 0.585 to 0.433, 0.716 to 0.2, 0.819 to 0.717),
                listOf(listOf(1, 2), listOf(2, 3), listOf(3, 4), listOf(1, 5), listOf(5, 6), listOf(6, 7), listOf(1, 8)),
            ),
        )
    }
}

data class MonthConstellation(
    val month: String, // "YYYY-MM"
    val name: String,
    val slots: List<Slot>,
    val lines: List<List<Int>>,
    val extra: List<Star>,
    val deep: Int? = null,
) {
    data class Star(
        val id: String,
        val title: String,
        val mood: Mood,
        val hasStarlight: Boolean,
        val starlight: Int? = null,
        val createdAt: String? = null,
        val isDeep: Boolean = false,
        val shape: StarShapeSpec? = null,
    )

    data class Slot(
        val point: ConstellationPoint,
        val star: Star?,
    )

    val filled: Int get() = slots.count { it.star != null }
    val total: Int get() = slots.size
    val isComplete: Boolean get() = filled == total && total > 0
    val stars: List<Star> get() = slots.mapNotNull { it.star } + extra
    val deepCount: Int get() = deep ?: stars.count { it.isDeep }

    val monthLabel: String
        get() = "${month.takeLast(2).toIntOrNull() ?: 0}월"

    val title: String
        get() = "$monthLabel · $name"

    fun isLit(line: List<Int>): Boolean {
        return line.size == 2 && line.all { idx -> idx < slots.size && slots[idx].star != null }
    }

    companion object {
        fun monthKey(date: ZonedDateTime?): String {
            val d = date ?: ZonedDateTime.now()
            return DateTimeFormatter.ofPattern("yyyy-MM", Locale.KOREAN).format(d)
        }

        fun monthKey(date: LocalDate): String {
            return DateTimeFormatter.ofPattern("yyyy-MM", Locale.KOREAN).format(date)
        }

        fun currentMonthKey(): String {
            return DateTimeFormatter.ofPattern("yyyy-MM", Locale.KOREAN).format(LocalDate.now())
        }

        fun shift(key: String, byMonths: Int): String {
            val parts = key.split("-").mapNotNull { it.toIntOrNull() }
            if (parts.size != 2) return key
            val total = parts[0] * 12 + (parts[1] - 1) + byMonths
            val year = total / 12
            val month = total % 12 + 1
            return "%04d-%02d".format(year, month)
        }

        fun local(key: String, stars: List<StarItem>): MonthConstellation {
            val m = key.takeLast(2).toIntOrNull() ?: 1
            val template = ConstellationTemplate.byMonth[m] ?: ConstellationTemplate.byMonth[11]!!
            val mine = stars
                .filter { it.parsedDate?.let { d -> monthKey(d) } == key }
                .sortedBy { it.parsedDate ?: ZonedDateTime.now() }
                .map { s ->
                    Star(
                        id = s.id,
                        title = s.title,
                        mood = s.mood,
                        hasStarlight = s.isFloated,
                        starlight = s.starlight ?: s.analysis?.starlight,
                        createdAt = s.createdAt,
                        isDeep = (s.analysis?.depthScore ?: 0) >= 280,
                        shape = s.shape ?: s.analysis?.shape?.toSpec(),
                    )
                }

            val slots = template.slots.mapIndexed { i, p ->
                Slot(point = p, star = if (i < mine.size) mine[i] else null)
            }

            return MonthConstellation(
                month = key,
                name = template.name,
                slots = slots,
                lines = template.lines,
                extra = if (mine.size > template.slots.size) mine.drop(template.slots.size) else emptyList(),
            )
        }
    }
}

// MARK: - Server DTOs

@Serializable
data class ServerConstellationsOverview(
    val items: List<ConstellationSummary> = emptyList(),
    @SerialName("cross_links") val crossLinks: List<List<String>> = emptyList(),
)

@Serializable
data class ConstellationSummary(
    val month: String,
    val key: String? = null,
    val name: String = "",
    val filled: Int = 0,
    val total: Int = 0,
    val complete: Boolean = false,
)

@Serializable
data class ServerConstellation(
    val month: String,
    val key: String? = null,
    val name: String,
    val slots: List<SlotOut> = emptyList(),
    val lines: List<List<Int>> = emptyList(),
    val extra: List<StarOut>? = null,
    val filled: Int? = null,
    val total: Int? = null,
    val complete: Boolean? = null,
    val lit: Int? = null,
    val unlit: Int? = null,
    val deep: Int? = null,
) {
    @Serializable
    data class SlotOut(
        val index: Int,
        val x: Double,
        val y: Double,
        val star: StarOut? = null,
    )

    @Serializable
    data class StarOut(
        val id: String,
        val title: String = "",
        val mood: Mood = Mood.calm,
        val moods: List<Mood>? = null,
        @SerialName("has_starlight") val hasStarlight: Boolean = false,
        val starlight: Int? = null,
        @SerialName("created_at") val createdAt: String? = null,
        val shape: ShapeOut? = null,
    )
}

@Serializable
data class ServerStory(
    val month: String,
    val key: String? = null,
    val name: String = "",
    val entries: List<ServerStoryEntry> = emptyList(),
)

@Serializable
data class ServerStoryEntry(
    @SerialName("star_id") val starId: String,
    val date: String? = null,
    val title: String = "",
    val sentence: String = "",
    @SerialName("has_starlight") val hasStarlight: Boolean = false,
)
