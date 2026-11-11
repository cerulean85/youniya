package com.dycdyp.youniya.ui.screens

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import com.dycdyp.youniya.data.AppModel
import com.dycdyp.youniya.ui.components.TopAppBar
import com.dycdyp.youniya.ui.design.StarField
import com.dycdyp.youniya.ui.design.cosmos
import com.dycdyp.youniya.ui.theme.Radius
import com.dycdyp.youniya.ui.theme.Space
import com.dycdyp.youniya.ui.theme.YColor
import com.dycdyp.youniya.ui.theme.YText
import com.dycdyp.youniya.ui.theme.sky
import java.time.YearMonth
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import java.util.Locale

private enum class FlowRange(val label: String) {
    Recent("최근 별"),
    Monthly("월평균"),
    All("전체"),
}

/**
 * 82 별빛 기록 · 밝기 흐름 (iOS BrightnessFlowView):
 * the user's own starlight over time, never compared.
 */
@Composable
fun BrightnessFlowView(
    model: AppModel,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var range by remember { mutableStateOf(FlowRange.Recent) }

    // Floated stars with starlight, oldest first
    val points = remember(model.stars) {
        model.stars.filter { it.isFloated && it.starlight != null && it.starlight > 0 }
            .sortedBy { it.parsedDate ?: ZonedDateTime.now() }
            .map { (it.parsedDate ?: ZonedDateTime.now()) to it.starlight!! }
    }

    val monthly = remember(points) {
        points.groupBy { YearMonth.from(it.first) }
            .map { (ym, pts) -> ym to (pts.map { it.second }.sum() / pts.size) }
            .sortedBy { it.first }
    }

    val series = remember(range, points, monthly) {
        val dFmt = DateTimeFormatter.ofPattern("M/d", Locale.KOREAN)
        val mFmt = DateTimeFormatter.ofPattern("M월", Locale.KOREAN)
        when (range) {
            FlowRange.Recent -> {
                val p = points.takeLast(8)
                SeriesData("최근 ${p.size}개의 별", p.map { it.second }, p.map { it.first.format(dFmt) })
            }
            FlowRange.Monthly -> {
                val m = monthly.takeLast(8)
                SeriesData("달마다 평균", m.map { it.second }, m.map { it.first.format(mFmt) })
            }
            FlowRange.All -> {
                SeriesData("전체 ${points.size}개의 별", points.map { it.second }, points.map { it.first.format(dFmt) })
            }
        }
    }

    BackHandler(onBack = onBack)
    Box(modifier.fillMaxSize()) {
        StarField()
        Column(Modifier.fillMaxSize()) {
            TopAppBar("별빛 기록", onBack = onBack)

            Column(
                modifier = Modifier
                    .weight(1f)
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = Space.xl)
                    .padding(top = Space.sm, bottom = Space.xl),
                verticalArrangement = Arrangement.spacedBy(Space.lg),
            ) {
                Column(
                    verticalArrangement = Arrangement.spacedBy(Space.sm),
                    modifier = Modifier.semantics { heading() },
                ) {
                    Text("나의 별빛 흐름", style = YText.h2, color = YColor.textPrimary)
                    Text(
                        "다른 사람과 비교하지 않아요. 지난날의 나와만 나란히 놓아 봐요.",
                        style = YText.bodyM,
                        color = YColor.textSecondary,
                    )
                }

                // Dot chips
                Row(horizontalArrangement = Arrangement.spacedBy(Space.sm)) {
                    FlowRange.entries.forEach { r ->
                        DotChip(title = r.label, isSelected = r == range, dot = sky().brandPrimary) {
                            range = r
                        }
                    }
                }

                if (points.size < 3) {
                    // 109 데이터 부족
                    EmptyStateView(
                        title = "흐름을 그리기엔 별이 조금 적어요",
                        message = "지금은 별이 ${points.size}개예요. 별이 더 모이면\n흐름을 선으로 이어 보여 드릴게요.",
                        modifier = Modifier.padding(top = Space.xxxl),
                    )
                } else {
                    TrendCard(series = series)
                    if (monthly.isNotEmpty()) {
                        MonthlyCard(monthly = monthly)
                    }
                }

                Text(
                    "숫자는 평가가 아니에요. 빛이 머물렀던 자리를 보여줄 뿐이에요.",
                    style = YText.caption,
                    color = YColor.textTertiary,
                )
            }
        }
    }
}

/** Trend card showing title, average, and chart */
@Composable
private fun TrendCard(
    series: SeriesData,
    modifier: Modifier = Modifier,
) {
    val average = if (series.values.isEmpty()) 0 else series.values.sum() / series.values.size
    val shape = RoundedCornerShape(Radius.lg)
    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(shape)
            .background(YColor.bgSurface, shape)
            .cosmos("trend", shape)
            .border(1.dp, YColor.borderDefault, shape)
            .padding(Space.lg),
        verticalArrangement = Arrangement.spacedBy(Space.md),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(series.title, style = YText.labelM, color = YColor.textPrimary)
            if (series.values.isNotEmpty()) {
                Text("평균 $average", style = YText.caption, color = YColor.textTertiary)
            }
        }

        if (series.values.size < 2) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(120.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text("별을 두 개 이상 띄우면 흐름이 그려져요.", style = YText.bodyS, color = YColor.textSecondary)
            }
        } else {
            TrendChart(values = series.values)
            XLabels(labels = series.labels)
        }
    }
}

private data class SeriesData(val title: String, val values: List<Int>, val labels: List<String>)

