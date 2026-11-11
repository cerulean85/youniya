package com.dycdyp.youniya.ui.screens

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.dycdyp.youniya.data.StarShapeSpec
import com.dycdyp.youniya.ui.components.PrimaryButton
import com.dycdyp.youniya.ui.design.ShapeStar
import com.dycdyp.youniya.ui.design.StarField
import com.dycdyp.youniya.ui.theme.LocalMotionReduced
import com.dycdyp.youniya.ui.theme.Space
import com.dycdyp.youniya.ui.theme.YColor
import com.dycdyp.youniya.ui.theme.YText
import com.dycdyp.youniya.ui.theme.sky
import kotlinx.coroutines.delay

/**
 * 61–64 별 탄생 (iOS StarBirthView):
 * a point of light gathers (0s), spreads (0.3s), takes shape (0.8s), and settles clear (1.1–1.7s).
 * Unlit star: a small light in its mood color.
 */
@Composable
fun StarBirthView(
    shape: StarShapeSpec? = null,
    color: Color = YColor.starBright,
    unlit: Boolean = false,
    onShow: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val reduced = LocalMotionReduced.current
    var phase by remember { mutableIntStateOf(if (reduced) 3 else 0) }
    val titles = listOf("마음을 모으는 중", "빛이 번져요", "별이 모양을 이뤄요", "별이 떴어요")
    val done = phase == 3

    LaunchedEffect(reduced) {
        if (reduced) {
            phase = 3
            return@LaunchedEffect
        }
        if (phase == 0) {
            delay(300)
            phase = 1
            delay(500)
            phase = 2
            delay(300)
            phase = 3
        }
    }

    Box(modifier.fillMaxSize()) {
        StarField()

        Column(
            modifier = Modifier
                .fillMaxSize()
                .safeDrawingPadding()
                .padding(horizontal = Space.xl)
                .padding(bottom = Space.xl),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            // iOS: Spacer(minLength: 0).frame(maxHeight: done ? 24 : 199), inside the safe area.
            Spacer(Modifier.height(if (done) 24.dp else 199.dp))

            Text(
                titles[phase],
                style = YText.h2,
                color = YColor.textPrimary,
                textAlign = TextAlign.Center,
                modifier = Modifier.semantics { heading() },
            )

            Spacer(Modifier.size(Space.lg))

            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(320.dp),
                contentAlignment = Alignment.Center,
            ) {
                if (unlit || shape == null) {
                    PlainLight(phase = phase, color = color, unlit = unlit)
                } else {
                    ShapedStarLight(phase = phase, spec = shape, color = color)
                }

                if (done) {
                    // Small satellite dot 1 (cyan)
                    Box(
                        Modifier
                            .offset(x = (-84).dp, y = (-82).dp)
                            .size(6.dp)
                            .dropShadow(CircleShape, Shadow(radius = 10.dp, color = YColor.starClear.copy(alpha = 0.4f)))
                            .background(YColor.starClear, CircleShape),
                    )
                    // Small satellite dot 2 (warm pink)
                    Box(
                        Modifier
                            .offset(x = 87.dp, y = 68.dp)
                            .size(5.dp)
                            .dropShadow(CircleShape, Shadow(radius = 12.dp, color = YColor.brandWarm.copy(alpha = 0.35f)))
                            .background(YColor.brandWarm, CircleShape),
                    )
                }
            }

            Spacer(Modifier.weight(1f))

            PrimaryButton(
                text = "별 보기",
                enabled = done,
                modifier = Modifier.alpha(if (done) 1f else 0f),
                onClick = onShow,
            )
        }
    }
}

@Composable
private fun ShapedStarLight(
    phase: Int,
    spec: StarShapeSpec,
    color: Color,
) {
    val a = sky()
    val ambientSizes = listOf(6.dp, 90.dp, 140.dp, 140.dp)
    val ambientColor = if (phase == 2) a.brandPrimary else YColor.starBright
    val ambientAlpha = if (phase == 3) 0f else if (phase == 2) 0.32f else 0.4f

    Box(contentAlignment = Alignment.Center) {
        if (ambientAlpha > 0f) {
            Box(
                Modifier
                    .size(ambientSizes[phase])
                    .dropShadow(CircleShape, Shadow(radius = 14.dp, color = ambientColor.copy(alpha = 0.5f)))
                    .background(ambientColor.copy(alpha = ambientAlpha), CircleShape),
            )
        }

        if (phase == 1) {
            Box(
                Modifier
                    .size(16.dp)
                    .dropShadow(CircleShape, Shadow(radius = 10.dp, color = YColor.starBright.copy(alpha = 0.6f)))
                    .background(YColor.starBright, CircleShape),
            )
        }

        if (phase >= 2) {
            val starSize = if (phase == 3) 120.dp else 64.dp
            val starAlpha = if (phase == 3) 1f else 0.55f
            ShapeStar(
                spec = spec,
                color = color,
                size = starSize,
                halo = phase == 3,
                modifier = Modifier.alpha(starAlpha),
            )
        }
    }
}

@Composable
private fun PlainLight(
    phase: Int,
    color: Color,
    unlit: Boolean,
) {
    val a = sky()
    val ambientSizes = listOf(0.dp, 90.dp, 140.dp, 150.dp)
    val coreSizes = if (unlit) listOf(6.dp, 12.dp, 20.dp, 22.dp) else listOf(6.dp, 16.dp, 40.dp, 48.dp)
    val coreColor = if (unlit) color else YColor.starBright
    val coreAlpha = if (phase == 0) 0.9f else if (unlit) 0.7f else 1f

    Box(contentAlignment = Alignment.Center) {
        if (ambientSizes[phase] > 0.dp && phase < 3) {
            val ambientColor = if (phase == 2) a.brandPrimary else YColor.starBright
            Box(
                Modifier
                    .size(ambientSizes[phase])
                    .dropShadow(CircleShape, Shadow(radius = 14.dp, color = ambientColor.copy(alpha = 0.45f)))
                    .background(ambientColor.copy(alpha = 0.16f), CircleShape),
            )
        }

        Box(
            Modifier
                .size(coreSizes[phase])
                .dropShadow(CircleShape, Shadow(radius = 14.dp, color = coreColor.copy(alpha = if (unlit) 0.25f else 0.5f)))
                .background(coreColor.copy(alpha = coreAlpha), CircleShape),
        )
    }
}
