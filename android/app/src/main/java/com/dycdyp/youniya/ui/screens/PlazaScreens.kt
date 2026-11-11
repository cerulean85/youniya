package com.dycdyp.youniya.ui.screens

import androidx.compose.animation.AnimatedVisibility
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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.dycdyp.youniya.R
import com.dycdyp.youniya.data.AppModel
import com.dycdyp.youniya.data.PlazaFilter
import com.dycdyp.youniya.data.PlazaNebula
import com.dycdyp.youniya.data.StarShapeSpec
import com.dycdyp.youniya.data.formatPlazaWhen
import com.dycdyp.youniya.ui.components.GhostButton
import com.dycdyp.youniya.ui.components.PrimaryButton
import com.dycdyp.youniya.ui.components.SecondaryButton
import com.dycdyp.youniya.ui.components.noRippleClick
import com.dycdyp.youniya.ui.design.ShapeStar
import com.dycdyp.youniya.ui.design.StarField
import com.dycdyp.youniya.ui.design.Twinkle
import com.dycdyp.youniya.ui.design.dimScale
import com.dycdyp.youniya.ui.design.twinkle
import com.dycdyp.youniya.ui.theme.Radius
import com.dycdyp.youniya.ui.theme.Space
import com.dycdyp.youniya.ui.theme.YColor
import com.dycdyp.youniya.ui.theme.YText
import com.dycdyp.youniya.ui.theme.sky

// MARK: - 09-5 우주 광장 메인 뷰

