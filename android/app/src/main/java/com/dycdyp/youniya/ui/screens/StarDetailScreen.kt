package com.dycdyp.youniya.ui.screens

import android.app.Activity
import androidx.activity.compose.BackHandler
import androidx.compose.ui.platform.LocalContext
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.dycdyp.youniya.data.AppModel
import com.dycdyp.youniya.data.StarItem
import com.dycdyp.youniya.ui.components.ActionSheetContent
import com.dycdyp.youniya.ui.components.BreakdownToggle
import com.dycdyp.youniya.ui.components.DangerButton
import com.dycdyp.youniya.ui.components.GhostButton
import com.dycdyp.youniya.ui.components.PrimaryButton
import com.dycdyp.youniya.ui.components.SecondaryButton
import com.dycdyp.youniya.ui.components.SheetGrabber
import com.dycdyp.youniya.ui.components.StarlightBreakdown
import com.dycdyp.youniya.ui.components.TodayStarCard
import com.dycdyp.youniya.ui.components.TopAppBar
import com.dycdyp.youniya.ui.components.noRippleClick
import com.dycdyp.youniya.ui.design.StarField
import com.dycdyp.youniya.ui.theme.Space
import com.dycdyp.youniya.ui.theme.YColor
import com.dycdyp.youniya.ui.theme.YText
import kotlinx.coroutines.launch

/**
 * 12 Star Detail (iOS StarDetailView):
 * the full entry, its card (if floated), and actions.
 */
