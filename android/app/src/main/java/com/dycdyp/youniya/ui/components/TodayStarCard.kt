package com.dycdyp.youniya.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.unit.DpOffset
import androidx.compose.ui.unit.dp
import com.dycdyp.youniya.data.ServerAnalysis
import com.dycdyp.youniya.ui.design.cosmos
import com.dycdyp.youniya.ui.theme.Radius
import com.dycdyp.youniya.ui.theme.Space
import com.dycdyp.youniya.ui.theme.YColor
import com.dycdyp.youniya.ui.theme.YText
import com.dycdyp.youniya.ui.theme.sky

/** Figma `Axis Meter`: one of the three measuring axes as a thin gauge. */
@Composable
fun AxisMeter(
    label: String,
    value: Double,
    color: Color,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(Space.sm),
    ) {
        Text(label, style = YText.labelS, color = YColor.textSecondary)
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(6.dp)
                .background(YColor.borderDefault, CircleShape),
        ) {
            val fraction = value.toFloat().coerceIn(0f, 1f)
            if (fraction > 0f) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth(fraction)
                        .height(6.dp)
                        .background(color, CircleShape),
                )
            }
        }
    }
}

/**
 * Figma `Today Star Card` (07): starlight, three axes, a gentle observation, tones.
 */
@Composable
fun TodayStarCard(
    analysis: ServerAnalysis,
    modifier: Modifier = Modifier,
    onClick: (() -> Unit)? = null,
) {
    val a = sky()
    val shape = RoundedCornerShape(Radius.xl)

    val baseModifier = modifier
        .fillMaxWidth()
        .dropShadow(
            shape,
            Shadow(radius = 12.dp, color = Color.Black.copy(alpha = 0.4f), offset = DpOffset(0.dp, 8.dp)),
        )
        .cosmos("card-${analysis.starlight}-${analysis.observation.length}", shape)
        .background(
            Brush.linearGradient(
                listOf(YColor.bgSurfaceRaised, YColor.bgSurface),
                start = Offset.Zero,
                end = Offset.Infinite,
            ),
            shape,
        )
        .border(
            1.dp,
            Brush.linearGradient(listOf(a.borderFocus, YColor.borderDefault)),
            shape,
        )
        .then(if (onClick != null) Modifier.noRippleClick(onClick) else Modifier)
        .padding(Space.xl)

    Column(
        modifier = baseModifier,
        verticalArrangement = Arrangement.spacedBy(Space.lg),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text("오늘의 별 카드", style = YText.labelS, color = YColor.textSecondary)
            StarlightBadge(value = analysis.starlight)
        }

        Row(
            verticalAlignment = Alignment.Bottom,
            horizontalArrangement = Arrangement.spacedBy(Space.sm),
        ) {
            Text(
                "${analysis.starlight}",
                style = YText.metric,
                color = YColor.textPrimary,
            )
            Text(
                "별빛",
                style = YText.bodyS,
                color = YColor.textSecondary,
                modifier = Modifier.padding(bottom = 8.dp),
            )
        }

        Text(
            analysis.observation,
            style = YText.observation,
            color = YColor.textPrimary,
        )

        Column(verticalArrangement = Arrangement.spacedBy(Space.md)) {
            AxisMeter(label = "별의 깊이", value = analysis.depth, color = a.brandPrimary)
            AxisMeter(label = "빛의 선명함", value = analysis.clarity, color = YColor.starClear)
            AxisMeter(label = "마음의 무게", value = analysis.weight, color = YColor.brandWarm)
        }

        Row(
            horizontalArrangement = Arrangement.spacedBy(Space.sm),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            analysis.tones.forEach { mood ->
                MoodTag(mood = mood)
            }
        }
    }
}
