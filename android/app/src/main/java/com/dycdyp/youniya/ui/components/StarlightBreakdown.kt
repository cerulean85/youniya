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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import com.dycdyp.youniya.data.ServerAnalysis
import com.dycdyp.youniya.ui.design.cosmos
import com.dycdyp.youniya.ui.theme.Radius
import com.dycdyp.youniya.ui.theme.Space
import com.dycdyp.youniya.ui.theme.YColor
import com.dycdyp.youniya.ui.theme.YText
import com.dycdyp.youniya.ui.theme.sky

/**
 * 17.3 별빛 풀이 (07-1, 12-5, iOS StarlightBreakdown):
 * "별빛 N은 이렇게 모였어요" — three scores with reasons, overall reading, and method.
 */
@Composable
fun StarlightBreakdown(
    analysis: ServerAnalysis,
    modifier: Modifier = Modifier,
) {
    val a = sky()
    val shape = RoundedCornerShape(Radius.xl)

    Column(
        modifier = modifier
            .fillMaxWidth()
            .cosmos("breakdown-${analysis.starlight}", shape)
            .background(YColor.bgSurface, shape)
            .border(1.dp, YColor.borderDefault, shape)
            .padding(Space.xl),
        verticalArrangement = Arrangement.spacedBy(Space.lg),
    ) {
        Text(
            "별빛 ${analysis.starlight}${starlightParticle(analysis.starlight)} 이렇게 모였어요",
            style = YText.h3,
            color = YColor.textPrimary,
            modifier = Modifier.semantics { heading() },
        )

        BreakdownRow(
            label = "별의 깊이",
            score = analysis.depthScore,
            max = 400,
            reason = analysis.depthReason,
            color = a.brandPrimary,
        )

        BreakdownRow(
            label = "빛의 선명함",
            score = analysis.clarityScore,
            max = 300,
            reason = analysis.clarityReason,
            color = YColor.starClear,
        )

        BreakdownRow(
            label = "마음의 무게",
            score = analysis.weightScore,
            max = 300,
            reason = analysis.weightReason,
            color = YColor.brandWarm,
        )

        if (analysis.interpretation != null) {
            Box(Modifier.fillMaxWidth().height(1.dp).background(YColor.borderDefault))
            Column(verticalArrangement = Arrangement.spacedBy(Space.sm)) {
                Text("종합 해석", style = YText.labelM, color = YColor.textPrimary)
                Text(
                    analysis.interpretation,
                    style = YText.observation,
                    color = YColor.textSecondary,
                )
            }
        } else if (analysis.prismVersion != null) {
            Text(
                "이번에는 별빛 풀이를 다 쓰지 못했어요. 별빛과 세 점수는 그대로예요.",
                style = YText.caption,
                color = YColor.textTertiary,
            )
        }

        Column(verticalArrangement = Arrangement.spacedBy(Space.sm)) {
            Text(
                "점수는 글을 평가한 것이 아니라, 이 글에서 마음이 어디까지 닿았는지를 별빛으로 옮긴 거예요.",
                style = YText.caption,
                color = YColor.textTertiary,
            )
            if (analysis.prismVersion != null) {
                Text(
                    "${analysis.prismVersion} · 2026년 11월 방식으로 읽었어요",
                    style = YText.caption,
                    color = YColor.textTertiary,
                )
            }
        }
    }
}

@Composable
private fun BreakdownRow(
    label: String,
    score: Int,
    max: Int,
    reason: String?,
    color: Color,
) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(Space.sm),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(label, style = YText.labelM, color = YColor.textPrimary)
            Text("$score / $max", style = YText.labelS, color = YColor.textSecondary)
        }

        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(6.dp)
                .background(YColor.borderDefault, CircleShape),
        ) {
            val fraction = (score.toFloat() / max.toFloat()).coerceIn(0f, 1f)
            if (fraction > 0f) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth(fraction)
                        .height(6.dp)
                        .background(color, CircleShape),
                )
            }
        }

        if (!reason.isNullOrBlank()) {
            Text(reason, style = YText.bodyS, color = YColor.textSecondary)
        }
    }
}

/** 「별빛 풀이 보기 ▾ / 접기 ▴」 (iOS BreakdownToggle) */
@Composable
fun BreakdownToggle(
    isOpen: Boolean,
    onToggle: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(44.dp)
            .noRippleClick(onToggle),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            if (isOpen) "별빛 풀이 접기 ▴" else "별빛 풀이 보기 ▾",
            style = YText.labelM,
            color = YColor.starBright,
        )
    }
}

/** Korean topic particle ("742는" / "740은") */
fun starlightParticle(n: Int): String {
    val last = n % 10
    if (last != 0) return if (last in setOf(1, 3, 6, 7, 8)) "은" else "는"
    if (n % 100 != 0) return "은"
    if (n % 1000 != 0) return "은"
    return "는"
}
