package com.dycdyp.youniya.ui.screens

import android.app.Activity
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.dycdyp.youniya.R
import com.dycdyp.youniya.data.AppModel
import com.dycdyp.youniya.data.MonthConstellation
import com.dycdyp.youniya.data.StarItem
import com.dycdyp.youniya.ui.components.ConstellationFigureView
import com.dycdyp.youniya.ui.components.SecondaryButton
import com.dycdyp.youniya.ui.components.noRippleClick
import com.dycdyp.youniya.ui.design.StarField
import com.dycdyp.youniya.ui.design.cosmos
import com.dycdyp.youniya.ui.theme.NotoSerifKR
import com.dycdyp.youniya.ui.theme.Pretendard
import com.dycdyp.youniya.ui.theme.Radius
import com.dycdyp.youniya.ui.theme.Space
import com.dycdyp.youniya.ui.theme.YColor
import com.dycdyp.youniya.ui.theme.YText
import com.dycdyp.youniya.ui.theme.sky
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * 08-3 나의 별자리 (별자리 tab, 436:15767):
 * this month's constellation, filled by the stars floated this month in date order.
 * ‹ › (or a swipe) shows the months before, back to the first one; not past this month.
 */
@Composable
fun ConstellationView(
    model: AppModel,
    onOpen: (String) -> Unit,
    onStory: (String) -> Unit,
    onOpenStar: (StarItem) -> Unit,
    modifier: Modifier = Modifier,
) {
    val thisMonth = remember { MonthConstellation.currentMonthKey() }
    var month by remember { mutableStateOf(thisMonth) }
    var selectedStar by remember { mutableStateOf<MonthConstellation.Star?>(null) }
    var showLinks by remember { mutableStateOf(false) }
    var showShareSheet by remember { mutableStateOf(false) }

    val coroutineScope = rememberCoroutineScope()
    val context = LocalContext.current
    val activity = context as? Activity

    val canGoBack = month > model.firstConstellationMonth
    val canGoForward = month < thisMonth

    val c = model.constellation(month)

    LaunchedEffect(month) {
        selectedStar = null
        showLinks = false
        model.loadConstellation(month)
    }

    fun pick(s: MonthConstellation.Star) {
        selectedStar = if (selectedStar?.id == s.id) null else s
        showLinks = selectedStar != null
        if (selectedStar != null) {
            coroutineScope.launch {
                delay(2500)
                if (selectedStar?.id == s.id) {
                    showLinks = false
                }
            }
        }
    }

    fun go(byMonths: Int) {
        val next = MonthConstellation.shift(month, byMonths)
        if (next >= model.firstConstellationMonth && next <= thisMonth) {
            month = next
        }
    }

    Box(modifier = modifier.fillMaxSize()) {
        StarField()

        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = Space.xl, vertical = Space.lg),
            verticalArrangement = Arrangement.spacedBy(Space.lg),
        ) {
            // Header
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .semantics(mergeDescendants = true) { heading() },
                verticalArrangement = Arrangement.spacedBy(Space.xs),
            ) {
                Text(
                    text = "나의 별자리",
                    style = YText.h1,
                    color = YColor.textPrimary,
                )
                Text(
                    text = "${c.title} · 별 ${c.stars.size}개",
                    style = YText.bodyM,
                    color = YColor.starBright,
                )
            }

            // Canvas (300dp height)
            ConstellationCanvas(
                model = model,
                constellation = c,
                selected = selectedStar,
                showLinks = showLinks,
                canGoBack = canGoBack,
                canGoForward = canGoForward,
                onGoBack = { go(-1) },
                onGoForward = { go(1) },
                onPick = { pick(it) },
                onShare = { showShareSheet = true },
                onOpenStar = onOpenStar,
            )

            // 3 Stat Cards
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(Space.md),
            ) {
                StatCard(
                    value = c.stars.size,
                    label = "떠 있는 별",
                    tappable = true,
                    onClick = { onOpen("떠 있는 별") },
                    modifier = Modifier.weight(1f),
                )
                StatCard(
                    value = c.deepCount,
                    label = "깊은 별",
                    tappable = true,
                    onClick = { onOpen("깊은 별") },
                    modifier = Modifier.weight(1f),
                )
                StatCard(
                    value = maxOf(0, c.total - c.filled),
                    label = "남은 자리",
                    tappable = false,
                    onClick = {},
                    modifier = Modifier.weight(1f),
                )
            }

            // Description
            Text(
                text = constellationDescription(c, month, thisMonth),
                style = YText.bodyS,
                color = YColor.textSecondary,
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth(),
            )

            // 별자리 이야기 버튼
            SecondaryButton(
                text = "별자리 이야기",
                onClick = { onStory(month) },
            )

            // 나의 은하수 미리 보기 카드
            MilkyWayPreviewCard(
                model = model,
                onOpen = { onOpen("나의 은하수") },
            )
        }

        // 별자리 카드로 나누기 Sheet
        if (showShareSheet) {
            YouniyaSheet(seed = "constellation-share-$month", onDismiss = { showShareSheet = false }) {
                CardShareSheetContent(
                    title = "별자리 카드로 나누기",
                    cardPreview = {
                        ConstellationShareCard(model = model, constellation = c)
                    },
                    onInstagram = { bitmap ->
                        run {
                                                        val uri = CardShareUtil.saveBitmapToCache(context, bitmap)
                            CardShareUtil.shareToInstagramStories(context, uri)
                        }
                        showShareSheet = false
                    },
                    onSaveImage = { bitmap ->
                        run {
                                                        CardShareUtil.saveToGallery(context, bitmap)
                        }
                        showShareSheet = false
                    },
                    onOtherApps = { bitmap ->
                        run {
                                                        val uri = CardShareUtil.saveBitmapToCache(context, bitmap)
                            CardShareUtil.shareToOtherApps(context, uri, "별자리 카드로 나누기")
                        }
                        showShareSheet = false
                    },
                )
            }
        }
    }
}

