package com.dycdyp.youniya.ui.design

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.State
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import com.dycdyp.youniya.ui.theme.LocalMotionReduced
import kotlin.math.pow

/** A looping keyframe track transcribed from Figma motion data; every segment eases in-out (iOS Twinkle). */
class Twinkle(val duration: Double, val keys: List<Pair<Double, Double>>) {
    fun value(time: Double): Double {
        val p = (time % duration) / duration
        val last = keys.last()
        if (p >= last.first) return last.second
        for (i in 0 until keys.size - 1) {
            if (p < keys[i + 1].first) {
                val (t0, v0) = keys[i]
                val (t1, v1) = keys[i + 1]
                val x = (p - t0) / (t1 - t0)
                val eased = if (x < 0.5) 2 * x * x else 1 - (-2 * x + 2).pow(2) / 2
                return v0 + (v1 - v0) * eased
            }
        }
        return last.second
    }
}

/** Seconds since this composable started; frozen at 0 when motion is reduced. */
@Composable
fun rememberClock(): State<Double> {
    val reduced = LocalMotionReduced.current
    val t = remember { mutableDoubleStateOf(0.0) }
    LaunchedEffect(reduced) {
        if (reduced) return@LaunchedEffect
        var start = -1L
        while (true) {
            withFrameNanos { now ->
                if (start < 0) start = now
                t.doubleValue = (now - start) / 1e9
            }
        }
    }
    return t
}

/** Figma stars shrink to 0.7 while fading to 0.3 opacity. */
val dimScale: (Double) -> Double = { o -> 0.7 + (o - 0.3) * (0.3 / 0.7) }

@Composable
fun Modifier.twinkle(track: Twinkle, scale: ((Double) -> Double)? = null): Modifier {
    val reduced = LocalMotionReduced.current
    if (reduced) return this.graphicsLayer { alpha = track.keys.first().second.toFloat() }
    val clock = rememberClock()
    return this.graphicsLayer {
        val o = track.value(clock.value)
        alpha = o.toFloat()
        val s = (scale?.invoke(o) ?: 1.0).toFloat()
        scaleX = s
        scaleY = s
    }
}