@Composable
fun PlazaView(
    model: AppModel,
    onOpenStar: (PlazaNebula) -> Unit,
    onNickname: () -> Unit,
    onShared: () -> Unit,
) {
    var filter by remember { mutableStateOf(PlazaFilter.Newest) }
    var shown by remember { mutableIntStateOf(20) }

    LaunchedEffect(Unit) {
        model.loadPlaza()
        model.loadTonight()
    }

    val stars = remember(filter, model.plazaStarItems, model.plazaStarsBeside, model.resonated) {
        val all: List<PlazaNebula> = when (filter) {
            PlazaFilter.Newest -> model.plazaStarItems.sortedBy { it.order }
            PlazaFilter.Similar -> model.plazaStarItems.filter { it.hasStarlight }.sortedByDescending { it.similarity }
            PlazaFilter.Kept -> {
                if (model.plazaStarsBeside.isNotEmpty()) model.plazaStarsBeside
                else model.plazaStarItems.filter { it.name in model.resonated }.sortedBy { it.order }
            }
        }
        if (filter == PlazaFilter.Similar) all
        else all.filter { it.hasStarlight } + all.filter { !it.hasStarlight }
    }

    val tonightCount = model.tonightCount ?: 0
    val tonightMine = model.tonightMine ?: 0
    val sharedCount = model.stars.count { it.isShared }

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = Space.xl),
        verticalArrangement = Arrangement.spacedBy(Space.lg),
    ) {
        item {
            Column(verticalArrangement = Arrangement.spacedBy(Space.sm)) {
                Text("우주 광장", style = YText.h1, color = YColor.textPrimary)
                Text(
                    "별지기들이 나눈 별이에요. 눌러서 글을 읽고, 마음이 닿으면 공명을 남겨 보세요.",
                    style = YText.bodyS,
                    color = YColor.textSecondary,
                )
            }
        }

        // 09-6 광장 이용 제한 배너
        if (model.isPlazaRestricted) {
            item {
                OperatorBanner(
                    title = "광장 이용이 ${model.restrictedText(false)}까지 멈춰요",
                    message = "별을 나누거나 공명·곁에 두기·별빛 한 줄을 남길 수 없어요. 내 기록과 별은 그대로이고, 다른 별은 계속 읽을 수 있어요.",
                    link = "자세히",
                    onClick = { model.showPlazaRestricted = true },
                )
            }
        }

        // 69 오늘 밤 줄
        if (tonightCount > 0) {
            item {
                Box(
                    modifier = Modifier
                        .clip(CircleShape)
                        .background(YColor.tintGold)
                        .padding(horizontal = Space.md, vertical = Space.xs),
                ) {
                    val line = if (tonightMine > 0) {
                        "오늘 밤, ${tonightCount}개의 마음이 모였어요 · 내 별 ${tonightMine}개도 함께 빛나요"
                    } else {
                        "오늘 밤, ${tonightCount}개의 마음이 모였어요"
                    }
                    Text(text = line, style = YText.labelS, color = YColor.starBright)
                }
            }
        }

        // 내가 나눈 별 바로가기
        if (model.nickname != null) {
            item {
                Row(
                    modifier = Modifier
                        .noRippleClick(onShared)
                        .padding(vertical = Space.xs),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(2.dp),
                ) {
                    Text("내가 나눈 별 ${sharedCount}개", style = YText.bodyS, color = YColor.textSecondary)
                    androidx.compose.foundation.Image(
                        painter = painterResource(R.drawable.icon_chevron_right),
                        contentDescription = null,
                        modifier = Modifier.size(14.dp),
                    )
                }
            }
        }

        // 21-1 닉네임 게이트 또는 목록
        if (model.nickname == null) {
            item {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(Radius.lg))
                        .background(YColor.bgSurface)
                        .border(1.dp, YColor.borderDefault, RoundedCornerShape(Radius.lg))
                        .padding(Space.lg),
                    verticalArrangement = Arrangement.spacedBy(Space.md),
                ) {
                    Text("별지기 이름이 필요해요", style = YText.h3, color = YColor.textPrimary)
                    Text(
                        "우주 광장에서는 나눈 별과 건넨 별빛 한 줄에 별지기 이름이 함께 보여요. 기록 쓰기와 별 띄우기는 이름 없이도 그대로예요.",
                        style = YText.bodyM,
                        color = YColor.textSecondary,
                    )
                    PrimaryButton(text = "별지기 이름 정하기", onClick = onNickname)
                }
            }
        } else {
            // 필터 탭 3종
            item {
                Row(horizontalArrangement = Arrangement.spacedBy(Space.sm)) {
                    PlazaFilter.entries.forEach { f ->
                        val isSelected = filter == f
                        val theme = sky()
                        Box(
                            modifier = Modifier
                                .clip(CircleShape)
                                .background(if (isSelected) theme.tint.copy(alpha = 0.2f) else YColor.bgSurfaceRaised)
                                .border(
                                    1.dp,
                                    if (isSelected) theme.strong else YColor.borderDefault,
                                    CircleShape,
                                )
                                .noRippleClick {
                                    filter = f
                                    shown = 20
                                }
                                .padding(horizontal = 14.dp, vertical = 8.dp),
                        ) {
                            Text(
                                text = f.title,
                                style = YText.labelS,
                                color = if (isSelected) YColor.textPrimary else YColor.textSecondary,
                            )
                        }
                    }
                }
            }

            // 별 목록
            if (stars.isEmpty()) {
                item {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(top = 48.dp, bottom = 48.dp),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(Space.sm),
                    ) {
                        if (filter == PlazaFilter.Kept) {
                            Text("곁에 둔 별이 아직 없어요", style = YText.h2, color = YColor.textPrimary)
                            Text(
                                "마음이 닿은 별에 공명을 남기면\n여기서 다시 모아 볼 수 있어요.",
                                style = YText.bodyM,
                                color = YColor.textSecondary,
                                textAlign = TextAlign.Center,
                            )
                            Spacer(Modifier.height(Space.md))
                            SecondaryButton("새로 뜬 것 둘러보기") { filter = PlazaFilter.Newest }
                        } else {
                            Text("아직 나눠진 별이 없어요", style = YText.h2, color = YColor.textPrimary)
                            Text("누군가 별을 나누면 여기에 한 문장씩 모여요.", style = YText.bodyM, color = YColor.textSecondary)
                        }
                    }
                }
            } else {
                val displayed = stars.take(shown)
                itemsIndexed(displayed, key = { _, item -> item.id }) { index, item ->
                    PlazaStarRow(
                        item = item,
                        resonated = item.name in model.resonated,
                        onOpen = { onOpenStar(item) },
                    )
                    if (index < displayed.size - 1) {
                        HorizontalDivider(
                            color = YColor.textPrimary.copy(alpha = 0.08f),
                            thickness = 1.dp,
                        )
                    }
                }

                if (stars.size > shown) {
                    item {
                        GhostButton(text = "더 보기") { shown += 20 }
                    }
                }
            }
        }
        item { Spacer(Modifier.height(Space.xxl)) }
    }
}

// MARK: - Plaza Star Row