/** Labels under trend plot */
@Composable
private fun XLabels(labels: List<String>) {
    val picks = remember(labels) {
        if (labels.size <= 4) labels
        else {
            (0..3).map { i ->
                val idx = (i.toDouble() / 3.0 * (labels.size - 1)).toInt()
                labels[idx]
            }
        }
    }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(start = 36.dp, end = 6.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        picks.forEach { label ->
            Text(label, style = YText.caption, color = YColor.textTertiary)
        }
    }
}

/**
 * Figma `Plot` (170dp tall):
 * grid at 900, 700, 500, smooth line with soft area, the last point gold with value.
 */
@Composable
private fun TrendChart(values: List<Int>, modifier: Modifier = Modifier) {
    val a = sky()

    // 100 starlight = 25dp, 700 at y = 83dp of 170dp
    fun yPos(v: Int): Float = 83f - (v - 700f) * 0.25f

    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(170.dp),
    ) {
        // Grid lines and labels
        Column(
            modifier = Modifier.fillMaxSize(),
            verticalArrangement = Arrangement.SpaceBetween,
        ) {
            listOf(900, 700, 500).forEach { v ->
                val y = yPos(v)
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .offset(y = y.dp),
                ) {
                    Text(
                        v.toString(),
                        style = YText.caption,
                        color = YColor.textTertiary,
                        modifier = Modifier.offset(y = (-8).dp),
                    )
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(start = 32.dp)
                            .height(1.dp)
                            .background(YColor.borderDefault.copy(alpha = 0.6f)),
                    )
                }
            }
        }

        // Plot canvas
        Canvas(modifier = Modifier.fillMaxSize()) {
            val left = 36.dp.toPx()
            val right = 6.dp.toPx()
            val w = size.width - left - right
            val step = if (values.size > 1) w / (values.size - 1) else 0f

            val pts = values.mapIndexed { i, v ->
                val y = yPos(v).dp.toPx().coerceIn(4.dp.toPx(), 166.dp.toPx())
                Offset(left + i * step, y)
            }

            if (pts.size >= 2) {
                // Line path
                val strokePath = Path().apply {
                    moveTo(pts[0].x, pts[0].y)
                    for (i in 1 until pts.size) {
                        val p0 = pts[i - 1]
                        val p1 = pts[i]
                        val c1 = Offset(p0.x + (p1.x - p0.x) / 2f, p0.y)
                        val c2 = Offset(p0.x + (p1.x - p0.x) / 2f, p1.y)
                        cubicTo(c1.x, c1.y, c2.x, c2.y, p1.x, p1.y)
                    }
                }

                // Fill area path
                val fillPath = Path().apply {
                    addPath(strokePath)
                    lineTo(pts.last().x, 159.dp.toPx())
                    lineTo(pts.first().x, 159.dp.toPx())
                    close()
                }

                drawPath(fillPath, color = a.brandPrimary.copy(alpha = 0.14f))
                drawPath(strokePath, color = a.brandPrimary, style = Stroke(width = 2.dp.toPx()))

                // Circles on previous points
                for (i in 0 until pts.size - 1) {
                    drawCircle(a.brandPrimary, radius = 2.5.dp.toPx(), center = pts[i])
                }

                // Gold circle on last point
                val last = pts.last()
                drawCircle(YColor.starBright.copy(alpha = 0.5f), radius = 7.dp.toPx(), center = last)
                drawCircle(YColor.starBright, radius = 5.dp.toPx(), center = last)
            }
        }

        // Last point starlight text
        if (values.isNotEmpty()) {
            val left = 36.dp
            val right = 6.dp
            // We can place text at top right near the last point
            Text(
                values.last().toString(),
                style = YText.labelS,
                color = YColor.starBright,
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .offset(x = (-10).dp, y = (yPos(values.last()) - 18).dp),
            )
        }
    }
}

/** Monthly average bars card */
@Composable
private fun MonthlyCard(
    monthly: List<Pair<YearMonth, Int>>,
    modifier: Modifier = Modifier,
) {
    val a = sky()
    val shape = RoundedCornerShape(Radius.lg)
    val rows = remember(monthly) { monthly.takeLast(3) }
    val currentYm = remember { YearMonth.now() }

    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(shape)
            .background(YColor.bgSurface, shape)
            .cosmos("monthly", shape)
            .border(1.dp, YColor.borderDefault, shape)
            .padding(Space.lg),
        verticalArrangement = Arrangement.spacedBy(Space.md),
    ) {
        Text("월평균 별빛", style = YText.labelM, color = YColor.textPrimary)

        rows.forEach { (ym, avg) ->
            val isCurrent = ym == currentYm
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(Space.md),
            ) {
                Text(
                    "${ym.monthValue}월",
                    style = YText.labelS,
                    color = YColor.textSecondary,
                    modifier = Modifier.width(32.dp),
                )
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .height(6.dp)
                        .background(YColor.borderDefault.copy(alpha = 0.5f), CircleShape),
                ) {
                    // 1dp per 5 starlight
                    val barWidth = (avg / 5f).dp
                    Box(
                        modifier = Modifier
                            .width(barWidth)
                            .height(6.dp)
                            .background(if (isCurrent) YColor.starBright else a.brandPrimary, CircleShape),
                    )
                }
                Text(
                    if (isCurrent) "$avg · 진행 중" else "$avg",
                    style = YText.caption,
                    color = YColor.textSecondary,
                )
            }
        }
    }
}
