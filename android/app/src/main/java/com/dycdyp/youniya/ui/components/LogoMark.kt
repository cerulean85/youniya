package com.dycdyp.youniya.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp
import com.dycdyp.youniya.R
import com.dycdyp.youniya.ui.design.Twinkle
import com.dycdyp.youniya.ui.design.dimScale
import com.dycdyp.youniya.ui.design.twinkle
import com.dycdyp.youniya.ui.theme.YColor

enum class LogoSize { Large, Small }

/** Figma Logo Mark: a dashed circle with a glowing violet star that breathes (iOS LogoMark). */
@Composable
fun LogoMark(size: LogoSize, modifier: Modifier = Modifier) {
    val d = if (size == LogoSize.Large) 112.dp else 56.dp
    Box(modifier.size(d), contentAlignment = Alignment.Center) {
        Canvas(Modifier.size(d)) {
            val w = 1.dp.toPx()
            drawCircle(
                YColor.borderDefault,
                radius = this.size.minDimension / 2 - w / 2,
                center = Offset(this.size.width / 2, this.size.height / 2),
                style = Stroke(width = w, pathEffect = PathEffect.dashPathEffect(floatArrayOf(2.dp.toPx(), 2.dp.toPx()))),
            )
        }
        if (size == LogoSize.Large) {
            // Splash star (8:13): 6s, scale 1↔1.08, opacity 1↔0.75
            Image(
                painterResource(R.drawable.logo_star_large), null,
                Modifier.size(95.04.dp).twinkle(
                    Twinkle(6.0, listOf(0.0 to 1.0, 0.16667 to 0.75, 0.47 to 1.0, 0.77167 to 0.75, 1.0 to 1.0)),
                ) { o -> 1 + (1 - o) * 0.32 },
            )
        } else {
            // Login star (8:34): 2s, scale 1↔0.7, opacity 1↔0.3
            Image(
                painterResource(R.drawable.logo_star_small), null,
                Modifier.size(71.52.dp).twinkle(Twinkle(2.0, listOf(0.0 to 1.0, 0.06 to 0.3, 0.55 to 1.0, 1.0 to 0.3)), dimScale),
            )
        }
    }
}
