package com.dycdyp.youniya.ui.screens

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.BlurredEdgeTreatment
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.dycdyp.youniya.data.AppModel
import com.dycdyp.youniya.data.MonthConstellation
import com.dycdyp.youniya.data.StarItem
import com.dycdyp.youniya.ui.components.StarRow
import com.dycdyp.youniya.ui.components.TopAppBar
import com.dycdyp.youniya.ui.components.noRippleClick
import com.dycdyp.youniya.ui.design.SeededRandom
import com.dycdyp.youniya.ui.design.StarField
import com.dycdyp.youniya.ui.design.cosmos
import com.dycdyp.youniya.ui.theme.NotoSerifKR
import com.dycdyp.youniya.ui.theme.Pretendard
import com.dycdyp.youniya.ui.theme.Radius
import com.dycdyp.youniya.ui.theme.Space
import com.dycdyp.youniya.ui.theme.YColor
import com.dycdyp.youniya.ui.theme.YText
import com.dycdyp.youniya.ui.theme.sky
import java.time.LocalDate
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import java.util.Locale
import kotlin.math.abs
import kotlin.math.min
import kotlin.math.pow

// MARK: - 89 / 90 나의 별

enum class NebulaStarKind(val label: String) {
    Floated("떠 있는 별"),
    Deep("깊은 별"),
    Supernova("초신성");

    val note: String
        get() = when (this) {
            Floated -> "지금 하늘에 떠 있는 별이에요. 누르면 그날의 기록이 열려요."
            Deep -> "마음을 깊이 들여다본 별이에요. 누르면 그날의 기록이 열려요."
            Supernova -> "별빛이 900을 넘어 크게 빛난 별이에요."
        }

    val emptyTitle: String
        get() = when (this) {
            Floated -> "아직 떠 있는 별이 없어요"
            Deep -> "아직 깊은 별이 없어요"
            Supernova -> "아직 초신성이 된 별은 없어요"
        }

    val emptyMessage: String
        get() = when (this) {
            Floated -> "오늘의 마음을 별로 띄우면\n이곳에 하나씩 모여요."
            Deep -> "마음을 천천히 들여다본 날의 별이\n깊은 별로 남아요."
            Supernova -> "마음을 깊이 들여다본 날, 별빛이 900을 넘으면\n초신성으로 터져요. 서두르지 않아도 괜찮아요."
        }

    fun includes(star: StarItem): Boolean = when (this) {
        Floated -> star.isFloated
        Deep -> (star.analysis?.depthScore ?: 0) >= 280
        Supernova -> (star.starlight ?: star.analysis?.starlight ?: 0) >= 900
    }
}

data class MonthStarGroup(
    val month: String,
    val title: String,
    val stars: List<StarItem>,
)

