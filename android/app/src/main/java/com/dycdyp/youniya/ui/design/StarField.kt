package com.dycdyp.youniya.ui.design

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.res.imageResource
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import com.dycdyp.youniya.R
import com.dycdyp.youniya.ui.theme.YColor
import kotlin.math.roundToInt

/**
 * The night sky behind most screens (iOS StarField): a 390×844 Figma canvas scaled to the
 * screen width, with three nebula textures, two constellations and 53 twinkling dots.
 * Draws edge to edge, under the status and navigation bars.
 */
@Composable
fun StarField(modifier: Modifier = Modifier) {
    val violet = ImageBitmap.imageResource(R.drawable.nebula_violet)
    val pink = ImageBitmap.imageResource(R.drawable.nebula_pink)
    val cyan = ImageBitmap.imageResource(R.drawable.nebula_cyan)
    val c0 = ImageBitmap.imageResource(R.drawable.constellation0)
    val c1 = ImageBitmap.imageResource(R.drawable.constellation1)
    val clock = rememberClock()
    Canvas(modifier.fillMaxSize()) {
        drawRect(YColor.bgCanvas)
        val s = size.width / 390f
        fun place(img: ImageBitmap, x: Float, y: Float, w: Float, h: Float) = drawImg(img, x * s, y * s, w * s, h * s)
        place(violet, 150f, -140f, 420f, 420f)
        place(pink, -160f, 520f, 420f, 420f)
        place(cyan, 200f, 360f, 260f, 260f)
        place(c0, 48f, 119.56f, 182.364f, 48.9005f)
        place(c1, 259.77f, 599.45f, 90.5463f, 60.7564f)
        val t = clock.value
        for (d in dots) {
            val o = d.track.value(t).toFloat()
            val r = d.size / 2 * s
            drawCircle(YColor.textPrimary.copy(alpha = o), radius = r, center = Offset((d.x + d.size / 2) * s, (d.y + d.size / 2) * s))
        }
    }
}

private fun DrawScope.drawImg(img: ImageBitmap, x: Float, y: Float, w: Float, h: Float) {
    drawImage(img, dstOffset = IntOffset(x.roundToInt(), y.roundToInt()), dstSize = IntSize(w.roundToInt(), h.roundToInt()))
}

private class Dot(val x: Float, val y: Float, val size: Float, keys: List<Pair<Double, Double>>) {
    val track = Twinkle(6.0, keys)
}

private fun dot(x: Float, y: Float, size: Float, vararg keys: Pair<Double, Double>) = Dot(x, y, size, keys.toList())

