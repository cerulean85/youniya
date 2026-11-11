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
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp
import com.dycdyp.youniya.R
import com.dycdyp.youniya.data.AppModel
import com.dycdyp.youniya.data.MaskPreview
import com.dycdyp.youniya.data.MyShareStarItem
import com.dycdyp.youniya.data.PrivacyScan
import com.dycdyp.youniya.data.SentenceOption
import com.dycdyp.youniya.data.StarItem
import com.dycdyp.youniya.ui.components.GhostButton
import com.dycdyp.youniya.ui.components.NoticeBanner
import com.dycdyp.youniya.ui.components.PrimaryButton
import com.dycdyp.youniya.ui.components.SecondaryButton
import com.dycdyp.youniya.ui.components.SheetGrabber
import com.dycdyp.youniya.ui.components.StarRow
import com.dycdyp.youniya.ui.components.TopAppBar
import com.dycdyp.youniya.ui.components.noRippleClick
import com.dycdyp.youniya.ui.design.StarField
import com.dycdyp.youniya.ui.theme.Radius
import com.dycdyp.youniya.ui.theme.Space
import com.dycdyp.youniya.ui.theme.YColor
import com.dycdyp.youniya.ui.theme.YText
import com.dycdyp.youniya.ui.theme.sky
import kotlinx.coroutines.launch

// MARK: - 19 우주 광장에 나눌까요?

@Composable
fun ShareConsentSheet(
    onShare: () -> Unit,
    onReview: () -> Unit,
    onCancel: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = Space.xl, vertical = Space.lg),
        verticalArrangement = Arrangement.spacedBy(Space.lg),
    ) {
        SheetGrabber()
        Column(verticalArrangement = Arrangement.spacedBy(Space.sm)) {
            Text("우주 광장에 나눌까요?", style = YText.h3, color = YColor.textPrimary)
            Text(
                "고른 대표 문장과 함께 글 전체가 내 별지기 이름과 함께 올라가요. 전화번호와 이메일은 자동으로 가려져요. 다른 사람은 '공명'만 남길 수 있고, 언제든 거둘 수 있어요.",
                style = YText.bodyM,
                color = YColor.textSecondary,
            )
        }
        Column(verticalArrangement = Arrangement.spacedBy(Space.md)) {
            PrimaryButton(text = "광장에 나누기", onClick = onShare)
            SecondaryButton(text = "내용 먼저 확인", onClick = onReview)
            GhostButton(text = "나누지 않기", onClick = onCancel)
        }
    }
}

// MARK: - 19-1 대표 문장 고르기