@Composable
private fun ConstellationCanvas(
    model: AppModel,
    constellation: MonthConstellation,
    selected: MonthConstellation.Star?,
    showLinks: Boolean,
    canGoBack: Boolean,
    canGoForward: Boolean,
    onGoBack: () -> Unit,
    onGoForward: () -> Unit,
    onPick: (MonthConstellation.Star) -> Unit,
    onShare: () -> Unit,
    onOpenStar: (StarItem) -> Unit,
    modifier: Modifier = Modifier,
) {
    val shape = RoundedCornerShape(Radius.xl)
    var dragAmount by remember { mutableFloatStateOf(0f) }

    val silverLinks = remember(selected, showLinks, model.stars) {
        if (showLinks && selected != null) {
            model.linkedStars(selected.id).map { it.id }
        } else emptyList()
    }

    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(300.dp)
            .clip(shape)
            .cosmos("nebula-canvas", shape)
            .background(YColor.bgSurface, shape)
            .border(1.dp, YColor.borderDefault, shape)
            .pointerInput(constellation.month) {
                detectHorizontalDragGestures(
                    onDragEnd = {
                        if (dragAmount > 60f) {
                            onGoBack()
                        } else if (dragAmount < -60f) {
                            onGoForward()
                        }
                        dragAmount = 0f
                    },
                    onHorizontalDrag = { _, dragDistance ->
                        dragAmount += dragDistance
                    },
                )
            },
    ) {
        // Figure in center
        ConstellationFigureView(
            constellation = constellation,
            selected = selected?.id,
            silverLinks = silverLinks,
            onTap = onPick,
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 36.dp, vertical = 32.dp),
        )

        // Arrow Buttons
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .align(Alignment.Center)
                .padding(horizontal = Space.xs),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            CanvasArrow(
                iconRes = R.drawable.icon_back,
                enabled = canGoBack,
                label = "지난달",
                onClick = onGoBack,
            )
            CanvasArrow(
                iconRes = R.drawable.icon_chevron_right,
                enabled = canGoForward,
                label = "다음 달",
                onClick = onGoForward,
            )
        }

        // Top Left Title
        Text(
            text = constellation.title,
            style = YText.labelS,
            color = YColor.textSecondary,
            modifier = Modifier
                .align(Alignment.TopStart)
                .padding(Space.lg),
        )

        // Top Right: "완성 카드 ›"
        if (constellation.isComplete) {
            Box(
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .padding(top = Space.lg - 6.dp, end = Space.lg)
                    .clip(RoundedCornerShape(14.dp))
                    .noRippleClick(onShare)
                    .background(YColor.starBright.copy(alpha = 0.14f), RoundedCornerShape(14.dp))
                    .border(1.dp, YColor.starBright.copy(alpha = 0.45f), RoundedCornerShape(14.dp))
                    .padding(horizontal = 10.dp, vertical = 6.dp),
            ) {
                Text(
                    text = "완성 카드 ›",
                    style = YText.labelS,
                    color = YColor.starBright,
                )
            }
        }

        // Bottom Right: "filled / total"
        if (selected == null) {
            Text(
                text = "${constellation.filled} / ${constellation.total}",
                style = YText.labelS,
                color = YColor.textSecondary,
                modifier = Modifier
                    .align(Alignment.BottomEnd)
                    .padding(Space.lg),
            )
        }

        // Bottom: Picked Star Card (08-8)
        AnimatedVisibility(
            visible = selected != null,
            enter = slideInVertically { it } + fadeIn(),
            exit = slideOutVertically { it } + fadeOut(),
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .fillMaxWidth()
                .padding(Space.sm),
        ) {
            if (selected != null) {
                PickedStarCard(
                    model = model,
                    star = selected,
                    onOpenStar = onOpenStar,
                )
            }
        }
    }
}