@Composable
fun StarDetailScreen(
    model: AppModel,
    starId: String,
    onBack: () -> Unit,
    onRewrite: () -> Unit = {},
    onDeleted: (() -> Unit)? = null,
    onEdit: () -> Unit = {},
    onFloat: () -> Unit = {},
    onRevise: () -> Unit = {},
    onLinkExisting: () -> Unit = {},
    onOpenLinked: (StarItem) -> Unit = {},
    onOpenLines: (String) -> Unit = {},
    onReviewShare: (String) -> Unit = {},
    modifier: Modifier = Modifier,
) {
    val star = model.stars.firstOrNull { it.id == starId }

    var confirmDelete by remember { mutableStateOf(false) }
    var showBreakdown by remember { mutableStateOf(false) }
    var askLink by remember { mutableStateOf(false) }
    var unlinkTarget by remember { mutableStateOf<StarItem?>(null) }
    var showShareSheet by remember { mutableStateOf(false) }
    var confirmShare by remember { mutableStateOf(false) }
    var pickQuote by remember { mutableStateOf(false) }
    // 22장: 별 제목 넣기 is off by default.
    var withTitle by remember { mutableStateOf(false) }
    val context = LocalContext.current
    val activity = context as? Activity

    val scope = rememberCoroutineScope()

    BackHandler(enabled = true, onBack = onBack)

    if (star == null) {
        NotFoundView(onBack = onBack, modifier = modifier)
        return
    }

    LaunchedEffect(starId) {
        model.starDetail(starId)
    }

    Box(
        modifier
            .fillMaxSize()
            .background(YColor.bgCanvas),
    ) {
        StarField()

        Column(
            Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .navigationBarsPadding(),
        ) {
            TopAppBar(title = "별 상세", onBack = onBack)

            Column(
                Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = Space.xl)
                    .padding(top = Space.sm, bottom = Space.xxxl),
                verticalArrangement = Arrangement.spacedBy(Space.lg),
            ) {
                // Header (Date & Title)
                Column(
                    verticalArrangement = Arrangement.spacedBy(Space.xs),
                    modifier = Modifier.semantics(mergeDescendants = true) { heading() },
                ) {
                    val dateHeader = if (star.isFloated) star.longDateText else "${star.longDateText} · 별빛 없는 별"
                    Text(
                        text = dateHeader,
                        style = YText.caption,
                        color = YColor.textTertiary,
                    )
                    Text(
                        text = star.title,
                        style = YText.h1,
                        color = YColor.textPrimary,
                    )
                }

                // Body text
                if (star.body.isNotEmpty()) {
                    Text(
                        text = star.body,
                        style = YText.journalBody,
                        color = YColor.textSecondary,
                    )
                }

                // Star card & Breakdown
                if (star.analysis != null) {
                    TodayStarCard(
                        analysis = star.analysis,
                        onClick = { showBreakdown = !showBreakdown },
                    )
                    AnimatedVisibility(
                        visible = showBreakdown,
                        enter = fadeIn(),
                        exit = fadeOut(),
                    ) {
                        StarlightBreakdown(analysis = star.analysis)
                    }
                    BreakdownToggle(
                        isOpen = showBreakdown,
                        onToggle = { showBreakdown = !showBreakdown },
                    )
                }

                // Kept star float prompt (12-1)
                if (!star.isFloated) {
                    val isLongEnough = star.body.length >= AppModel.minFloatLength
                    PrimaryButton(
                        text = "별빛 받기",
                        enabled = isLongEnough,
                        onClick = onFloat,
                    )
                    val hint = if (isLongEnough) {
                        (if (model.isFloatFree) "오늘 무료 1번 · 이후 " else "") +
                            "한 번에 ${AppModel.floatCost}코인 · ${AppModel.minFloatLength}자부터 받을 수 있어요"
                    } else {
                        "${AppModel.minFloatLength}자부터 별빛을 받을 수 있어요 · 지금 ${star.body.length}자"
                    }
                    Text(
                        text = hint,
                        style = YText.caption,
                        color = YColor.textTertiary,
                        modifier = Modifier.fillMaxWidth(),
                        textAlign = TextAlign.Center,
                    )
                }

                // Lines button (12 / 12-4)
                val lineCount = star.lineCount ?: 0
                if (star.isShared || lineCount > 0) {
                    val lineTitle = if (lineCount > 0) "받은 별빛 한 줄 ${lineCount}개 ›" else "받은 별빛 한 줄 ›"
                    SecondaryButton(
                        text = lineTitle,
                        onClick = { onOpenLines(star.id) },
                    )
                }

                // Linked stars group (12-2)
                val linked = model.linkedStars(star.id)
                if (linked.isNotEmpty()) {
                    LinkedStarsSection(
                        linked = linked,
                        onOpen = onOpenLinked,
                        onLongClick = { unlinkTarget = it },
                    )
                }

                // Primary action: Link star or Edit
                if (star.isFloated) {
                    PrimaryButton(
                        text = "별 잇기",
                        onClick = { askLink = true },
                    )
                } else {
                    SecondaryButton(
                        text = "글 수정",
                        onClick = onEdit,
                    )
                }

                // Plaza share toggle
                if (star.isFloated) {
                    val plazaTitle = if (star.isShared) "우주 광장에서 거두기" else "우주 광장에 나누기"
                    SecondaryButton(
                        text = plazaTitle,
                        onClick = {
                            if (star.isShared) {
                                scope.launch {
                                    model.unshareStarLive(star.id)
                                    model.message = "광장에서 거뒀어요. 언제든 다시 나눌 수 있어요."
                                }
                            } else {
                                confirmShare = true
                            }
                        },
                    )
                }

                // 12-12 Action row (카드 공유 · 내보내기 · 고쳐 쓰기 · 삭제)
                Row(
                    Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(Space.sm),
                ) {
                    GhostButton(
                        text = "카드 공유",
                        compact = true,
                        modifier = Modifier.weight(1f),
                        onClick = { showShareSheet = true },
                    )
                    GhostButton(
                        text = "내보내기",
                        compact = true,
                        modifier = Modifier.weight(1f),
                        onClick = { model.message = "다음 단계에서 만들어요." },
                    )
                    if (star.isFloated) {
                        GhostButton(
                            text = "고쳐 쓰기",
                            compact = true,
                            modifier = Modifier.weight(1f),
                            onClick = onRevise,
                        )
                    }
                    GhostButton(
                        text = "삭제",
                        compact = true,
                        modifier = Modifier.weight(1f),
                        onClick = { confirmDelete = true },
                    )
                }
            }
        }

        // 15 Delete Confirm Sheet
        if (confirmDelete) {
            YouniyaSheet("delete-sheet", onDismiss = { confirmDelete = false }) {
                Column(
                    Modifier
                        .fillMaxWidth()
                        .padding(horizontal = Space.xl)
                        .padding(top = Space.md, bottom = Space.xl),
                    verticalArrangement = Arrangement.spacedBy(Space.lg),
                ) {
                    SheetGrabber()

                    Column(verticalArrangement = Arrangement.spacedBy(Space.sm)) {
                        Text("이 별을 어떻게 할까요?", style = YText.h3, color = YColor.textPrimary)
                        Text(
                            "영구 삭제하면 쓴 글과 별빛 풀이가 모두 사라지고 되돌릴 수 없어요. 먼저 내보내 둘 수 있어요.",
                            style = YText.bodyM,
                            color = YColor.textSecondary,
                        )
                    }

                    Column(
                        Modifier.fillMaxWidth(),
                        verticalArrangement = Arrangement.spacedBy(Space.md),
                    ) {
                        PrimaryButton(
                            text = "그대로 두기",
                            onClick = { confirmDelete = false },
                        )
                        SecondaryButton(
                            text = "내보내기",
                            onClick = {
                                model.message = "다음 단계에서 만들어요."
                            },
                        )
                        DangerButton(
                            text = "영구 삭제",
                            onClick = {
                                confirmDelete = false
                                scope.launch {
                                    model.deleteStar(star.id)
                                    (onDeleted ?: onBack)()
                                }
                            },
                        )
                    }
                }
            }
        }

        // 12-6 이 별과 무엇을 이을까요? 시트
        if (askLink) {
            YouniyaSheet("link-ask", onDismiss = { askLink = false }) {
                ActionSheetContent(
                    title = "이 별과 무엇을 이을까요?",
                    message = "이은 별은 서로의 별 상세에 '이어진 별'로 보여요. 여러 별과 이을 수 있고, 언제든 끊을 수 있어요.",
                    primaryText = "새 글을 써서 잇기",
                    onPrimary = {
                        askLink = false
                        onRewrite()
                    },
                    secondaryText = "이미 쓴 별과 잇기",
                    onSecondary = {
                        askLink = false
                        onLinkExisting()
                    },
                    ghostText = "취소",
                    onGhost = { askLink = false },
                )
            }
        }

        // 연결 끊기 확인 시트
        if (unlinkTarget != null) {
            val target = unlinkTarget!!
            YouniyaSheet("unlink-sheet", onDismiss = { unlinkTarget = null }) {
                ActionSheetContent(
                    title = "이 별과의 연결을 끊을까요?",
                    message = "「${target.title}」와의 연결만 끊어지고, 두 별의 글과 별빛은 그대로 남아요.",
                    primaryText = "연결 끊기",
                    onPrimary = {
                        val otherId = target.id
                        unlinkTarget = null
                        scope.launch {
                            model.unlinkStar(star.id, otherId)
                        }
                    },
                    ghostText = "취소",
                    onGhost = { unlinkTarget = null },
                )
            }
        }

        // 12-13 공유 시트
        if (showShareSheet) {
            YouniyaSheet("star-share-sheet", onDismiss = { showShareSheet = false }) {
                CardShareSheetContent(
                    title = "별 카드로 나누기",
                    withTitle = withTitle,
                    onTitleToggle = { withTitle = it },
                    cardPreview = {
                        StarShareCard(model = model, star = star, withTitle = withTitle)
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
                            CardShareUtil.shareToOtherApps(context, uri, "별 카드로 나누기")
                        }
                        showShareSheet = false
                    },
                )
            }
        }

        // 19 공유 동의 시트
        if (confirmShare) {
            YouniyaSheet("share-consent", onDismiss = { confirmShare = false }) {
                ShareConsentSheet(
                    onShare = {
                        confirmShare = false
                        pickQuote = true
                    },
                    onReview = {
                        confirmShare = false
                        onReviewShare(star.id)
                    },
                    onCancel = { confirmShare = false },
                )
            }
        }

        // 19-1 대표 문장 고르기 시트
        if (pickQuote) {
            YouniyaSheet("quote-picker", onDismiss = { pickQuote = false }) {
                SentencePickerSheet(
                    model = model,
                    title = "대표 문장 고르기",
                    detail = "고른 문장은 광장 목록에 대표로 보여요. 글 전체도 함께 공개되고, 전화번호·이메일은 ●●●로 가려져요.",
                    actionTitle = if (star.isShared) "이 문장으로 바꾸기" else "이 문장으로 나누기",
                    options = model.sentenceOptions(star.id),
                    fullText = star.title to star.body,
                    onPick = { quote ->
                        scope.launch {
                            val ok = model.shareStarLive(star.id, quote = quote)
                            pickQuote = false
                            if (ok) model.message = "우주 광장에 별을 나눴어요."
                        }
                    },
                    onCancel = { pickQuote = false },
                )
            }
        }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun LinkedStarsSection(
    linked: List<StarItem>,
    onOpen: (StarItem) -> Unit,
    onLongClick: (StarItem) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(Space.sm)) {
        Text(
            text = "이어진 별 ${linked.size}",
            style = YText.labelM,
            color = YColor.textPrimary,
            modifier = Modifier.semantics { heading() },
        )
        Row(
            Modifier.horizontalScroll(rememberScrollState()),
            horizontalArrangement = Arrangement.spacedBy(Space.sm),
        ) {
            linked.forEach { other ->
                Row(
                    Modifier
                        .background(YColor.bgSurface, CircleShape)
                        .border(1.dp, YColor.borderDefault, CircleShape)
                        .combinedClickable(
                            interactionSource = null,
                            indication = null,
                            onClick = { onOpen(other) },
                            onLongClick = { onLongClick(other) },
                        )
                        .padding(horizontal = Space.md, vertical = Space.sm),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    Box(
                        Modifier
                            .size(7.dp)
                            .background(other.mood.color, CircleShape),
                    )
                    Text(
                        text = other.title,
                        style = YText.labelS,
                        color = YColor.textPrimary,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                    Text(
                        text = other.shortDateText,
                        style = YText.caption,
                        color = YColor.textTertiary,
                    )
                }
            }
        }
    }
}