@Composable
fun PlazaStarRow(
    item: PlazaNebula,
    resonated: Boolean,
    onOpen: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .noRippleClick(onOpen)
            .padding(vertical = 14.dp),
        horizontalArrangement = Arrangement.spacedBy(14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        PlazaStarThumb(item = item, side = 44.dp)
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(3.dp),
        ) {
            Text(
                text = "“${item.line}”",
                style = YText.observation,
                color = YColor.textPrimary,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
            val who = item.nickname?.let { "$it  「${item.starTitle ?: item.name}」" } ?: item.name
            val tail = if (item.hasStarlight) formatPlazaWhen(item.sharedAt) else "별빛 없음"
            Text(
                text = "$who · $tail",
                style = YText.caption,
                color = YColor.textSecondary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
        val theme = sky()
        Text(
            text = "✦",
            style = YText.labelM,
            color = if (resonated) theme.brandPrimaryText else YColor.textTertiary.copy(alpha = 0.6f),
        )
    }
}

// MARK: - Plaza Star Thumb

@Composable
fun PlazaStarThumb(
    item: PlazaNebula,
    side: Dp = 44.dp,
) {
    val k = side.value / 44f
    val cornerRadius = if (side == 44.dp) 12.dp else 16.dp
    val spec = if (item.hasStarlight) item.cardShape else StarShapeSpec(points = 4, sharpness = StarShapeSpec.Sharpness.soft)
    val moodColor = item.cardMood.color.copy(alpha = if (item.hasStarlight) 1f else 0.5f)
    val starSize = (if (item.hasStarlight) 22f else 14f) * k

    Box(
        modifier = Modifier
            .size(side)
            .clip(RoundedCornerShape(cornerRadius))
            .background(YColor.bgSurfaceRaised)
            .then(
                if (item.hasStarlight) {
                    Modifier.shadow(
                        elevation = ((1f + item.cardDepth * 1.2f) * k).dp,
                        shape = RoundedCornerShape(cornerRadius),
                        ambientColor = item.cardMood.color,
                        spotColor = item.cardMood.color,
                    )
                } else Modifier
            ),
        contentAlignment = Alignment.Center,
    ) {
        ShapeStar(
            spec = spec,
            color = moodColor,
            size = starSize.dp,
            halo = false,
        )
    }
}

// MARK: - 21 Plaza Welcome View

@Composable
fun PlazaWelcomeView(
    onBrowse: () -> Unit,
    onLater: () -> Unit,
) {
    Box(Modifier.fillMaxSize()) {
        StarField()
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = Space.xl, vertical = Space.xl),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Spacer(Modifier.height(Space.xxl))
            PlazaHero()
            Spacer(Modifier.height(Space.xl))

            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(Space.sm),
            ) {
                Text(
                    text = "우주 광장에 오신 걸\n환영해요",
                    style = YText.h1,
                    color = YColor.textPrimary,
                    textAlign = TextAlign.Center,
                )
                Text(
                    text = "점수도 순위도 없는 곳이에요.\n마음에 닿으면 '공명'이나 '별빛 한 줄'을 남길 수 있어요.",
                    style = YText.bodyM,
                    color = YColor.textSecondary,
                    textAlign = TextAlign.Center,
                )
            }

            Spacer(Modifier.weight(1f))

            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(Space.md),
            ) {
                PrimaryButton(text = "둘러보기", onClick = onBrowse)
                GhostButton(text = "다음에", onClick = onLater)
            }
        }
    }
}

// MARK: - Plaza Hero Graphics

@Composable
fun PlazaHero() {
    val theme = sky()
    Box(
        modifier = Modifier
            .size(width = 342.dp, height = 140.dp),
        contentAlignment = Alignment.Center,
    ) {
        // Outer orbit
        Box(
            modifier = Modifier
                .size(130.dp)
                .border(1.dp, theme.strong.copy(alpha = 0.3f), CircleShape)
        )
        // Inner orbit
        Box(
            modifier = Modifier
                .size(86.dp)
                .border(1.5.dp, theme.strong.copy(alpha = 0.5f), CircleShape)
        )
        // Center planet
        Box(
            modifier = Modifier
                .size(26.dp)
                .twinkle(Twinkle(duration = 2.0, keys = listOf(0.0 to 1.0, 0.475 to 0.3, 1.0 to 1.0)), scale = dimScale)
                .background(theme.strong, CircleShape)
        )
        // Center core
        Box(
            modifier = Modifier
                .size(10.dp)
                .twinkle(Twinkle(duration = 2.0, keys = listOf(0.0 to 1.0, 0.155 to 0.3, 0.705 to 1.0, 1.0 to 0.3)), scale = dimScale)
                .background(YColor.starBright, CircleShape)
        )
    }
}