@Composable
private fun CanvasArrow(
    iconRes: Int,
    enabled: Boolean,
    label: String,
    onClick: () -> Unit,
) {
    Box(
        modifier = Modifier
            .size(44.dp)
            .noRippleClick(if (enabled) onClick else { {} }),
        contentAlignment = Alignment.Center,
    ) {
        if (enabled) {
            Icon(
                painter = painterResource(iconRes),
                contentDescription = label,
                modifier = Modifier.size(16.dp),
                tint = YColor.textTertiary,
            )
        }
    }
}

/** 08-8 `Star Tooltip`: "내 별 · {제목}", its shape and starlight, 「별 보기 ›」. */
@Composable
private fun PickedStarCard(
    model: AppModel,
    star: MonthConstellation.Star,
    onOpenStar: (StarItem) -> Unit,
) {
    val starItem = model.stars.firstOrNull { it.id == star.id }
    val shape = RoundedCornerShape(Radius.lg)
    val a = sky()

    val detail = if (!star.hasStarlight) {
        "별빛 없는 별"
    } else {
        val shapeLabel = (star.shape ?: starItem?.shape)?.label?.let { "모양: $it · " } ?: ""
        "${shapeLabel}별빛 ${star.starlight ?: 0}"
    }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(shape)
            .noRippleClick {
                if (starItem != null) onOpenStar(starItem)
            }
            .cosmos("picked-star", shape)
            .background(YColor.bgSurface, shape)
            .border(1.dp, YColor.starBright, shape)
            .padding(Space.lg),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(Space.xs),
        ) {
            Text(
                text = "내 별 · ${star.title}",
                style = YText.labelM,
                color = YColor.textPrimary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                text = detail,
                style = YText.caption,
                color = YColor.textTertiary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }

        Text(
            text = "별 보기 ›",
            style = YText.labelM,
            color = a.brandPrimary,
            modifier = Modifier.padding(start = Space.sm),
        )
    }
}

@Composable
private fun StatCard(
    value: Int,
    label: String,
    tappable: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val shape = RoundedCornerShape(Radius.lg)
    Column(
        modifier = modifier
            .clip(shape)
            .noRippleClick(if (tappable) onClick else { {} })
            .cosmos("stat-$label", shape)
            .background(YColor.bgSurface, shape)
            .border(1.dp, YColor.borderDefault, shape)
            .padding(Space.md),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(Space.xs),
    ) {
        Text(
            text = "$value",
            style = YText.h2,
            color = YColor.textPrimary,
        )
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(2.dp),
        ) {
            Text(
                text = label,
                style = YText.caption,
                color = YColor.textSecondary,
            )
            if (tappable) {
                Image(
                    painter = painterResource(R.drawable.icon_chevron_right),
                    contentDescription = null,
                    modifier = Modifier.size(14.dp),
                )
            }
        }
    }
}

