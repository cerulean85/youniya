package com.dycdyp.youniya.ui.screens

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
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.dycdyp.youniya.data.AppModel
import com.dycdyp.youniya.data.PlazaNebula
import com.dycdyp.youniya.ui.components.PrimaryButton
import com.dycdyp.youniya.ui.components.SecondaryButton
import com.dycdyp.youniya.ui.components.TopAppBar
import com.dycdyp.youniya.ui.components.noRippleClick
import com.dycdyp.youniya.ui.design.StarField
import com.dycdyp.youniya.ui.theme.NotoSerifKR
import com.dycdyp.youniya.ui.theme.Radius
import com.dycdyp.youniya.ui.theme.Space
import com.dycdyp.youniya.ui.theme.YColor
import com.dycdyp.youniya.ui.theme.YText
import kotlinx.coroutines.launch

// MARK: - 75 다른 이의 별

@Composable
fun PlazaStarScreen(
    model: AppModel,
    star: PlazaNebula,
    onBack: () -> Unit,
    onKeeper: (String) -> Unit,
    onLine: () -> Unit,
    onBlocked: () -> Unit,
) {
    val scope = rememberCoroutineScope()
    var showMenu by remember { mutableStateOf(false) }
    var showReport by remember { mutableStateOf(false) }
    var showBlockConfirm by remember { mutableStateOf(false) }
    // Saveable, like iOS's @State on a pushed view: coming back from the keeper page keeps the
    // whole writing instead of showing "한 문장만" while it loads again.
    var liveTitle by rememberSaveable(star.serverID) { mutableStateOf<String?>(null) }
    var liveBody by rememberSaveable(star.serverID) { mutableStateOf<String?>(null) }
    val liveText = liveBody?.let { (liveTitle ?: "") to it }

    val serverId = star.serverID
    LaunchedEffect(star.serverID) {
        if (star.fullText && serverId != null && liveBody == null) {
            model.plazaStarText(serverId)?.let { liveTitle = it.first; liveBody = it.second }
        }
    }

    val title = liveText?.first?.ifEmpty { null } ?: star.fullTitle ?: star.starTitle ?: star.name
    val fullBody = liveText?.second ?: star.fullBody
    val isFullText = star.fullText && fullBody != null
    val resonated = star.name in model.resonated
    val dimAlpha = if (model.isPlazaRestricted) 0.45f else 1.0f

    Box(Modifier.fillMaxSize()) {
        StarField()
        Column(Modifier.fillMaxSize().safeDrawingPadding()) {
            PlazaTopAppBar(
                title = "다른 이의 별",
                onBack = onBack,
                onMore = { showMenu = true },
            )

            Column(
                modifier = Modifier
                    .weight(1f)
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = Space.xl, vertical = Space.sm),
                verticalArrangement = Arrangement.spacedBy(Space.lg),
            ) {
                // Header (56dp thumb + title + tags)
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(14.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    PlazaStarThumb(item = star, side = 56.dp)
                    Column(
                        modifier = Modifier.weight(1f),
                        verticalArrangement = Arrangement.spacedBy(Space.sm),
                    ) {
                        Text(title, style = YText.h2, color = YColor.textPrimary)
                        Row(horizontalArrangement = Arrangement.spacedBy(Space.sm)) {
                            if (star.nickname != null) {
                                Box(
                                    modifier = Modifier
                                        .clip(RoundedCornerShape(Radius.sm))
                                        .background(YColor.bgSurfaceRaised)
                                        .border(1.dp, YColor.borderDefault, RoundedCornerShape(Radius.sm))
                                        .noRippleClick { onKeeper(star.nickname) }
                                        .padding(horizontal = 8.dp, vertical = 4.dp),
                                ) {
                                    Text("${star.nickname} ›", style = YText.labelS, color = YColor.textSecondary)
                                }
                            } else {
                                Box(
                                    modifier = Modifier
                                        .clip(RoundedCornerShape(Radius.sm))
                                        .background(YColor.bgSurfaceRaised)
                                        .border(1.dp, YColor.borderDefault, RoundedCornerShape(Radius.sm))
                                        .padding(horizontal = 8.dp, vertical = 4.dp),
                                ) {
                                    Text("익명의 별지기", style = YText.labelS, color = YColor.textSecondary)
                                }
                            }
                            Box(
                                modifier = Modifier
                                    .clip(RoundedCornerShape(Radius.sm))
                                    .background(YColor.bgSurfaceRaised)
                                    .border(
                                        1.dp,
                                        if (star.hasStarlight) YColor.starBright.copy(alpha = 0.4f) else YColor.borderDefault,
                                        RoundedCornerShape(Radius.sm),
                                    )
                                    .padding(horizontal = 8.dp, vertical = 4.dp),
                            ) {
                                Text(
                                    if (star.hasStarlight) "깊이 ${star.cardDepth}단계" else "별빛 없는 별",
                                    style = YText.labelS,
                                    color = if (star.hasStarlight) YColor.starBright else YColor.textSecondary,
                                )
                            }
                        }
                    }
                }

                // 대표 문장 카드
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(Radius.lg))
                        .background(YColor.bgSurface)
                        .border(1.dp, YColor.borderDefault, RoundedCornerShape(Radius.lg))
                        .padding(Space.lg),
                    verticalArrangement = Arrangement.spacedBy(Space.xs),
                ) {
                    if (star.line.isNotEmpty()) {
                        Text("“${star.line}”", style = YText.observation, color = YColor.textPrimary)
                    }
                    Text(
                        if (isFullText) "대표 문장이에요. 아래에서 글 전체를 읽을 수 있어요."
                        else "본인이 고른 한 문장만 나눈 별이에요",
                        style = YText.caption,
                        color = YColor.textTertiary,
                    )
                }

                // 본문 (글 전체 공유된 경우)
                if (isFullText && fullBody != null) {
                    SelectionContainer {
                        Text(
                            text = fullBody,
                            fontFamily = NotoSerifKR,
                            fontSize = 15.sp,
                            lineHeight = (15 * 1.75).sp,
                            color = YColor.textSecondary,
                            modifier = Modifier.fillMaxWidth(),
                        )
                    }
                }

                Spacer(Modifier.height(Space.md))

                // Actions
                Column(
                    modifier = Modifier.fillMaxWidth(),
                    verticalArrangement = Arrangement.spacedBy(Space.md),
                ) {
                    PrimaryButton(
                        text = if (resonated) "공명했어요" else "공명 남기기",
                        modifier = Modifier.alpha(dimAlpha),
                        onClick = {
                            if (model.plazaAllowed()) {
                                model.toggleResonance(star)
                            }
                        },
                    )
                    SecondaryButton(
                        text = "별빛 한 줄 건네기",
                        modifier = Modifier.alpha(dimAlpha),
                        onClick = {
                            if (model.plazaAllowed()) {
                                onLine()
                            }
                        },
                    )
                    if (star.nickname != null) {
                        SecondaryButton(
                            text = "${star.nickname}의 밤하늘",
                            onClick = { onKeeper(star.nickname) },
                        )
                    }
                }
            }
        }

        // More Menu
        PlazaMoreMenuPopup(
            visible = showMenu,
            onDismiss = { showMenu = false },
            onReport = { showReport = true },
            onBlock = { showBlockConfirm = true },
        )

        // 100 Report Sheet
        if (showReport) {
            YouniyaSheet("report-sheet", onDismiss = { showReport = false }) {
                ReportSheetContent(
                    title = "이 별을 신고할까요?",
                    message = "신고한 별은 운영팀이 살펴봐요. 누가 신고했는지는 알리지 않아요.",
                    onReport = { reason, alsoBlock ->
                        showReport = false
                        scope.launch {
                            val targetId = star.serverID ?: star.name
                            if (model.reportShare(targetId, reason, alsoBlock)) {
                                if (alsoBlock) {
                                    onBlocked()
                                } else {
                                    model.message = "신고를 받았어요. 살펴본 뒤 결과를 알림으로 알려 드릴게요."
                                }
                            }
                        }
                    },
                    onCancel = { showReport = false },
                )
            }
        }

        // 75-2 Block Confirm Sheet
        if (showBlockConfirm) {
            YouniyaSheet("block-sheet", onDismiss = { showBlockConfirm = false }) {
                BlockConfirmSheet(
                    onBlock = {
                        showBlockConfirm = false
                        scope.launch {
                            val targetId = star.serverID ?: star.name
                            if (model.blockKeeper(targetId)) {
                                onBlocked()
                            }
                        }
                    },
                    onCancel = { showBlockConfirm = false },
                )
            }
        }
    }
}