@Composable
fun NebulaStarsView(
    model: AppModel,
    initialKind: NebulaStarKind = NebulaStarKind.Floated,
    onBack: () -> Unit,
    onOpenStar: (StarItem) -> Unit,
    modifier: Modifier = Modifier,
) {
    var currentKind by remember { mutableStateOf(initialKind) }
    val stars = remember(model.stars, currentKind) {
        model.stars.filter { currentKind.includes(it) }
    }

    val groups = remember(stars) {
        val sorted = stars.sortedByDescending { it.parsedDate ?: ZonedDateTime.now() }
        val list = mutableListOf<MonthStarGroup>()
        for (star in sorted) {
            val key = star.parsedDate?.let { MonthConstellation.monthKey(it) } ?: "?"
            val lastGroup = list.lastOrNull()
            if (lastGroup?.month == key) {
                list[list.size - 1] = lastGroup.copy(stars = lastGroup.stars + star)
            } else {
                val parts = key.split("-")
                val title = if (parts.size == 2) "${parts[0]}년 ${parts[1].toIntOrNull() ?: 0}월" else "날짜 없음"
                list.add(MonthStarGroup(month = key, title = title, stars = listOf(star)))
            }
        }
        list
    }

    Box(modifier = modifier.fillMaxSize()) {
        StarField()

        Column(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding(),
        ) {
            TopAppBar(title = "나의 별", onBack = onBack)

            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = Space.xl, vertical = Space.lg),
                verticalArrangement = Arrangement.spacedBy(Space.lg),
            ) {
                // Filter chips
                Row(horizontalArrangement = Arrangement.spacedBy(Space.sm)) {
                    NebulaStarKind.entries.forEach { k ->
                        val count = model.stars.count { k.includes(it) }
                        FilterChip(
                            title = "${k.label} $count",
                            isSelected = k == currentKind,
                            onClick = { currentKind = k },
                        )
                    }
                }

                Text(
                    text = currentKind.note,
                    style = YText.bodyS,
                    color = YColor.textSecondary,
                )

                if (stars.isEmpty()) {
                    // 90 Empty State
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(top = 96.dp),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(Space.md),
                    ) {
                        Canvas(modifier = Modifier.size(40.dp)) {
                            drawCircle(color = YColor.starBright.copy(alpha = 0.8f), radius = size.minDimension / 2f)
                        }
                        Text(
                            text = currentKind.emptyTitle,
                            style = YText.h3,
                            color = YColor.textPrimary,
                            textAlign = TextAlign.Center,
                        )
                        Text(
                            text = currentKind.emptyMessage,
                            style = YText.bodyM,
                            color = YColor.textSecondary,
                            textAlign = TextAlign.Center,
                        )
                    }
                } else {
                    Column(verticalArrangement = Arrangement.spacedBy(Space.md)) {
                        groups.forEachIndexed { i, group ->
                            MonthDivider(
                                title = group.title,
                                modifier = if (i > 0) Modifier.padding(top = Space.sm) else Modifier,
                            )
                            group.stars.forEach { star ->
                                StarRow(star = star, onClick = { onOpenStar(star) })
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun MonthDivider(title: String, modifier: Modifier = Modifier) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .semantics(mergeDescendants = true) { heading() },
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Space.md),
    ) {
        Text(title, style = YText.labelS, color = YColor.textTertiary)
        Box(
            modifier = Modifier
                .weight(1f)
                .height(1.dp)
                .background(YColor.borderDefault),
        )
    }
}

@Composable
fun FilterChip(
    title: String,
    isSelected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val a = sky()
    Box(
        modifier = modifier
            .clip(CircleShape)
            .noRippleClick(onClick)
            .cosmos("chip-$title", CircleShape, intensity = 0.6)
            .background(if (isSelected) a.tintPrimary else YColor.bgSurface, CircleShape)
            .border(1.dp, if (isSelected) a.brandPrimary else YColor.borderDefault, CircleShape)
            .padding(horizontal = Space.md, vertical = Space.sm),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = title,
            style = YText.labelS,
            color = if (isSelected) YColor.textPrimary else YColor.textSecondary,
        )
    }
}

// MARK: - 81 나의 은하수

@Composable
fun MilkyWayView(
    model: AppModel,
    onBack: () -> Unit,
    onOpenStar: (StarItem) -> Unit,
    modifier: Modifier = Modifier,
) {
    val timeline = remember(model.stars) {
        model.stars
            .filter { it.parsedDate != null }
            .sortedBy { it.parsedDate }
    }

    val currentMonthKey = MonthConstellation.currentMonthKey()
    val album = remember(timeline, currentMonthKey) {
        timeline
            .filter { it.isFloated && MonthConstellation.monthKey(it.parsedDate) == currentMonthKey }
            .reversed()
    }
    val currentMonthNum = LocalDate.now().monthValue

    Box(modifier = modifier.fillMaxSize()) {
        StarField()

        Column(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding(),
        ) {
            TopAppBar(title = "나의 은하수", onBack = onBack)

            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = Space.xl, vertical = Space.lg),
                verticalArrangement = Arrangement.spacedBy(Space.lg),
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .semantics(mergeDescendants = true) { heading() },
                    verticalArrangement = Arrangement.spacedBy(Space.xs),
                ) {
                    Text(
                        text = "시간의 길을 따라 흐르는 은하수",
                        style = YText.h2,
                        color = YColor.textPrimary,
                    )
                    Text(
                        text = "달마다 채운 별자리가 시간순으로 이어져요. 은빛 점선은 서로 다른 달의 별을 이은 별 잇기예요.",
                        style = YText.bodyM,
                        color = YColor.textSecondary,
                    )
                }

                GalaxyRiver(
                    timeline = timeline,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(300.dp),
                )

                // Album Header
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.SpaceBetween,
                ) {
                    Text(
                        text = "별 카드 앨범",
                        style = YText.labelM,
                        color = YColor.textPrimary,
                    )
                    Text(
                        text = "${currentMonthNum}월 · ${album.size}장",
                        style = YText.caption,
                        color = YColor.textTertiary,
                    )
                }

                if (album.isEmpty()) {
                    Text(
                        text = "별을 띄우면 이곳에 카드로 모여요.",
                        style = YText.bodyS,
                        color = YColor.textSecondary,
                    )
                } else {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .horizontalScroll(rememberScrollState()),
                        horizontalArrangement = Arrangement.spacedBy(10.dp),
                    ) {
                        album.forEach { star ->
                            AlbumCard(star = star, onClick = { onOpenStar(star) })
                        }
                    }
                }

                Text(
                    text = "은하수는 별이 쌓일수록 길어져요. 지난 시간을 다시 걷고 싶을 때 천천히 들러 보세요.",
                    style = YText.caption,
                    color = YColor.textTertiary,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        }
    }
}