private val dots = listOf(
    dot(191.26f, 473.31f, 3f, 0.0 to 0.372, 0.07667 to 0.08, 0.35 to 0.37),
    dot(172.85f, 427.39f, 3f, 0.0 to 0.689, 0.195 to 0.08, 0.425 to 0.489),
    dot(229.87f, 346.74f, 1.5f, 0.0 to 0.579, 0.07667 to 0.08, 0.26333 to 0.579, 0.44833 to 0.43),
    dot(29.87f, 420.78f, 1.5f, 0.0 to 0.329, 0.14 to 0.08, 0.28167 to 0.329, 0.42333 to 0.26),
    dot(218.56f, 411.24f, 2f, 0.0 to 0.72, 0.145 to 0.08, 0.41 to 0.608),
    dot(378.26f, 101.93f, 1.5f, 0.0 to 0.345, 0.02667 to 0.08, 0.24667 to 0.345, 0.46667 to 0.259),
    dot(163.5f, 464.46f, 2f, 0.0 to 0.335, 0.12167 to 0.08, 0.29667 to 0.335, 0.47333 to 0.313),
    dot(384.39f, 376.13f, 1.5f, 0.0 to 0.415, 0.03333 to 0.08, 0.165 to 0.415, 0.29667 to 0.08, 0.42833 to 0.134),
    dot(59.9f, 652.27f, 2f, 0.0 to 0.29, 0.21 to 0.08, 0.46333 to 0.18),
    dot(361.24f, 201.42f, 2f, 0.0 to 0.368, 0.08333 to 0.08, 0.29333 to 0.368, 0.50167 to 0.346),
    dot(235.16f, 339.07f, 1.5f, 0.0 to 0.318, 0.16 to 0.08, 0.325 to 0.318, 0.49167 to 0.317),
    dot(87.31f, 380.11f, 3f, 0.0 to 0.274, 0.065 to 0.08, 0.18667 to 0.274, 0.30833 to 0.08, 0.42833 to 0.097),
    dot(160.78f, 574.71f, 1.5f, 0.0 to 0.412, 0.02333 to 0.08, 0.26833 to 0.412, 0.51167 to 0.363),
    dot(170.92f, 418.44f, 1.5f, 0.0 to 0.475, 0.13333 to 0.08, 0.33333 to 0.475),
    dot(171.33f, 222.87f, 1.5f, 0.0 to 0.316, 0.03667 to 0.08, 0.19167 to 0.316, 0.34833 to 0.084),
    dot(105.44f, 647.06f, 1.5f, 0.0 to 0.713, 0.22333 to 0.08, 0.50167 to 0.285),
    dot(335.55f, 630.79f, 1.5f, 0.0 to 0.262, 0.08667 to 0.08, 0.32167 to 0.262, 0.555 to 0.261),
    dot(126.22f, 301.72f, 2f, 0.0 to 0.593, 0.17833 to 0.08, 0.36833 to 0.558),
    dot(287.52f, 225.11f, 2f, 0.0 to 0.43, 0.07333 to 0.08, 0.22 to 0.43, 0.365 to 0.114),
    dot(228.45f, 372.31f, 3f, 0.0 to 0.745, 0.02 to 0.08, 0.28833 to 0.745, 0.55667 to 0.707),
    dot(177.94f, 736.23f, 2f, 0.0 to 0.313, 0.145 to 0.08, 0.36833 to 0.301),
    dot(309.35f, 756.44f, 2f, 0.0 to 0.327, 0.03833 to 0.08, 0.21833 to 0.327, 0.39833 to 0.147),
    dot(275.76f, 588.87f, 1.5f, 0.0 to 0.365, 0.10667 to 0.08, 0.24167 to 0.365, 0.37667 to 0.141),
    dot(323.92f, 142.36f, 3f, 0.0 to 0.291, 0.09 to 0.08, 0.34833 to 0.29),
    dot(8.19f, 453.32f, 1.5f, 0.0 to 0.323, 0.19667 to 0.08, 0.41 to 0.257),
    dot(192.67f, 43.93f, 2f, 0.0 to 0.282, 0.08333 to 0.08, 0.25167 to 0.282, 0.42167 to 0.188),
    dot(138.71f, 194.38f, 1.5f, 0.0 to 0.318, 0.00667 to 0.08, 0.13167 to 0.318, 0.25833 to 0.08, 0.38333 to 0.239),
    dot(64.19f, 0.76f, 2f, 0.0 to 0.452, 0.155 to 0.08, 0.40333 to 0.39),
    dot(42.53f, 403.46f, 2f, 0.0 to 0.628, 0.04 to 0.08, 0.24333 to 0.628, 0.44667 to 0.408),
    dot(176.05f, 623.6f, 1.5f, 0.0 to 0.608, 0.12167 to 0.08, 0.28 to 0.608, 0.44 to 0.486),
    dot(249.28f, 226.14f, 2f, 0.0 to 0.691, 0.09333 to 0.08, 0.375 to 0.664),
    dot(32.32f, 57.71f, 2f, 0.0 to 0.265, 0.21333 to 0.08, 0.45167 to 0.173),
    dot(234.15f, 370.97f, 1.5f, 0.0 to 0.703, 0.09 to 0.08, 0.28333 to 0.703, 0.47667 to 0.617),
    dot(205.97f, 355.79f, 3f, 0.0 to 0.699, 0.005 to 0.08, 0.155 to 0.699, 0.30333 to 0.08, 0.45333 to 0.131),
    dot(258.18f, 421.02f, 1.5f, 0.0 to 0.479, 0.16333 to 0.08, 0.435 to 0.363),
    dot(377.16f, 747.74f, 2f, 0.0 to 0.601, 0.04 to 0.08, 0.26667 to 0.601, 0.49333 to 0.508),
    dot(307.05f, 772.07f, 1.5f, 0.0 to 0.568, 0.135 to 0.08, 0.31833 to 0.568, 0.50167 to 0.561),
    dot(323.51f, 371.58f, 3f, 0.0 to 0.736, 0.04333 to 0.08, 0.18167 to 0.736, 0.32167 to 0.08, 0.46 to 0.089),
    dot(216.42f, 550.55f, 1.5f, 0.0 to 0.641, 0.23 to 0.08, 0.49167 to 0.262),
    dot(195.87f, 374.74f, 1.5f, 0.0 to 0.276, 0.09667 to 0.08, 0.315 to 0.276, 0.53167 to 0.273),
    dot(143.92f, 394.08f, 1.5f, 0.0 to 0.327, 0.00167 to 0.08, 0.175 to 0.327, 0.34833 to 0.084),
    dot(264f, 142.28f, 1.5f, 0.0 to 0.407, 0.075 to 0.08, 0.20333 to 0.407, 0.33333 to 0.08),
    dot(8.42f, 809.82f, 2f, 0.0 to 0.444, 0.03833 to 0.08, 0.29 to 0.444, 0.54167 to 0.423),
    dot(71.72f, 554.99f, 1.5f, 0.0 to 0.403, 0.14833 to 0.08, 0.35667 to 0.395),
    dot(354f, 505.73f, 1.5f, 0.0 to 0.339, 0.04667 to 0.08, 0.21 to 0.339, 0.37333 to 0.112),
    dot(134.23f, 352.05f, 1.5f, 0.0 to 0.293, 0.10167 to 0.08, 0.22 to 0.293, 0.34 to 0.081),
    dot(46f, 148f, 4f, 0.0 to 0.5, 0.10333 to 0.15, 0.34333 to 0.499),
    dot(108f, 118f, 4f, 0.0 to 0.5, 0.195 to 0.15, 0.39333 to 0.433),
    dot(168f, 166f, 4f, 0.0 to 0.5, 0.08667 to 0.15, 0.23833 to 0.5, 0.39167 to 0.255),
    dot(228f, 128f, 4f, 0.0 to 0.5, 0.035 to 0.15, 0.31167 to 0.5, 0.58667 to 0.496),
    dot(258f, 638f, 4f, 0.0 to 0.5, 0.16167 to 0.15, 0.39333 to 0.451),
    dot(308f, 598f, 4f, 0.0 to 0.5, 0.05 to 0.15, 0.23667 to 0.5, 0.42333 to 0.314),
    dot(348f, 658f, 4f, 0.0 to 0.5, 0.12 to 0.15, 0.26167 to 0.5, 0.405 to 0.325),
)
