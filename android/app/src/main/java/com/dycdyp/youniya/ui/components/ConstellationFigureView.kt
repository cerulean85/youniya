package com.dycdyp.youniya.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.dycdyp.youniya.data.MonthConstellation
import com.dycdyp.youniya.data.StarShapeSpec
import com.dycdyp.youniya.data.formatKstShortDate
import com.dycdyp.youniya.ui.design.SeededRandom
import com.dycdyp.youniya.ui.design.ShapeStar
import com.dycdyp.youniya.ui.theme.Pretendard
import com.dycdyp.youniya.ui.theme.YColor
import java.time.Instant
import java.time.OffsetDateTime
import java.time.ZoneId
import java.time.ZonedDateTime
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.sin

/**
 * Draws a [MonthConstellation] (08-3, 04 card, 70/77):
 * lines in gold when both ends are filled, otherwise faint dashes;
 * filled places as mood-colored stars (lit ones larger and glowing, unlit ones small and faint);
 * empty places as dashed rings; extra stars floating faintly around the figure.
 */
@Composable
fun ConstellationFigureView(
    constellation: MonthConstellation,
    modifier: Modifier = Modifier,
    compact: Boolean = false,
    selected: String? = null,
    silverLinks: List<String> = emptyList(),
    shapes: Map<String, StarShapeSpec>? = null,
    onTap: ((MonthConstellation.Star) -> Unit)? = null,
) {
    val k = if (compact) 0.6f else 1.0f

    BoxWithConstraints(modifier = modifier.fillMaxSize()) {
        val widthPx = constraints.maxWidth.toFloat()
        val heightPx = constraints.maxHeight.toFloat()
        val density = androidx.compose.ui.platform.LocalDensity.current

        val pts = constellation.slots.map { slot ->
            Offset(slot.point.x * widthPx, slot.point.y * heightPx)
        }

        // 1. Draw Lines on Canvas
        Canvas(modifier = Modifier.fillMaxSize()) {
            val dashWaiting = PathEffect.dashPathEffect(floatArrayOf(2.dp.toPx(), 4.dp.toPx()))
            val dashSilver = PathEffect.dashPathEffect(floatArrayOf(1.5.dp.toPx(), 3.dp.toPx()))

            // Waiting lines first
            for (line in constellation.lines) {
                if (!constellation.isLit(line) && line.size == 2 && line[0] < pts.size && line[1] < pts.size) {
                    val p = Path().apply {
                        moveTo(pts[line[0]].x, pts[line[0]].y)
                        lineTo(pts[line[1]].x, pts[line[1]].y)
                    }
                    drawPath(
                        path = p,
                        color = YColor.textTertiary.copy(alpha = 0.35f),
                        style = Stroke(width = 1.dp.toPx(), pathEffect = dashWaiting),
                    )
                }
            }

            // Gold lines over them
            for (line in constellation.lines) {
                if (constellation.isLit(line) && line.size == 2 && line[0] < pts.size && line[1] < pts.size) {
                    val p = Path().apply {
                        moveTo(pts[line[0]].x, pts[line[0]].y)
                        lineTo(pts[line[1]].x, pts[line[1]].y)
                    }
                    drawPath(
                        path = p,
                        color = YColor.starBright.copy(alpha = 0.6f),
                        style = Stroke(width = if (compact) 0.8.dp.toPx() else 1.2.dp.toPx()),
                    )
                }
            }

            // Silver dotted lines from selected star to linked stars in this month
            if (selected != null) {
                val from = findPointOf(selected, constellation, pts, widthPx, heightPx)
                if (from != null) {
                    for (linkId in silverLinks) {
                        val to = findPointOf(linkId, constellation, pts, widthPx, heightPx)
                        if (to != null) {
                            val p = Path().apply {
                                moveTo(from.x, from.y)
                                lineTo(to.x, to.y)
                            }
                            drawPath(
                                path = p,
                                color = Color.White.copy(alpha = 0.75f),
                                style = Stroke(width = 1.dp.toPx(), pathEffect = dashSilver),
                            )
                        }
                    }
                }
            }
        }

        // 2. Extra stars
        constellation.extra.forEachIndexed { i, s ->
            val pt = extraPoint(i, widthPx, heightPx, constellation.month)
            val dpX = with(density) { pt.x.toDp() }
            val dpY = with(density) { pt.y.toDp() }

            Box(
                modifier = Modifier
                    .offset(x = dpX - 16.dp, y = dpY - 16.dp)
                    .size(32.dp),
                contentAlignment = Alignment.Center,
            ) {
                Dot(
                    star = s,
                    k = k * 0.7f,
                    faint = true,
                    isSelected = selected == s.id,
                    spec = null,
                    onTap = onTap,
                )
            }
        }

        // 3. Slot stars or empty rings
        constellation.slots.forEachIndexed { i, slot ->
            val pt = pts[i]
            val dpX = with(density) { pt.x.toDp() }
            val dpY = with(density) { pt.y.toDp() }

            Box(
                modifier = Modifier
                    .offset(x = dpX - 16.dp, y = dpY - 16.dp)
                    .size(32.dp),
                contentAlignment = Alignment.Center,
            ) {
                if (slot.star != null) {
                    Dot(
                        star = slot.star,
                        k = k,
                        faint = false,
                        isSelected = selected == slot.star.id,
                        spec = shapes?.get(slot.star.id),
                        onTap = onTap,
                    )
                } else {
                    EmptySlotRing(k = k)
                }
            }
        }
    }
}