private fun constellationDescription(c: MonthConstellation, month: String, thisMonth: String): String {
    return if (c.isComplete) {
        "${c.monthLabel} 저녁 하늘에 뜨는 ${c.name}를 모두 채웠어요. 자리보다 많이 띄운 별은 별자리 둘레에 은은하게 떠요."
    } else if (month < thisMonth) {
        "${c.monthLabel}에는 ${c.total}자리 중 ${c.filled}자리를 채웠어요. 남은 자리는 그달의 여백으로 남아요."
    } else {
        "${c.monthLabel} 저녁 하늘에 뜨는 ${c.name}예요. 별을 띄울 때마다 빈 자리가 하나씩 채워지고, ${c.total}개를 다 채우면 별자리가 완성돼요."
    }
}

/**
 * 04 이번 달 별자리 한 줄 (Figma 554:14661):
 * "11월 페가수스자리 · 6 / 9 자리 채움" and 「별자리 보기 ›」
 */
@Composable
fun MonthConstellationLink(
    model: AppModel,
    onOpen: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val thisMonth = remember { MonthConstellation.currentMonthKey() }
    val c = model.constellation(thisMonth)

    LaunchedEffect(thisMonth) {
        model.loadConstellation(thisMonth)
    }

    val shape = RoundedCornerShape(Radius.lg)
    val a = sky()

    Row(
        modifier = modifier
            .fillMaxWidth()
            .clip(shape)
            .noRippleClick(onOpen)
            .cosmos("home-constellation", shape)
            .background(YColor.bgSurface, shape)
            .border(1.dp, YColor.borderDefault, shape)
            .padding(horizontal = Space.lg, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(
            text = "${c.monthLabel} ${c.name} · ${c.filled} / ${c.total} 자리 채움",
            style = YText.caption,
            color = YColor.textSecondary,
            modifier = Modifier.weight(1f),
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
        Text(
            text = "별자리 보기 ›",
            style = YText.labelS,
            color = a.borderFocus,
            modifier = Modifier.padding(start = Space.sm),
        )
    }
}

/**
 * 567:15050: a 92dp band of the 81 Galaxy Canvas, "나의 은하수 ›", and
 * "별자리 N개 · 별 M개 · {첫 달}부터". Opens 81.
 */
@Composable
fun MilkyWayPreviewCard(
    model: AppModel,
    onOpen: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val timeline = remember(model.stars) {
        model.stars
            .filter { it.parsedDate != null }
            .sortedBy { it.parsedDate }
    }
    val first = model.firstConstellationMonth
    val firstMonthNum = first.takeLast(2).toIntOrNull() ?: 1
    val monthsCount = monthCount(first, MonthConstellation.currentMonthKey())
    val floatedCount = model.stars.count { it.isFloated }

    val shape = RoundedCornerShape(Radius.lg)

    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(shape)
            .noRippleClick(onOpen)
            .cosmos("milky-way-preview", shape)
            .background(YColor.bgSurface, shape)
            .border(1.dp, YColor.borderDefault, shape),
    ) {
        // 92dp clipped preview of galaxy river
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(92.dp)
                .clip(RoundedCornerShape(topStart = Radius.lg, topEnd = Radius.lg)),
        ) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(300.dp)
                    .offset(y = (-18).dp),
            ) {
                GalaxyRiver(timeline = timeline)
            }
        }

        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(Space.lg),
            verticalArrangement = Arrangement.spacedBy(Space.xs),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Text(
                    text = "나의 은하수",
                    fontFamily = NotoSerifKR,
                    fontWeight = FontWeight.Medium,
                    fontSize = 17.sp,
                    color = YColor.textPrimary,
                )
                Image(
                    painter = painterResource(R.drawable.icon_chevron_right),
                    contentDescription = null,
                    modifier = Modifier.size(16.dp),
                )
            }
            Text(
                text = "별자리 ${monthsCount}개 · 별 ${floatedCount}개 · ${firstMonthNum}월부터",
                fontFamily = Pretendard,
                fontSize = 13.sp,
                color = YColor.textTertiary,
            )
        }
    }
}

private fun monthCount(from: String, to: String): Int {
    fun n(m: String): Int {
        val p = m.split("-").mapNotNull { it.toIntOrNull() }
        return if (p.size == 2) p[0] * 12 + p[1] else 0
    }
    return maxOf(1, n(to) - n(from) + 1)
}