@Composable
fun SentencePickerSheet(
    model: AppModel,
    title: String = "대표 문장 고르기",
    detail: String = "고른 문장은 광장 목록에 대표로 보여요. 글 전체도 함께 공개되고, 전화번호·이메일은 ●●●로 가려져요.",
    actionTitle: String = "이 문장으로 나누기",
    options: List<SentenceOption>,
    fullText: Pair<String, String>? = null,
    onPick: (String) -> Unit,
    onCancel: () -> Unit,
) {
    val longest = remember(options) { options.maxByOrNull { it.sentence.length }?.id }
    var selectedId by remember { mutableStateOf(longest) }
    var showFullText by remember { mutableStateOf(false) }
    val previews = remember { mutableStateMapOf<Int, MaskPreview>() }
    val theme = sky()

    LaunchedEffect(selectedId) {
        val id = selectedId ?: return@LaunchedEffect
        if (previews[id] == null) {
            val opt = options.firstOrNull { it.id == id } ?: return@LaunchedEffect
            previews[id] = model.maskPreview(opt.sentence, contactsOnly = fullText != null)
        }
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = Space.xl, vertical = Space.lg),
        verticalArrangement = Arrangement.spacedBy(Space.lg),
    ) {
        SheetGrabber()
        Column(verticalArrangement = Arrangement.spacedBy(Space.sm)) {
            Text(title, style = YText.h3, color = YColor.textPrimary)
            Text(detail, style = YText.bodyM, color = YColor.textSecondary)
        }

        Column(
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(max = 380.dp)
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(Space.sm),
        ) {
            options.forEach { option ->
                val isOn = option.id == selectedId
                val preview = (if (isOn) previews[option.id] else null)
                    ?: MaskPreview(PrivacyScan(option.sentence, contactsOnly = fullText != null).masked)

                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(Radius.lg))
                        .background(if (isOn) theme.tint.copy(alpha = 0.14f) else YColor.bgSurface.copy(alpha = 0.7f))
                        .border(
                            if (isOn) 1.5.dp else 1.dp,
                            if (isOn) theme.strong else YColor.borderDefault,
                            RoundedCornerShape(Radius.lg),
                        )
                        .noRippleClick { selectedId = option.id }
                        .padding(horizontal = Space.lg, vertical = 14.dp),
                    horizontalArrangement = Arrangement.spacedBy(Space.md),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    // Radio Circle
                    Box(
                        modifier = Modifier
                            .size(18.dp)
                            .clip(CircleShape)
                            .background(if (isOn) theme.strong else androidx.compose.ui.graphics.Color.Transparent)
                            .border(1.5.dp, if (isOn) theme.strong else YColor.textSecondary, CircleShape),
                        contentAlignment = Alignment.Center,
                    ) {
                        if (isOn) {
                            Box(modifier = Modifier.size(8.dp).background(YColor.textPrimary, CircleShape))
                        }
                    }

                    Column(
                        modifier = Modifier.weight(1f),
                        verticalArrangement = Arrangement.spacedBy(Space.xs),
                    ) {
                        if (option.caption != null) {
                            Text(option.caption, style = YText.caption, color = YColor.textSecondary)
                        }
                        Text("“${preview.masked}”", style = YText.bodyM, color = YColor.textPrimary)
                        if (isOn && preview.note != null) {
                            Text(preview.note ?: "", style = YText.labelS, color = theme.tint)
                        }
                    }
                }
            }

            if (fullText != null) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(Radius.lg))
                        .background(YColor.bgSurface.copy(alpha = 0.7f))
                        .border(1.dp, YColor.borderDefault, RoundedCornerShape(Radius.lg))
                        .padding(horizontal = Space.lg, vertical = 14.dp),
                    verticalArrangement = Arrangement.spacedBy(Space.xs),
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .noRippleClick { showFullText = !showFullText },
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text("글 전체 미리 보기", style = YText.labelM, color = YColor.textSecondary)
                        Text(if (showFullText) "▲" else "▼", style = YText.caption, color = YColor.textTertiary)
                    }
                    AnimatedVisibility(visible = showFullText) {
                        Column(
                            modifier = Modifier.padding(top = Space.sm),
                            verticalArrangement = Arrangement.spacedBy(Space.xs),
                        ) {
                            val maskedTitle = PrivacyScan(fullText.first, contactsOnly = true).masked
                            val maskedBody = PrivacyScan(fullText.second, contactsOnly = true).masked
                            Text(maskedTitle, style = YText.labelM, color = YColor.textPrimary)
                            Text(maskedBody, style = YText.bodyM, color = YColor.textSecondary)
                        }
                    }
                }
            }
        }

        Column(verticalArrangement = Arrangement.spacedBy(Space.md)) {
            PrimaryButton(
                text = actionTitle,
                enabled = selectedId != null,
                onClick = {
                    val s = options.firstOrNull { it.id == selectedId }
                    if (s != null) onPick(s.sentence)
                },
            )
            GhostButton(text = "취소", onClick = onCancel)
        }
    }
}

// MARK: - 20 Privacy Check Screen

