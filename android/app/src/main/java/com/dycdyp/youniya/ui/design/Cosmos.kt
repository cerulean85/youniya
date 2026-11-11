package com.dycdyp.youniya.ui.design

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.addOutline
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.withTransform
import com.dycdyp.youniya.ui.theme.LocalSky
import com.dycdyp.youniya.ui.theme.SkyAccent
import com.dycdyp.youniya.ui.theme.YColor
import kotlin.math.max
import kotlin.math.min

/** SplitMix64 seeded from the FNV-1a hash of a string: the same sky as iOS for the same seed. */
class SeededRandom(seed: String) {
    private var state: ULong

    init {
        var h = 0xcbf29ce484222325uL
        for (b in seed.encodeToByteArray()) h = (h xor b.toUByte().toULong()) * 0x100000001b3uL
        state = h
    }

    fun next(): ULong {
        state += 0x9E3779B97F4A7C15uL
        var z = state
        z = (z xor (z shr 30)) * 0xBF58476D1CE4E5B9uL
        z = (z xor (z shr 27)) * 0x94D049BB133111EBuL
        return z xor (z shr 31)
    }

    fun next(lo: Double, hi: Double): Double {
        val unit = (next() shr 11).toDouble() / (1L shl 53).toDouble()
        return lo + unit * (hi - lo)
    }
}

/** Figma `Cosmos BG`: three soft glows and star dust, laid out from a seed (iOS CosmosBackground). */
fun DrawScope.drawCosmos(seed: String, sky: SkyAccent, intensity: Double = 1.0) {
    val k = intensity * 0.6
    val rng = SeededRandom(seed)
    val d = density
    val w = size.width / d
    val h = size.height / d
    val ry = h * 0.9
    val rx = min(w * 0.9, max(w * 0.32, ry * 1.6))
    val (main, second, third) = sky.glows
    val glows = listOf(
        Glow(main, 0.28 * 0.55, 0.2..0.4, 0.25..0.75),
        Glow(second, 0.14 * 0.4, 0.65..0.9, 0.6..1.0),
        Glow(third, 0.10 * 0.3, 0.5..0.9, 0.0..0.3),
    )
    for (g in glows) {
        val cx = rng.next(g.x.start, g.x.endInclusive) * w
        val cy = rng.next(g.y.start, g.y.endInclusive) * h
        val r = (ry * d).toFloat()
        withTransform({
            translate((cx * d).toFloat(), (cy * d).toFloat())
            scale((rx / ry).toFloat(), 1f, pivot = Offset.Zero)
        }) {
            drawCircle(
                brush = Brush.radialGradient(
                    listOf(g.color.copy(alpha = (g.alpha * k).toFloat()), g.color.copy(alpha = 0f)),
                    center = Offset.Zero, radius = r,
                ),
                radius = r, center = Offset.Zero,
            )
        }
    }
    val count = ((w * h) / 900).toInt()
    repeat(count) {
        val r = rng.next(0.5, 0.75)
        val px = rng.next(0.0, 1.0) * w
        val py = rng.next(0.0, 1.0) * h
        val a = rng.next(0.2, 0.5) * k
        drawCircle(YColor.textPrimary.copy(alpha = a.toFloat()), radius = (r * d).toFloat(), center = Offset((px * d).toFloat(), (py * d).toFloat()))
    }
}

private class Glow(val color: androidx.compose.ui.graphics.Color, val alpha: Double, val x: ClosedFloatingPointRange<Double>, val y: ClosedFloatingPointRange<Double>)

/** Adds the Cosmos BG behind this content, clipped to [shape]. */
@Composable
fun Modifier.cosmos(seed: String, shape: Shape = RectangleShape, intensity: Double = 1.0): Modifier {
    val sky = LocalSky.current
    return this.drawBehind {
        val path = Path().apply { addOutline(shape.createOutline(size, layoutDirection, this@drawBehind)) }
        clipPath(path) { drawCosmos(seed, sky, intensity) }
    }
}
