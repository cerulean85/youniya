package com.dycdyp.youniya.ui.screens

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.dycdyp.youniya.R
import com.dycdyp.youniya.data.StarShapeSpec
import com.dycdyp.youniya.ui.components.GhostButton
import com.dycdyp.youniya.ui.design.ShapeStar
import com.dycdyp.youniya.ui.design.StarField
import com.dycdyp.youniya.ui.theme.LocalMotionReduced
import com.dycdyp.youniya.ui.theme.Space
import com.dycdyp.youniya.ui.theme.YColor
import com.dycdyp.youniya.ui.theme.YText
import com.dycdyp.youniya.ui.theme.sky
import kotlinx.coroutines.delay
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin

/**
 * 06 별빛 프리즘 분석 (iOS PrismAnalysisView):
 * orbit loader (three dashed rings turning, violet 4-point star) and three stage chips.
 * 06-1: after 8s, slow copy and 「그만두기」 appear.
 */
@Composable
fun PrismAnalysisView(
    onFinish: (() -> Unit)? = null,
    onStop: (() -> Unit)? = null,
    stopping: Boolean = false,
    isReading: Boolean = true,
    modifier: Modifier = Modifier,
) {
    val reduced = LocalMotionReduced.current
    var elapsedMs by remember { mutableLongStateOf(0L) }
    var slow by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        val start = System.currentTimeMillis()
        while (true) {
            val now = System.currentTimeMillis()
            elapsedMs = now - start
            if (elapsedMs >= 8000L && !slow) {
                slow = true
            }
            if (!isReading && elapsedMs >= 4200L) {
                onFinish?.invoke()
                break
            }
            delay(100)
        }
    }

    val transition = rememberInfiniteTransition(label = "orbit")
    val angle by if (reduced) {
        remember { mutableStateOf(0f) }
    } else {
        transition.animateFloat(
            initialValue = 0f,
            targetValue = 360f,
            animationSpec = infiniteRepeatable(
                animation = tween(durationMillis = 15000, easing = LinearEasing),
            ),
            label = "orbitAngle",
        )
    }

    Box(modifier.fillMaxSize()) {
        StarField()
        Box(Modifier.fillMaxSize().background(YColor.bgCanvas.copy(alpha = 0.78f)))

        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = Space.xl),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            OrbitLoader(angle = angle)

            Spacer(Modifier.height(Space.xl))

            Column(
                verticalArrangement = Arrangement.spacedBy(Space.md),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Text(
                    if (slow) "조금 오래 걸리고 있어요" else "별빛 프리즘이 마음의 결을 비추고 있어요",
                    style = YText.h3,
                    color = YColor.textPrimary,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.semantics { heading() },
                )
                Text(
                    if (slow) "기다리지 않아도 괜찮아요. 그만두면 별빛 없이\n띄워 두고, 오늘 무료와 코인은 쓰지 않아요."
                    else "별의 깊이 · 빛의 선명함 · 마음의 무게를\n부드럽게 살펴보는 중이에요.",
                    style = YText.bodyM,
                    color = YColor.textSecondary,
                    textAlign = TextAlign.Center,
                )
            }

            Spacer(Modifier.height(Space.xl))

            val stages = listOf("별의 깊이", "빛의 선명함", "마음의 무게")
            val step = if (isReading) {
                ((elapsedMs / 1300L) % 3).toInt()
            } else {
                minOf(2, (elapsedMs / 1300L).toInt())
            }

            Row(
                horizontalArrangement = Arrangement.spacedBy(Space.sm),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                stages.forEachIndexed { i, title ->
                    StageChip(
                        title = title,
                        done = i < step,
                        current = i == step,
                    )
                }
            }

            if (slow && onStop != null) {
                Spacer(Modifier.height(Space.xl))
                GhostButton(
                    text = "그만두기",
                    onClick = { if (!stopping) onStop() },
                )
            }
        }
    }
}