@Composable
fun PrivacyCheckScreen(
    star: StarItem,
    onConfirm: () -> Unit,
    onBack: () -> Unit,
) {
    val scan = remember(star.body) { PrivacyScan(star.body) }

    Box(Modifier.fillMaxSize()) {
        StarField()
        Column(Modifier.fillMaxSize().safeDrawingPadding()) {
            TopAppBar(title = "공유 전 확인", onBack = onBack)

            Column(
                modifier = Modifier
                    .weight(1f)
                    .padding(horizontal = Space.xl, vertical = Space.sm),
                verticalArrangement = Arrangement.spacedBy(Space.lg),
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(Space.sm)) {
                    Text("이름이나 장소가 있나요?", style = YText.h1, color = YColor.textPrimary)
                    Text("글 속 개인정보를 가려 두었어요. 확인하고 나눌 수 있어요.", style = YText.bodyM, color = YColor.textSecondary)
                }

                NoticeBanner(message = "이름, 연락처, 장소는 자동으로 가려져요.")

                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(Radius.lg))
                        .background(YColor.bgSurface)
                        .border(1.dp, YColor.borderDefault, RoundedCornerShape(Radius.lg))
                        .padding(Space.lg),
                    verticalArrangement = Arrangement.spacedBy(Space.xs),
                ) {
                    if (scan.total > 0) {
                        Text("가려진 항목 ${scan.total}개", style = YText.labelM, color = YColor.textPrimary)
                        Text(scan.summary, style = YText.bodyS, color = YColor.textSecondary)
                    } else {
                        Text("가려진 항목이 없어요", style = YText.labelM, color = YColor.textPrimary)
                        Text("그대로 나눠도 괜찮아 보여요.", style = YText.bodyS, color = YColor.textSecondary)
                    }
                }

                Spacer(Modifier.weight(1f))

                Column(verticalArrangement = Arrangement.spacedBy(Space.md)) {
                    PrimaryButton(text = "확인했어요", onClick = onConfirm)
                    GhostButton(text = "취소", onClick = onBack)
                }
            }
        }
    }
}

// MARK: - 17/18 나눈 별 목록

@Composable
fun SharedStarsScreen(
    model: AppModel,
    onBack: () -> Unit,
    onOpenStar: (StarItem) -> Unit,
    onPlaza: () -> Unit,
) {
    val scope = rememberCoroutineScope()
    var liveShares by remember { mutableStateOf<List<MyShareStarItem>>(emptyList()) }
    var loaded by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        liveShares = model.loadSharedStars()
        loaded = true
    }

    val sharedStars: List<StarItem> = remember(liveShares, model.stars) {
        if (liveShares.isNotEmpty()) {
            liveShares.mapNotNull { s ->
                model.stars.firstOrNull { it.id == s.starId } ?: StarItem(
                    id = s.starId,
                    title = s.title,
                    dateText = s.writtenAt ?: "",
                    floated = true,
                    starlight = s.starlight,
                    shared = true,
                )
            }
        } else {
            model.stars.filter { it.isShared }
        }
    }

    Box(Modifier.fillMaxSize()) {
        StarField()
        Column(Modifier.fillMaxSize().safeDrawingPadding()) {
            TopAppBar(title = "나눈 별", onBack = onBack)

            if (sharedStars.isEmpty() && loaded) {
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(horizontal = Space.xl, vertical = Space.xxxl),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center,
                ) {
                    Text("아직 나눈 별이 없어요", style = YText.h2, color = YColor.textPrimary)
                    Spacer(Modifier.height(Space.sm))
                    Text(
                        "띄운 별을 열어 ‘우주 광장에 나누기’를 누르면\n여기에 모여요.",
                        style = YText.bodyM,
                        color = YColor.textSecondary,
                        textAlign = androidx.compose.ui.text.style.TextAlign.Center,
                    )
                    Spacer(Modifier.height(Space.xl))
                    SecondaryButton(text = "우주 광장 둘러보기", onClick = onPlaza)
                }
            } else {
                LazyColumn(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(horizontal = Space.xl),
                    verticalArrangement = Arrangement.spacedBy(Space.md),
                ) {
                    item {
                        Text(
                            "우주 광장에 나눈 별 ${sharedStars.size}개예요. 거두면 광장에서 바로 사라지고, 받은 공명과 별빛 한 줄은 그대로 간직돼요.",
                            style = YText.bodyM,
                            color = YColor.textSecondary,
                        )
                    }
                    items(sharedStars, key = { it.id }) { star ->
                        Column(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalAlignment = Alignment.End,
                        ) {
                            Box(modifier = Modifier.fillMaxWidth().noRippleClick { onOpenStar(star) }) {
                                StarRow(star = star)
                            }
                            Text(
                                text = "광장에서 거두기",
                                style = YText.labelS,
                                color = YColor.textSecondary,
                                modifier = Modifier
                                    .noRippleClick {
                                        scope.launch {
                                            model.unshareStarLive(star.id)
                                            liveShares = liveShares.filter { it.starId != star.id }
                                            model.message = "광장에서 거뒀어요. 언제든 다시 나눌 수 있어요."
                                        }
                                    }
                                    .padding(vertical = Space.xs, horizontal = Space.xs),
                            )
                        }
                    }
                }
            }
        }
    }
}
