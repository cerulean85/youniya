package com.dycdyp.youniya.ui.components

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.gestures.Orientation
import androidx.compose.foundation.gestures.draggable
import androidx.compose.foundation.gestures.rememberDraggableState
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch

/** Width of the strip at a screen edge that starts an edge swipe (iOS EdgeSwipe.swift). */
val EdgeSwipeWidth = 20.dp

/**
 * iOS EdgeSwipeBack: drag right from the left edge to go back. The page follows the finger over
 * [below], then slides off past a quarter of the width (or a fast flick), else springs back.
 */
@Composable
fun EdgeSwipeBack(
    enabled: Boolean,
    below: @Composable () -> Unit,
    onBack: () -> Unit,
    content: @Composable () -> Unit,
) {
    val offset = remember { Animatable(0f) }
    var committed by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    BoxWithConstraints(Modifier.fillMaxSize()) {
        val width = with(LocalDensity.current) { maxWidth.toPx() }
        if (offset.value > 0f && !committed) below()
        Box(
            Modifier.fillMaxSize().graphicsLayer {
                translationX = offset.value
                if (offset.value > 0f) shadowElevation = 24.dp.toPx()
            },
        ) { content() }
        if (enabled) {
            Box(
                Modifier.align(Alignment.CenterStart).width(EdgeSwipeWidth).fillMaxHeight().draggable(
                    orientation = Orientation.Horizontal,
                    state = rememberDraggableState { d -> scope.launch { offset.snapTo((offset.value + d).coerceIn(0f, width)) } },
                    onDragStopped = { velocity ->
                        if (offset.value > width * 0.25f || velocity > 1200f) {
                            offset.animateTo(width, tween(200))
                            committed = true  // the page beneath takes over from here
                            onBack()
                        } else {
                            offset.animateTo(0f, spring(dampingRatio = 0.9f))
                        }
                    },
                ),
            )
        }
    }
}
