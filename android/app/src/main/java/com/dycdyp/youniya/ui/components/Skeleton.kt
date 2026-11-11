package com.dycdyp.youniya.ui.components

import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.dycdyp.youniya.ui.theme.LocalMotionReduced
import com.dycdyp.youniya.ui.theme.Radius
import com.dycdyp.youniya.ui.theme.Space
import com.dycdyp.youniya.ui.theme.YColor

/**
 * Figma `Skeleton` (iOS SkeletonBlock):
 * flat #1A2338 (bgSurfaceRaised) block that stands in for content while loading.
 */
@Composable
fun SkeletonBlock(
    height: Dp,
    modifier: Modifier = Modifier,
    width: Dp? = null,
    radius: Dp = Radius.md,
) {
    val shape = RoundedCornerShape(radius)
    Box(
        modifier = modifier
            .then(if (width != null) Modifier.width(width) else Modifier.fillMaxWidth())
            .height(height)
            .clip(shape)
            .background(YColor.bgSurfaceRaised, shape),
    )
}

/**
 * Lays out skeleton blocks with screen padding and a slow pulse (iOS SkeletonStack).
 */
@Composable
fun SkeletonStack(
    modifier: Modifier = Modifier,
    spacing: Dp = Space.lg,
    content: @Composable ColumnScope.() -> Unit,
) {
    val reduced = LocalMotionReduced.current
    val transition = rememberInfiniteTransition(label = "skeleton_pulse")
    val alpha by if (reduced) {
        androidx.compose.runtime.remember { androidx.compose.runtime.mutableFloatStateOf(1f) }
    } else {
        transition.animateFloat(
            initialValue = 1f,
            targetValue = 0.55f,
            animationSpec = infiniteRepeatable(
                animation = tween(durationMillis = 900, easing = FastOutSlowInEasing),
                repeatMode = RepeatMode.Reverse,
            ),
            label = "skeleton_alpha",
        )
    }

    Column(
        modifier = modifier
            .fillMaxWidth()
            .alpha(alpha)
            .semantics(mergeDescendants = true) {
                contentDescription = "불러오는 중이에요"
            },
        verticalArrangement = Arrangement.spacedBy(spacing),
        content = content,
    )
}

/** 47 스켈레톤 · 홈 (iOS HomeSkeleton) */
@Composable
fun HomeSkeleton(modifier: Modifier = Modifier) {
    SkeletonStack(
        modifier = modifier
            .padding(horizontal = Space.xl)
            .padding(top = Space.lg),
    ) {
        SkeletonBlock(width = 160.dp, height = 28.dp)
        SkeletonBlock(height = 20.dp)
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(Radius.xl))
                .background(YColor.bgSurface, RoundedCornerShape(Radius.xl))
                .padding(Space.lg),
            verticalArrangement = Arrangement.spacedBy(Space.md),
        ) {
            SkeletonBlock(width = 120.dp, height = 16.dp)
            SkeletonBlock(height = 56.dp)
            SkeletonBlock(height = 12.dp)
            SkeletonBlock(height = 12.dp)
        }
        SkeletonBlock(height = 52.dp, radius = Radius.lg)
        SkeletonBlock(height = 52.dp, radius = Radius.lg)
    }
}

/** 48 스켈레톤 · 별 상세 (iOS StarDetailSkeleton) */
@Composable
fun StarDetailSkeleton(modifier: Modifier = Modifier) {
    SkeletonStack(
        modifier = modifier
            .padding(horizontal = Space.xl)
            .padding(top = Space.sm),
    ) {
        SkeletonBlock(width = 120.dp, height = 14.dp)
        SkeletonBlock(width = 240.dp, height = 28.dp)
        SkeletonBlock(height = 14.dp)
        SkeletonBlock(height = 14.dp)
        SkeletonBlock(height = 14.dp)
        SkeletonBlock(width = 200.dp, height = 14.dp)
        SkeletonBlock(height = 200.dp, radius = Radius.xl)
        SkeletonBlock(height = 52.dp, radius = Radius.lg)
    }
}

/** 49 스켈레톤 · 별빛 기록 / 50 스켈레톤 · 우주 광장 (iOS ListSkeleton) */
@Composable
fun ListSkeleton(
    titleWidth: Dp,
    rowHeight: Dp,
    rows: Int,
    modifier: Modifier = Modifier,
) {
    SkeletonStack(
        modifier = modifier
            .padding(horizontal = Space.xl)
            .padding(top = Space.lg),
    ) {
        SkeletonBlock(width = titleWidth, height = 28.dp)
        repeat(rows) {
            SkeletonBlock(height = rowHeight, radius = Radius.lg)
        }
    }
}