@Composable
private fun AlbumCard(
    star: StarItem,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val shape = RoundedCornerShape(Radius.lg)
    Column(
        modifier = modifier
            .width(118.dp)
            .noRippleClick(onClick)
            .cosmos("album-${star.id}", shape)
            .background(YColor.bgSurface, shape)
            .border(1.dp, YColor.borderDefault, shape)
            .padding(Space.lg),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Canvas(modifier = Modifier.size(10.dp)) {
            drawCircle(color = star.mood.color)
        }
        Text(
            text = "${star.starlight ?: 0}",
            style = YText.h3,
            color = YColor.textPrimary,
        )
        Text(
            text = star.title,
            style = YText.labelS,
            color = YColor.textSecondary,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
        )
        Text(
            text = star.shortDateText,
            style = YText.caption,
            color = YColor.textTertiary,
        )
    }
}

// MARK: - GalaxyRiver

@Composable
fun GalaxyRiver(
    timeline: List<StarItem>,
    modifier: Modifier = Modifier,
) {
    val shape = RoundedCornerShape(Radius.lg)
    val a = sky()

    BoxWithConstraints(
        modifier = modifier
            .clip(shape)
            .cosmos("galaxy", shape)
            .background(YColor.bgSurface, shape)
            .border(1.dp, YColor.borderDefault, shape),
    ) {
        val widthPx = constraints.maxWidth.toFloat()
        val heightPx = constraints.maxHeight.toFloat()
        val n = timeline.size
        val tFunc: (Int) -> Double = { i ->
            if (n > 1) 0.04 + 0.92 * i.toDouble() / (n - 1).toDouble() else 0.96
        }

        val dpScale = androidx.compose.ui.platform.LocalDensity.current.density
        val riverPath = remember(widthPx, dpScale) {
            val sx = widthPx / 342f
            fun y(v: Float) = (v + 45f) * dpScale
            Path().apply {
                moveTo(0f, y(205f))
                cubicTo(80f * sx, y(170f), 110f * sx, y(105f), 175f * sx, y(105f))
                cubicTo(240f * sx, y(105f), 270f * sx, y(25f), 342f * sx, y(0f))
            }
        }
        // iOS: the river is two blurred strokes (Figma layer blur 30 ≈ SwiftUI 15, and 7).
        Canvas(Modifier.fillMaxSize().blur(15.dp, BlurredEdgeTreatment.Unbounded)) {
            drawPath(riverPath, a.brandPrimary.copy(alpha = 0.3f), style = Stroke(width = 80.dp.toPx(), cap = StrokeCap.Round))
        }
        Canvas(Modifier.fillMaxSize().blur(7.dp, BlurredEdgeTreatment.Unbounded)) {
            drawPath(riverPath, YColor.starClear.copy(alpha = 0.16f), style = Stroke(width = 26.dp.toPx(), cap = StrokeCap.Round))
        }

        Canvas(modifier = Modifier.fillMaxSize()) {
            // Star dots
            for (i in timeline.indices) {
                val item = timeline[i]
                val rng = SeededRandom(item.id)
                val p = riverPoint(tFunc(i), widthPx, dpScale)
                val d = rng.next(2.0, 5.0).toFloat()
                val alpha = rng.next(0.6, 0.95).toFloat()
                val scatterX = rng.next(-14.0, 14.0).toFloat()
                val scatterY = rng.next(-14.0, 14.0).toFloat()

                drawCircle(
                    color = item.mood.color.copy(alpha = alpha),
                    radius = d / 2f * dpScale,
                    center = Offset(p.x + scatterX * dpScale, p.y + scatterY * dpScale),
                )
            }

            // Cross-month links: silver dotted lines
            val dashCross = PathEffect.dashPathEffect(floatArrayOf(1.5.dp.toPx(), 3.5.dp.toPx()))
            val idMap = timeline.mapIndexed { idx, it -> it.id to idx }.toMap()
            for (i in timeline.indices) {
                val item = timeline[i]
                val itemMonth = item.parsedDate?.let { MonthConstellation.monthKey(it) }
                for (otherId in item.linkedIds ?: emptyList()) {
                    val j = idMap[otherId] ?: continue
                    if (j <= i) continue
                    val otherMonth = timeline[j].parsedDate?.let { MonthConstellation.monthKey(it) }
                    if (itemMonth != null && otherMonth != null && itemMonth != otherMonth) {
                        val pa = riverPoint(tFunc(i), widthPx, dpScale)
                        val pb = riverPoint(tFunc(j), widthPx, dpScale)
                        val lift = min(90f * dpScale, abs(pb.x - pa.x) * 0.45f + 30f * dpScale)
                        val arc = Path().apply {
                            moveTo(pa.x, pa.y)
                            quadraticTo((pa.x + pb.x) / 2f, min(pa.y, pb.y) - lift, pb.x, pb.y)
                        }
                        drawPath(
                            path = arc,
                            color = Color.White.copy(alpha = 0.55f),
                            style = Stroke(width = 1.dp.toPx(), pathEffect = dashCross),
                        )
                    }
                }
            }
        }

        // Month markers
        val months = remember(timeline) {
            val seen = mutableSetOf<String>()
            val marks = mutableListOf<Pair<Double, String>>()
            timeline.forEachIndexed { i, it ->
                val parsed = it.parsedDate ?: return@forEachIndexed
                val m = MonthConstellation.monthKey(parsed)
                if (seen.add(m)) {
                    val label = "${parsed.monthValue}월"
                    marks.add(tFunc(i) to label)
                }
            }
            marks.takeLast(4)
        }

        val density = androidx.compose.ui.platform.LocalDensity.current
        months.forEachIndexed { idx, mark ->
            val p = riverPoint(mark.first, widthPx, dpScale)
            val isNow = idx == months.size - 1
            val dpX = with(density) { p.x.toDp() }
            val dpY = with(density) { p.y.toDp() }

            // Ring
            Canvas(
                modifier = Modifier
                    .offset(x = dpX - 9.dp, y = dpY - 9.dp)
                    .size(18.dp),
            ) {
                drawCircle(
                    color = if (isNow) YColor.starBright else YColor.textSecondary.copy(alpha = 0.5f),
                    radius = size.minDimension / 2f - 0.6.dp.toPx(),
                    style = Stroke(width = 1.2.dp.toPx()),
                )
            }

            // Month text
            Text(
                text = mark.second,
                style = YText.caption,
                color = if (isNow) YColor.starBright else YColor.textTertiary,
                modifier = Modifier.offset(x = dpX - 12.dp, y = dpY + 14.dp),
            )

            // "지금 여기"
            if (isNow) {
                Text(
                    text = "지금 여기",
                    style = YText.caption,
                    color = YColor.starBright,
                    // iOS: centered on the ring, kept 28 from either edge.
                    modifier = Modifier.offset(x = dpX.coerceIn(28.dp, maxWidth - 28.dp) - 24.dp, y = dpY - 30.dp),
                )
            }
        }
    }
}

/** A point on the Figma river path (342-wide box, y offset 45), in px: x scales with the width, y is in dp. */
private fun riverPoint(t: Double, widthPx: Float, dp: Float): Offset {
    val sx = widthPx / 342f
    fun bez(p0: Offset, p1: Offset, p2: Offset, p3: Offset, u: Double): Offset {
        val a = (1 - u).pow(3)
        val b = 3 * (1 - u).pow(2) * u
        val c = 3 * (1 - u) * u * u
        val d = u.pow(3)
        return Offset(
            (a * p0.x + b * p1.x + c * p2.x + d * p3.x).toFloat(),
            (a * p0.y + b * p1.y + c * p2.y + d * p3.y).toFloat(),
        )
    }

    val p = if (t < 0.5) {
        bez(Offset(0f, 205f), Offset(80f, 170f), Offset(110f, 105f), Offset(175f, 105f), t * 2)
    } else {
        bez(Offset(175f, 105f), Offset(240f, 105f), Offset(270f, 25f), Offset(342f, 0f), t * 2 - 1)
    }
    return Offset(p.x * sx, (p.y + 45f) * dp)
}
