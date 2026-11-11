package com.dycdyp.youniya.ui.screens

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.unit.dp
import com.dycdyp.youniya.data.StarItem
import com.dycdyp.youniya.ui.components.BreakdownToggle
import com.dycdyp.youniya.ui.components.FlowTopBar
import com.dycdyp.youniya.ui.components.PrimaryButton
import com.dycdyp.youniya.ui.components.StarlightBreakdown
import com.dycdyp.youniya.ui.components.TodayStarCard
import com.dycdyp.youniya.ui.design.StarField
import com.dycdyp.youniya.ui.theme.LocalMotionReduced
import com.dycdyp.youniya.ui.theme.Space
import kotlinx.coroutines.delay

/**
 * 07-1 오늘의 별 카드 · 별빛 풀이 (iOS StarCardView):
 * the card, the 별빛 풀이 (open here), then 「나의 별자리 보기」.
 * Sequential appear animation: 0s, 0.2s, 0.4s, 0.6s (0.5s duration, 12dp slide up).
 */
@Composable
fun StarCardView(
    star: StarItem,
    onClose: () -> Unit,
    onShowNebula: () -> Unit,
    modifier: Modifier = Modifier,
    title: String = "별이 떠올랐어요",
) {
    val reduceMotion = LocalMotionReduced.current
    var showBreakdown by remember { mutableStateOf(true) }

    BackHandler { onClose() }

    Box(modifier.fillMaxSize()) {
        StarField()

        Column(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .navigationBarsPadding()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = Space.xl)
                .padding(top = Space.sm, bottom = Space.xl),
            verticalArrangement = Arrangement.spacedBy(Space.lg),
        ) {
            FlowTopBar(title = title, onClose = onClose)

            star.analysis?.let { analysis ->
                AppearBox(delayMs = 0L, reduceMotion = reduceMotion) {
                    TodayStarCard(
                        analysis = analysis,
                        onClick = { showBreakdown = !showBreakdown },
                    )
                }

                AnimatedVisibility(
                    visible = showBreakdown,
                    enter = fadeIn(tween(300)) + expandVertically(tween(300)),
                    exit = fadeOut(tween(300)) + shrinkVertically(tween(300)),
                ) {
                    AppearBox(delayMs = 200L, reduceMotion = reduceMotion) {
                        StarlightBreakdown(analysis = analysis)
                    }
                }

                AppearBox(delayMs = 400L, reduceMotion = reduceMotion) {
                    BreakdownToggle(
                        isOpen = showBreakdown,
                        onToggle = { showBreakdown = !showBreakdown },
                    )
                }
            }

            AppearBox(delayMs = 600L, reduceMotion = reduceMotion) {
                PrimaryButton(
                    text = "나의 별자리 보기",
                    onClick = onShowNebula,
                )
            }
        }
    }
}

@Composable
private fun AppearBox(
    delayMs: Long,
    reduceMotion: Boolean,
    modifier: Modifier = Modifier,
    content: @Composable () -> Unit,
) {
    if (reduceMotion) {
        Box(modifier.fillMaxWidth()) { content() }
        return
    }

    var visible by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        delay(delayMs)
        visible = true
    }

    val alpha by animateFloatAsState(
        targetValue = if (visible) 1f else 0f,
        animationSpec = tween(durationMillis = 500),
        label = "appearAlpha",
    )
    val offsetY by animateDpAsState(
        targetValue = if (visible) 0.dp else 12.dp,
        animationSpec = tween(durationMillis = 500),
        label = "appearOffset",
    )

    Box(
        modifier = modifier
            .fillMaxWidth()
            .offset(y = offsetY)
            .alpha(alpha),
    ) {
        content()
    }
}
