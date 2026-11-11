package com.dycdyp.youniya.ui.screens

import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
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
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.CircularProgressIndicator
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.dycdyp.youniya.data.AppModel
import com.dycdyp.youniya.data.LineSendResult
import com.dycdyp.youniya.data.PlazaNebula
import com.dycdyp.youniya.data.ReceivedLine
import com.dycdyp.youniya.data.StarItem
import com.dycdyp.youniya.data.formatPlazaWhen
import com.dycdyp.youniya.ui.components.CheckboxRow
import com.dycdyp.youniya.ui.components.NoticeBanner
import com.dycdyp.youniya.ui.components.PrimaryButton
import com.dycdyp.youniya.ui.components.SecondaryButton
import com.dycdyp.youniya.ui.components.SheetGrabber
import com.dycdyp.youniya.ui.components.TopAppBar
import com.dycdyp.youniya.ui.components.noRippleClick
import com.dycdyp.youniya.ui.design.StarField
import com.dycdyp.youniya.ui.theme.Radius
import com.dycdyp.youniya.ui.theme.Space
import com.dycdyp.youniya.ui.theme.YColor
import com.dycdyp.youniya.ui.theme.YText
import com.dycdyp.youniya.ui.theme.sky
import kotlinx.coroutines.launch

// MARK: - 74 별빛 한 줄 건네기

