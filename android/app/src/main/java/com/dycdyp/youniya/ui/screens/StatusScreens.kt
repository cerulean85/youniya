package com.dycdyp.youniya.ui.screens

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.dycdyp.youniya.R
import com.dycdyp.youniya.ui.components.GhostButton
import com.dycdyp.youniya.ui.components.PrimaryButton
import com.dycdyp.youniya.ui.components.SecondaryButton
import com.dycdyp.youniya.ui.design.StarField
import com.dycdyp.youniya.ui.theme.Space
import com.dycdyp.youniya.ui.theme.YColor
import com.dycdyp.youniya.ui.theme.YText
import com.dycdyp.youniya.ui.theme.sky

data class StatusAction(
    val title: String,
    val style: Style,
    val disabled: Boolean = false,
    val run: () -> Unit,
) {
    enum class Style { Primary, Secondary, Ghost }
}

/**
 * Figma status screens (35, 36, iOS StatusView):
 * an orb with an icon, a title, a short note, and actions over the star field.
 */
@Composable
fun StatusView(
    icon: Int,
    title: String,
    message: String,
    actions: List<StatusAction>,
    modifier: Modifier = Modifier,
) {
    Box(modifier.fillMaxSize()) {
        StarField()

        Column(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .navigationBarsPadding()
                .padding(horizontal = Space.xl, vertical = Space.xl),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Spacer(Modifier.weight(1f))

            StatusHero(icon = icon)

            Spacer(Modifier.size(Space.lg))

            Column(
                verticalArrangement = Arrangement.spacedBy(Space.lg),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Text(
                    title,
                    style = YText.h2,
                    color = YColor.textPrimary,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.semantics { heading() },
                )
                Text(
                    message,
                    style = YText.bodyM,
                    color = YColor.textSecondary,
                    textAlign = TextAlign.Center,
                )
            }

            Spacer(Modifier.size(Space.lg))

            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(Space.md),
            ) {
                actions.forEach { action ->
                    when (action.style) {
                        StatusAction.Style.Primary -> PrimaryButton(
                            text = action.title,
                            enabled = !action.disabled,
                            onClick = action.run,
                        )
                        StatusAction.Style.Secondary -> SecondaryButton(
                            text = action.title,
                            enabled = !action.disabled,
                            onClick = action.run,
                        )
                        StatusAction.Style.Ghost -> GhostButton(
                            text = action.title,
                            onClick = action.run,
                        )
                    }
                }
            }

            Spacer(Modifier.weight(1f))
        }
    }
}

/**
 * Figma status `Hero` (120×120, iOS StatusHero):
 * two orbits, a violet orb with a gold icon, two stars.
 */
@Composable
fun StatusHero(
    icon: Int,
    modifier: Modifier = Modifier,
) {
    val a = sky()

    Box(
        modifier = modifier.size(120.dp),
        contentAlignment = Alignment.TopStart,
    ) {
        // Outer orbit
        Box(
            Modifier
                .size(120.dp)
                .alpha(0.3f)
                .border(1.dp, a.brandPrimary, CircleShape),
        )

        // Middle orbit
        Box(
            Modifier
                .offset(x = 14.dp, y = 14.dp)
                .size(92.dp)
                .alpha(0.5f)
                .border(1.dp, a.brandPrimary, CircleShape),
        )

        // Center orb
        Box(
            Modifier
                .offset(x = 28.dp, y = 28.dp)
                .size(64.dp)
                .dropShadow(CircleShape, Shadow(radius = 12.dp, color = a.brandPrimary.copy(alpha = 0.4f)))
                .background(a.tintPrimary, CircleShape)
                .border(1.dp, a.borderFocus, CircleShape),
        )

        // Gold icon in center
        Image(
            painter = painterResource(icon),
            contentDescription = null,
            colorFilter = ColorFilter.tint(YColor.starBright),
            modifier = Modifier
                .offset(x = 45.dp, y = 45.dp)
                .size(30.dp),
        )

        // Star dot 1 (gold)
        Box(
            Modifier
                .offset(x = 97.dp, y = 17.dp)
                .size(6.dp)
                .dropShadow(CircleShape, Shadow(radius = 14.dp, color = YColor.starBright.copy(alpha = 0.5f)))
                .background(YColor.starBright, CircleShape),
        )

        // Star dot 2 (cyan)
        Box(
            Modifier
                .offset(x = 12.dp, y = 94.dp)
                .size(5.dp)
                .dropShadow(CircleShape, Shadow(radius = 10.dp, color = YColor.starClear.copy(alpha = 0.4f)))
                .background(YColor.starClear, CircleShape),
        )
    }
}

/**
 * 122 별을 찾을 수 없어요 (iOS NotFoundView):
 * deleted, or tidied away on another device.
 */
@Composable
fun NotFoundView(
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
) {
    StatusView(
        icon = R.drawable.icon_star,
        title = "별을 찾을 수 없어요",
        message = "이미 지웠거나 다른 기기에서 정리한 별이에요.",
        actions = listOf(
            StatusAction(
                title = "오늘로 돌아가기",
                style = StatusAction.Style.Primary,
                run = onBack,
            ),
        ),
        modifier = modifier,
    )
}
