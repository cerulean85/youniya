package com.dycdyp.youniya.ui.design

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Fill
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.dycdyp.youniya.data.StarShapeSpec
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin

/** Linear mix toward [other] (iOS Color.blend). */
fun Color.blend(other: Color, by: Float): Color {
    val t = by.coerceIn(0f, 1f)
    return Color(
        red = this.red + (other.red - this.red) * t,
        green = this.green + (other.green - this.green) * t,
        blue = this.blue + (other.blue - this.blue) * t,
        alpha = this.alpha + (other.alpha - this.alpha) * t,
    )
}

/** Curved star path with [points] tips curving inward (iOS CurvedStar). */
fun curvedStarPath(points: Int, inner: Float, center: Offset, radius: Float): Path {
    val path = Path()
    val tips = Array(points) { i ->
        val a = -PI / 2.0 + i.toDouble() * 2.0 * PI / points.toDouble()
        Offset((cos(a) * radius).toFloat(), (sin(a) * radius).toFloat())
    }
    val far = 0.085f
    path.moveTo(center.x + tips[0].x, center.y + tips[0].y)
    for (i in 0 until points) {
        val t0 = tips[i]
        val t1 = tips[(i + 1) % points]
        path.cubicTo(
            center.x + t0.x * inner + t1.x * far,
            center.y + t0.y * inner + t1.y * far,
            center.x + t1.x * inner + t0.x * far,
            center.y + t1.y * inner + t0.y * far,
            center.x + t1.x,
            center.y + t1.y,
        )
    }
    path.close()
    return path
}

/**
 * Figma `Star Shape`: halo, optional cross rays, gradient body, facet, glowing core.
 */
@Composable
fun ShapeStar(
    spec: StarShapeSpec,
    color: Color,
    size: Dp,
    modifier: Modifier = Modifier,
    halo: Boolean = true,
    rays: Boolean = false,
) {
    val light = color.blend(Color.White, 0.8f)
    val dark = color.blend(Color.Black, 0.28f)

    Box(
        modifier = modifier.size(size).semantics { },
        contentAlignment = Alignment.Center,
    ) {
        Canvas(modifier = Modifier.size(size)) {
            val center = Offset(this.size.width / 2f, this.size.height / 2f)
            val sizePx = this.size.width

            // 1. Halo
            if (halo) {
                val haloRadius = sizePx * 1.15f
                drawCircle(
                    brush = Brush.radialGradient(
                        0.0f to color.copy(alpha = 0.38f),
                        0.45f to color.copy(alpha = 0.12f),
                        1.0f to color.copy(alpha = 0f),
                        center = center,
                        radius = haloRadius,
                    ),
                    radius = haloRadius,
                    center = center,
                )
            }

            // 2. Rays
            if (rays) {
                val rayWidth = sizePx * 1.5f
                val rayHeight = maxOf(0.9f * density, sizePx / 60f)
                val rayBrush = Brush.horizontalGradient(
                    listOf(light.copy(alpha = 0f), light.copy(alpha = 0.8f), light.copy(alpha = 0f)),
                    startX = center.x - rayWidth / 2f,
                    endX = center.x + rayWidth / 2f,
                )
                for (angle in listOf(0f, 90f)) {
                    rotate(angle, pivot = center) {
                        drawRoundRect(
                            brush = rayBrush,
                            topLeft = Offset(center.x - rayWidth / 2f, center.y - rayHeight / 2f),
                            size = Size(rayWidth, rayHeight),
                            cornerRadius = CornerRadius(rayHeight / 2f, rayHeight / 2f),
                        )
                    }
                }
            }

            // 3. Body: CurvedStar
            val bodyRadius = sizePx / 2f
            val bodyPath = curvedStarPath(spec.points, spec.sharpness.inner, center, bodyRadius)
            drawPath(
                path = bodyPath,
                brush = Brush.radialGradient(
                    0.0f to light,
                    0.5f to color,
                    1.0f to dark,
                    center = center,
                    radius = bodyRadius,
                ),
            )
            val strokeWidth = maxOf(0.5f * density, sizePx * 0.017f)
            drawPath(
                path = bodyPath,
                color = color.blend(Color.White, 0.75f).copy(alpha = 0.7f),
                style = Stroke(width = strokeWidth),
            )

            // 4. Facet (안쪽 면)
            val facetRadius = sizePx * 0.38f / 2f
            val facetPath = curvedStarPath(spec.points, spec.sharpness.inner, center, facetRadius)
            val facetRotation = 180f / spec.points.toFloat()
            rotate(facetRotation, pivot = center) {
                drawPath(
                    path = facetPath,
                    color = Color.White.copy(alpha = 0.2f),
                    style = Fill,
                )
            }

            // 5. Glowing core (빛나는 심)
            val coreRadius = sizePx * 0.16f / 2f
            val glowRadius = sizePx * 0.11f
            drawCircle(
                brush = Brush.radialGradient(
                    0.0f to color.blend(Color.White, 0.5f).copy(alpha = 0.9f),
                    1.0f to Color.Transparent,
                    center = center,
                    radius = coreRadius + glowRadius,
                ),
                radius = coreRadius + glowRadius,
                center = center,
            )
            drawCircle(
                color = Color.White,
                radius = coreRadius,
                center = center,
            )
        }
    }
}