/**
 * 06 `Orbit`: three dashed rings (cyan, pink, violet), each with a small dot,
 * turning around a violet four-point star.
 */
@Composable
private fun OrbitLoader(angle: Float) {
    val a = sky()

    Box(
        modifier = Modifier.size(220.dp),
        contentAlignment = Alignment.Center,
    ) {
        Canvas(modifier = Modifier.size(220.dp)) {
            val center = Offset(size.width / 2f, size.height / 2f)
            val baseRadius = size.width / 2f

            val dashEffect = PathEffect.dashPathEffect(floatArrayOf(3.dp.toPx(), 4.dp.toPx()), 0f)

            // Ring 0: k=1.0, starClear, at -90, speed 1.0
            drawOrbitRing(
                center = center,
                radius = baseRadius * 1.0f,
                ringColor = YColor.starClear.copy(alpha = 0.85f),
                dotColor = YColor.starClear,
                dashEffect = dashEffect,
                startDeg = -90f,
                speed = 1.0f,
                angle = angle,
            )

            // Ring 1: k=0.77, brandWarm, at 0, speed -1.4
            drawOrbitRing(
                center = center,
                radius = baseRadius * 0.77f,
                ringColor = YColor.brandWarm.copy(alpha = 0.85f),
                dotColor = YColor.brandWarm,
                dashEffect = dashEffect,
                startDeg = 0f,
                speed = -1.4f,
                angle = angle,
            )

            // Ring 2: k=0.55, brandPrimary, at 150, speed 1.9
            drawOrbitRing(
                center = center,
                radius = baseRadius * 0.55f,
                ringColor = a.brandPrimary.copy(alpha = 0.85f),
                dotColor = YColor.starBright,
                dashEffect = dashEffect,
                startDeg = 150f,
                speed = 1.9f,
                angle = angle,
            )
        }

        ShapeStar(
            spec = StarShapeSpec(points = 4, sharpness = StarShapeSpec.Sharpness.sharp),
            color = a.brandPrimary,
            size = 44.dp,
            halo = false,
            modifier = Modifier.dropShadow(CircleShape, Shadow(radius = 10.dp, color = a.brandPrimary.copy(alpha = 0.6f))),
        )
    }
}

private fun androidx.compose.ui.graphics.drawscope.DrawScope.drawOrbitRing(
    center: Offset,
    radius: Float,
    ringColor: Color,
    dotColor: Color,
    dashEffect: PathEffect,
    startDeg: Float,
    speed: Float,
    angle: Float,
) {
    drawCircle(
        color = ringColor,
        radius = radius,
        center = center,
        style = Stroke(width = 1.2.dp.toPx(), pathEffect = dashEffect),
    )

    val currentDeg = startDeg + angle * speed
    val rad = currentDeg * (PI / 180.0)
    val dotCenter = Offset(
        (center.x + cos(rad) * radius).toFloat(),
        (center.y + sin(rad) * radius).toFloat(),
    )
    drawCircle(
        color = dotColor,
        radius = 4.5.dp.toPx(),
        center = dotCenter,
    )
}

@Composable
private fun StageChip(
    title: String,
    done: Boolean,
    current: Boolean,
) {
    val a = sky()

    Row(
        modifier = Modifier
            .background(if (current) a.tintPrimary else YColor.bgSurface, CircleShape)
            .border(1.dp, if (current) a.brandPrimary else YColor.borderDefault, CircleShape)
            .padding(horizontal = Space.md, vertical = Space.sm),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        if (done) {
            Image(
                painter = painterResource(R.drawable.icon_check),
                contentDescription = null,
                colorFilter = ColorFilter.tint(YColor.emotionCalm),
                modifier = Modifier.size(12.dp),
            )
        } else {
            Box(
                Modifier
                    .size(6.dp)
                    .background(if (current) a.text else YColor.textTertiary, CircleShape),
            )
        }

        Text(
            title,
            style = YText.labelS,
            color = if (current || done) YColor.textPrimary else YColor.textTertiary,
        )
    }
}