@Composable
fun StarLineComposeScreen(
    model: AppModel,
    star: PlazaNebula,
    onBack: () -> Unit,
) {
    val scope = rememberCoroutineScope()
    var draft by remember { mutableStateOf("") }
    var problem by remember { mutableStateOf<String?>(null) }
    var sending by remember { mutableStateOf(false) }

    val sent = model.sentStarLines[star.name] ?: if (star.lineLeft) "" else null
    val over = draft.length > 60
    val canSend = draft.isNotBlank() && !over && !sending
    val theme = sky()

    val chips = listOf(
        "empathize" to "공감해요",
        "me_too" to "저도 그랬어요",
        "thanks" to "고마워요",
    )

    fun sendLine(chip: String?) {
        sending = true
        scope.launch {
            val textToSend = if (chip == null) draft.trim() else null
            val res = model.sendStarLine(star, textToSend, chip)
            sending = false
            when (res) {
                is LineSendResult.Sent -> {
                    draft = ""
                    model.message = "별빛 한 줄을 건넸어요. 별 주인만 읽을 수 있어요."
                }
                is LineSendResult.Rejected -> problem = res.why
                is LineSendResult.Already -> {
                    problem = null
                    model.message = "이 별에는 이미 한 줄을 건넸어요."
                }
                is LineSendResult.Closed -> model.message = "이 별은 지금 별빛 한 줄을 받지 않아요."
            }
        }
    }

    Box(Modifier.fillMaxSize()) {
        StarField()
        Column(Modifier.fillMaxSize().safeDrawingPadding()) {
            val starTitle = star.starTitle ?: star.name
            TopAppBar(title = "별빛 한 줄 · 「$starTitle」", onBack = onBack)

            Column(
                modifier = Modifier
                    .weight(1f)
                    .padding(horizontal = Space.xl, vertical = Space.sm),
                verticalArrangement = Arrangement.spacedBy(Space.lg),
            ) {
                Text(
                    text = "한 사람이 한 별에 한 줄씩 건넬 수 있어요. 별 주인만 읽을 수 있어요.",
                    style = YText.caption,
                    color = YColor.textTertiary,
                    modifier = Modifier.fillMaxWidth(),
                    textAlign = TextAlign.Center,
                )

                if (!sent.isNullOrEmpty()) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(Radius.lg))
                            .background(YColor.bgSurface)
                            .border(1.dp, YColor.borderDefault, RoundedCornerShape(Radius.lg))
                            .padding(Space.lg),
                        verticalArrangement = Arrangement.spacedBy(Space.xs),
                    ) {
                        Text("내가 건넨 한 줄", style = YText.caption, color = YColor.textTertiary)
                        Text(sent, style = YText.bodyM, color = YColor.textPrimary)
                    }
                }

                Spacer(Modifier.weight(1f))

                // Bottom Composer Section
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .imePadding(),
                    verticalArrangement = Arrangement.spacedBy(Space.md),
                ) {
                    when {
                        !star.receiveLines -> {
                            NoticeBanner("이 별은 지금 별빛 한 줄을 받지 않아요")
                        }
                        sent != null -> {
                            NoticeBanner("이 별에는 이미 한 줄을 건넸어요")
                        }
                        else -> {
                            if (problem != null) {
                                NoticeBanner(message = problem ?: "", warm = true)
                            } else if (over) {
                                NoticeBanner(message = "${draft.length} / 60자 · 60자 안으로 줄여 주세요", warm = true)
                            } else {
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.spacedBy(Space.sm),
                                ) {
                                    chips.forEach { (key, label) ->
                                        Box(
                                            modifier = Modifier
                                                .clip(CircleShape)
                                                .background(YColor.bgSurfaceRaised)
                                                .border(1.dp, YColor.borderDefault, CircleShape)
                                                .noRippleClick { sendLine(key) }
                                                .padding(horizontal = 14.dp, vertical = 8.dp),
                                        ) {
                                            Text(label, style = YText.labelS, color = YColor.textPrimary)
                                        }
                                    }
                                }
                            }

                            // Composer input box
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clip(RoundedCornerShape(Radius.lg))
                                    .background(YColor.bgSurface)
                                    .border(1.dp, theme.borderFocus.copy(alpha = 0.6f), RoundedCornerShape(Radius.lg))
                                    .padding(start = Space.lg, end = Space.sm, top = Space.sm, bottom = Space.sm),
                                verticalAlignment = Alignment.CenterVertically,
                            ) {
                                Box(modifier = Modifier.weight(1f)) {
                                    if (draft.isEmpty()) {
                                        Text(
                                            "한 줄을 남겨 보세요 (60자)",
                                            style = YText.bodyM,
                                            color = YColor.textTertiary,
                                        )
                                    }
                                    BasicTextField(
                                        value = draft,
                                        onValueChange = {
                                            draft = it
                                            if (problem != null) problem = null
                                        },
                                        modifier = Modifier.semantics { contentDescription = "한 줄을 남겨 보세요 (60자)" }.fillMaxWidth(),
                                        textStyle = YText.bodyM.copy(color = YColor.textPrimary),
                                        cursorBrush = SolidColor(theme.borderFocus),
                                        keyboardOptions = KeyboardOptions(imeAction = ImeAction.Send),
                                        keyboardActions = KeyboardActions(onSend = { if (canSend) sendLine(null) }),
                                    )
                                }
                                Box(
                                    modifier = Modifier
                                        .size(32.dp)
                                        .clip(CircleShape)
                                        .background(if (canSend) theme.strong else YColor.textTertiary.copy(alpha = 0.4f))
                                        .noRippleClick { if (canSend) sendLine(null) },
                                    contentAlignment = Alignment.Center,
                                ) {
                                    Text("↑", style = YText.labelM, color = YColor.textPrimary)
                                }
                            }

                            Text(
                                text = "상처 주는 말은 별빛이 되지 못해요 · 보내기 전에 한 번 걸러요",
                                style = YText.caption,
                                color = YColor.textTertiary,
                            )
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 12-4 받은 별빛 한 줄

@Composable
fun ReceivedLinesScreen(
    model: AppModel,
    starId: String,
    onBack: () -> Unit,
) {
    val scope = rememberCoroutineScope()
    var lines by remember { mutableStateOf<List<ReceivedLine>?>(null) }
    var reportingLine by remember { mutableStateOf<ReceivedLine?>(null) }

    val star = model.stars.firstOrNull { it.id == starId }

    LaunchedEffect(starId) {
        lines = model.receivedLines(starId)
    }

    Box(Modifier.fillMaxSize()) {
        StarField()
        Column(Modifier.fillMaxSize().safeDrawingPadding()) {
            TopAppBar(title = "받은 별빛 한 줄 · 「${star?.title ?: ""}」", onBack = onBack)

            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(horizontal = Space.xl, vertical = Space.sm),
                verticalArrangement = Arrangement.spacedBy(Space.md),
            ) {
                item {
                    Text(
                        text = "이 별에 건네진 한 줄이에요. 나만 읽을 수 있고, 지우거나 신고할 수 있어요.",
                        style = YText.caption,
                        color = YColor.textTertiary,
                        modifier = Modifier.fillMaxWidth(),
                        textAlign = TextAlign.Center,
                    )
                }

                val currentLines = lines
                if (currentLines == null) {
                    item {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(160.dp),
                            contentAlignment = Alignment.Center,
                        ) {
                            CircularProgressIndicator(color = YColor.textPrimary)
                        }
                    }
                } else if (currentLines.isEmpty()) {
                    item {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(160.dp),
                            contentAlignment = Alignment.Center,
                        ) {
                            Text("아직 받은 한 줄이 없어요.", style = YText.bodyM, color = YColor.textTertiary)
                        }
                    }
                } else {
                    items(currentLines, key = { it.id }) { line ->
                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clip(RoundedCornerShape(Radius.lg))
                                .background(YColor.bgSurface)
                                .border(1.dp, YColor.borderDefault, RoundedCornerShape(Radius.lg))
                                .padding(Space.lg),
                            verticalArrangement = Arrangement.spacedBy(Space.sm),
                        ) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically,
                            ) {
                                Text(
                                    "${line.nickname ?: "별지기"} · ${formatPlazaWhen(line.createdAt)}",
                                    style = YText.caption,
                                    color = YColor.textTertiary,
                                )
                                Row(horizontalArrangement = Arrangement.spacedBy(Space.sm)) {
                                    Text(
                                        text = "지우기",
                                        style = YText.labelS,
                                        color = YColor.brandWarm,
                                        modifier = Modifier.noRippleClick {
                                            scope.launch {
                                                if (model.deleteLine(starId, line.id)) {
                                                    lines = lines?.filter { it.id != line.id }
                                                }
                                            }
                                        },
                                    )
                                    Text(
                                        text = "신고",
                                        style = YText.labelS,
                                        color = YColor.textSecondary,
                                        modifier = Modifier.noRippleClick { reportingLine = line },
                                    )
                                }
                            }
                            Text(line.text, style = YText.bodyM, color = YColor.textPrimary)
                        }
                    }
                }
            }
        }

        // 100 신고 시트
        val rep = reportingLine
        if (rep != null) {
            YouniyaSheet("line-report", onDismiss = { reportingLine = null }) {
                LineReportSheet(
                    onReport = { reason, block ->
                        reportingLine = null
                        scope.launch {
                            if (model.reportLine(starId, rep.id, reason, block)) {
                                lines = lines?.filter { it.id != rep.id }
                                model.message = if (block) "신고했어요. 그 별지기도 차단했어요." else "신고했어요. 바로 가려졌어요."
                            }
                        }
                    },
                    onCancel = { reportingLine = null },
                )
            }
        }
    }
}