// MARK: - 76-1 별지기 페이지

@Composable
fun KeeperPageScreen(
    model: AppModel,
    nickname: String,
    onBack: () -> Unit,
    onOpenStar: (PlazaNebula) -> Unit,
) {
    var stars by remember { mutableStateOf<List<PlazaNebula>?>(null) }
    var loaded by remember { mutableStateOf(false) }

    val isMine = nickname == model.nickname

    LaunchedEffect(nickname) {
        stars = model.keeperStars(nickname)
        loaded = true
    }

    Box(Modifier.fillMaxSize()) {
        StarField()
        Column(Modifier.fillMaxSize().safeDrawingPadding()) {
            TopAppBar(title = "별지기", onBack = onBack)

            Column(
                modifier = Modifier
                    .weight(1f)
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = Space.xl, vertical = Space.sm),
                verticalArrangement = Arrangement.spacedBy(Space.lg),
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(Space.sm)) {
                    Text("${nickname}의 밤하늘", style = YText.h1, color = YColor.textPrimary)
                    Text(
                        if (isMine) "다른 별지기에게는 이렇게 보여요. 우주 광장에 나눈 별만 보이고, 나누지 않은 기록과 수치는 보이지 않아요."
                        else "${nickname}이 우주 광장에 나눈 별이에요. 나누지 않은 기록과 수치는 보이지 않아요.",
                        style = YText.bodyS,
                        color = YColor.textSecondary,
                    )
                }

                val currentStars = stars
                if (currentStars != null) {
                    Text("나눈 별 ${currentStars.size}", style = YText.h3, color = YColor.textPrimary)
                    if (currentStars.isEmpty()) {
                        Text("아직 나눈 별이 없어요.", style = YText.bodyM, color = YColor.textTertiary)
                    } else {
                        Column {
                            currentStars.forEachIndexed { idx, item ->
                                PlazaStarRow(
                                    item = item,
                                    resonated = item.name in model.resonated,
                                    onOpen = { onOpenStar(item) },
                                )
                                if (idx < currentStars.size - 1) {
                                    HorizontalDivider(
                                        color = YColor.textPrimary.copy(alpha = 0.08f),
                                        thickness = 1.dp,
                                    )
                                }
                            }
                        }
                    }
                } else if (loaded) {
                    Text("이 별지기의 밤하늘을 볼 수 없어요.", style = YText.bodyM, color = YColor.textTertiary)
                } else {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(160.dp),
                        contentAlignment = Alignment.Center,
                    ) {
                        CircularProgressIndicator(color = YColor.textPrimary)
                    }
                }
            }
        }
    }
}