@Composable
private fun EmptySlotRing(k: Float) {
    Canvas(modifier = Modifier.size((9 * k).dp)) {
        val dash = PathEffect.dashPathEffect(floatArrayOf(2.dp.toPx(), 2.dp.toPx()))
        drawCircle(
            color = YColor.textTertiary.copy(alpha = 0.5f),
            radius = size.minDimension / 2f - 0.5.dp.toPx(),
            style = Stroke(width = 1.dp.toPx(), pathEffect = dash),
        )
    }
}

@Composable
private fun Dot(
    star: MonthConstellation.Star,
    k: Float,
    faint: Boolean,
    isSelected: Boolean,
    spec: StarShapeSpec?,
    onTap: ((MonthConstellation.Star) -> Unit)?,
) {
    if (spec != null && !faint) {
        ShapeDot(star = star, spec = spec)
    } else {
        PlainDot(star = star, k = k, faint = faint, isSelected = isSelected, onTap = onTap)
    }
}

@Composable
private fun ShapeDot(
    star: MonthConstellation.Star,
    spec: StarShapeSpec?,
) {
    Box(
        modifier = Modifier.size(38.dp),
        contentAlignment = Alignment.Center,
    ) {
        if (star.hasStarlight) {
            ShapeStar(
                spec = spec ?: StarShapeSpec(5, StarShapeSpec.Sharpness.normal),
                color = star.mood.color,
                size = 38.dp,
                halo = true,
            )
        } else {
            Box(
                modifier = Modifier
                    .size(9.dp)
                    .dropShadow(CircleShape, Shadow(radius = 5.dp, color = star.mood.color.copy(alpha = 0.6f)))
                    .border(0.dp, Color.Transparent, CircleShape)
                    .CanvasFill(star.mood.color.copy(alpha = 0.7f)),
            )
        }

        // Date text underneath
        val dateText = formatShortDate(star.createdAt)
        if (dateText.isNotEmpty()) {
            Text(
                text = dateText,
                fontFamily = Pretendard,
                fontSize = 12.sp,
                color = YColor.textTertiary,
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .offset(y = 22.dp),
            )
        }
    }
}

@Composable
private fun PlainDot(
    star: MonthConstellation.Star,
    k: Float,
    faint: Boolean,
    isSelected: Boolean,
    onTap: ((MonthConstellation.Star) -> Unit)?,
) {
    val baseSize = if (star.hasStarlight) {
        (9f + 6f * min(1f, (star.starlight ?: 500).toFloat() / 999f)) * k
    } else {
        7f * k
    }
    val color = star.mood.color
    val dotAlpha = if (faint) 0.45f else if (star.hasStarlight) 1f else 0.6f

    Box(
        modifier = Modifier
            .size(32.dp)
            .then(
                if (onTap != null) {
                    Modifier
                        .noRippleClick { onTap(star) }
                        .semantics {
                            role = Role.Button
                            contentDescription = "${star.title}, ${if (star.hasStarlight) "별빛 ${star.starlight ?: 0}" else "별빛 없는 별"}"
                        }
                } else Modifier
            ),
        contentAlignment = Alignment.Center,
    ) {
        if (isSelected) {
            Canvas(modifier = Modifier.size((baseSize * 2.6f).dp)) {
                val dash = PathEffect.dashPathEffect(floatArrayOf(3.dp.toPx(), 3.dp.toPx()))
                drawCircle(
                    color = YColor.starBright,
                    radius = size.minDimension / 2f - 0.6.dp.toPx(),
                    style = Stroke(width = 1.2.dp.toPx(), pathEffect = dash),
                )
            }
        }

        Canvas(
            modifier = Modifier
                .size(baseSize.dp)
                .then(
                    if (star.hasStarlight && !faint) {
                        Modifier.dropShadow(CircleShape, Shadow(radius = (6 * k).dp, color = color.copy(alpha = 0.8f)))
                    } else Modifier
                ),
        ) {
            drawCircle(color = color.copy(alpha = dotAlpha))
        }
    }
}

private fun Modifier.CanvasFill(color: Color): Modifier = this.then(
    Modifier.drawBehind { drawCircle(color = color) }
)

private fun findPointOf(
    id: String,
    constellation: MonthConstellation,
    pts: List<Offset>,
    widthPx: Float,
    heightPx: Float,
): Offset? {
    val slotIdx = constellation.slots.indexOfFirst { it.star?.id == id }
    if (slotIdx >= 0 && slotIdx < pts.size) return pts[slotIdx]
    val extraIdx = constellation.extra.indexOfFirst { it.id == id }
    if (extraIdx >= 0) {
        return extraPoint(extraIdx, widthPx, heightPx, constellation.month)
    }
    return null
}

fun extraPoint(i: Int, widthPx: Float, heightPx: Float, month: String): Offset {
    val rng = SeededRandom("extra-$month-$i")
    val a = rng.next(0.0, 2.0 * Math.PI)
    val r = rng.next(0.42, 0.48)
    val midX = widthPx / 2f
    val midY = heightPx / 2f
    return Offset(
        (midX + cos(a) * widthPx * r).toFloat(),
        (midY + sin(a) * heightPx * r).toFloat(),
    )
}

private fun formatShortDate(iso: String?): String {
    if (iso.isNullOrBlank()) return ""
    return try {
        val zdt = Instant.parse(iso).atZone(ZoneId.of("Asia/Seoul"))
        "${zdt.monthValue}/${zdt.dayOfMonth}"
    } catch (_: Exception) {
        try {
            val odt = OffsetDateTime.parse(iso).atZoneSameInstant(ZoneId.of("Asia/Seoul"))
            "${odt.monthValue}/${odt.dayOfMonth}"
        } catch (_: Exception) {
            ""
        }
    }
}