// MARK: - 100 이 별빛을 신고할까요?

@Composable
fun LineReportSheet(
    onReport: (reason: String, block: Boolean) -> Unit,
    onCancel: () -> Unit,
) {
    val reasons = listOf(
        "hurtful" to "상처를 주는 말이에요",
        "personal_info" to "개인정보가 드러나 있어요",
        "spam" to "광고나 스팸이에요",
        "other" to "그 밖의 이유가 있어요",
    )
    var selectedReason by remember { mutableStateOf("hurtful") }
    var block by remember { mutableStateOf(false) }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = Space.xl, vertical = Space.lg),
        verticalArrangement = Arrangement.spacedBy(Space.lg),
    ) {
        SheetGrabber()
        Column(verticalArrangement = Arrangement.spacedBy(Space.sm)) {
            Text("이 별빛을 신고할까요?", style = YText.h3, color = YColor.textPrimary)
            Text(
                "신고한 별빛은 바로 가려지고 운영팀이 살펴봐요. 누가 신고했는지는 알리지 않아요.",
                style = YText.bodyM,
                color = YColor.textSecondary,
            )
        }
        Column(verticalArrangement = Arrangement.spacedBy(Space.xs)) {
            reasons.forEach { (code, label) ->
                CheckboxRow(
                    label = label,
                    checked = selectedReason == code,
                    onToggle = { selectedReason = code },
                )
            }
            Spacer(Modifier.height(Space.sm))
            CheckboxRow(
                label = "이 별지기도 차단하기",
                checked = block,
                onToggle = { block = !block },
            )
        }
        Column(verticalArrangement = Arrangement.spacedBy(Space.md)) {
            PrimaryButton(text = "신고하기", onClick = { onReport(selectedReason, block) })
            SecondaryButton(text = "취소", onClick = onCancel)
        }
    }
}
