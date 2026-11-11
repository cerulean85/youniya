package com.dycdyp.youniya.ui.screens

import androidx.activity.compose.BackHandler
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextAlign
import com.dycdyp.youniya.data.AppModel
import com.dycdyp.youniya.data.Mood
import com.dycdyp.youniya.data.StarDraft
import com.dycdyp.youniya.ui.components.DangerButton
import com.dycdyp.youniya.ui.components.FlowTopBar
import com.dycdyp.youniya.ui.components.MoodChip
import com.dycdyp.youniya.ui.components.NoticeBanner
import com.dycdyp.youniya.ui.components.PrimaryButton
import com.dycdyp.youniya.ui.components.SecondaryButton
import com.dycdyp.youniya.ui.components.SheetGrabber
import com.dycdyp.youniya.ui.design.StarField
import com.dycdyp.youniya.ui.theme.Space
import com.dycdyp.youniya.ui.theme.YColor
import com.dycdyp.youniya.ui.theme.YText
import com.dycdyp.youniya.ui.theme.sky
import kotlinx.coroutines.delay

/**
 * 05 Star Making: write today's story, then float it with starlight or without.
 */
@Composable
fun StarMakingScreen(
    model: AppModel,
    onClose: () -> Unit,
    onPublish: (StarDraft, Boolean) -> Unit,
    revising: com.dycdyp.youniya.data.StarItem? = null,
    onRevise: (StarDraft) -> Unit = {},
    revisePublished: Boolean = false,
) {
    val initialDraft = remember(revising) {
        if (revising != null) {
            model.reviseDrafts[revising.id] ?: StarDraft(
                mood = revising.mood,
                extraMoods = revising.extraMoods,
                title = revising.title,
                body = revising.body,
            )
        } else {
            model.draft
        }
    }
    var draft by remember { mutableStateOf(initialDraft) }
    var isSaved by remember { mutableStateOf(if (revising != null) model.reviseDrafts.containsKey(revising.id) else !model.draft.isEmpty) }
    var didPublish by remember { mutableStateOf(false) }
    var askLeave by remember { mutableStateOf(false) }

    fun save(d: StarDraft) {
        if (revising != null) {
            model.reviseDrafts[revising.id] = d
        } else {
            model.saveDraft(d)
        }
    }

    val titleFocus = remember { FocusRequester() }
    val bodyFocus = remember { FocusRequester() }

    val canPublish = draft.body.trim().isNotEmpty()
    val canFloat = draft.body.length >= AppModel.minFloatLength

    val handleClose = {
        if (draft.isEmpty) {
            onClose()
        } else {
            askLeave = true
        }
    }

    BackHandler(enabled = askLeave) { askLeave = false }
    BackHandler(enabled = !askLeave) { handleClose() }

    // Autosave after 0.8s
    LaunchedEffect(draft) {
        val savedDraft = if (revising != null) model.reviseDrafts[revising.id] ?: StarDraft() else model.draft
        if (draft == savedDraft) {
            isSaved = !draft.isEmpty
            return@LaunchedEffect
        }
        isSaved = false
        delay(800)
        save(draft)
        isSaved = !draft.isEmpty
    }

    DisposableEffect(Unit) {
        onDispose {
            if (!didPublish && !revisePublished) {
                save(draft)
            }
        }
    }

    val savedAlpha by animateFloatAsState(
        targetValue = if (isSaved) 1f else 0f,
        animationSpec = tween(durationMillis = 300),
        label = "savedAlpha",
    )

    Box(
        Modifier
            .fillMaxSize()
            .background(YColor.bgCanvas)
    ) {
        StarField()

        Column(
            Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .navigationBarsPadding()
                .imePadding()
                .padding(horizontal = Space.xl)
                .padding(top = Space.sm, bottom = Space.xl),
            verticalArrangement = Arrangement.spacedBy(Space.lg),
        ) {
            // Top Bar
            FlowTopBar(
                title = if (revising != null) "고쳐 쓰기" else "별 만들기",
                onClose = handleClose,
                trailing = {
                    Text(
                        "임시 저장됨",
                        style = YText.caption,
                        color = YColor.textTertiary,
                        modifier = Modifier.alpha(savedAlpha),
                    )
                },
            )

            if (revising != null) {
                NoticeBanner(message = "「${revising.title}」를 고쳐 쓰고 있어요. 원래 별과 별빛은 그대로 남고, 띄우면 새 별이 되어 원래 별과 이어져요.")
            }

            // Mood Chips
            Column(verticalArrangement = Arrangement.spacedBy(Space.sm)) {
                Row(
                    Modifier.horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(Space.sm),
                ) {
                    Mood.entries.forEach { mood ->
                        MoodChip(
                            mood = mood,
                            isSelected = draft.moods.contains(mood),
                            onClick = { draft = draft.toggle(mood) },
                        )
                    }
                }
                Text(
                    "오늘의 마음을 여러 개 고를 수 있어요 · 처음 고른 마음이 별의 색이 돼요",
                    style = YText.caption,
                    color = YColor.textTertiary,
                )
            }

            // Title input
            Box(Modifier.fillMaxWidth()) {
                if (draft.title.isEmpty()) {
                    Text(
                        "제목을 붙여주세요",
                        style = YText.h2,
                        color = YColor.textTertiary,
                    )
                }
                BasicTextField(
                    value = draft.title,
                    onValueChange = { draft = draft.copy(title = it) },
                    modifier = Modifier.semantics { contentDescription = "제목을 붙여주세요" }
                        .fillMaxWidth()
                        .focusRequester(titleFocus),
                    textStyle = YText.h2.copy(color = YColor.textPrimary),
                    cursorBrush = SolidColor(sky().borderFocus),
                    keyboardOptions = KeyboardOptions(imeAction = ImeAction.Next),
                    keyboardActions = KeyboardActions(onNext = { bodyFocus.requestFocus() }),
                    singleLine = false,
                )
            }

            // Body editor
            Box(Modifier.fillMaxWidth().weight(1f)) {
                if (draft.body.isEmpty()) {
                    Text(
                        "마음에 머무는 이야기를 적어주세요.",
                        style = YText.journalBody,
                        color = YColor.textTertiary,
                    )
                }
                BasicTextField(
                    value = draft.body,
                    onValueChange = { draft = draft.copy(body = it) },
                    modifier = Modifier.semantics { contentDescription = "마음에 머무는 이야기를 적어주세요." }
                        .fillMaxSize()
                        .focusRequester(bodyFocus),
                    textStyle = YText.journalBody.copy(color = YColor.textSecondary),
                    cursorBrush = SolidColor(sky().borderFocus),
                )
            }

            // Character count
            val charCountText = if (canFloat) {
                "${draft.body.length}자"
            } else {
                "${draft.body.length}자 · ${AppModel.minFloatLength - draft.body.length}자 더 쓰면 별빛을 받을 수 있어요"
            }
            Text(
                text = charCountText,
                style = YText.caption,
                color = YColor.textTertiary,
                modifier = Modifier
                    .fillMaxWidth()
                    .semantics { contentDescription = "${draft.body.length}자 작성함" },
                textAlign = TextAlign.End,
            )

            // Short notice banner
            if (canPublish && !canFloat) {
                NoticeBanner(message = "짧은 글은 '별빛 없이 띄우기'로 띄울 수 있어요")
            }

            // Buttons
            if (revising != null) {
                PrimaryButton(
                    text = "새 별로 띄우기",
                    modifier = Modifier.fillMaxWidth(),
                    enabled = canPublish,
                    onClick = {
                        onRevise(draft)
                    },
                )
            } else {
                Row(
                    Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(Space.md),
                ) {
                    SecondaryButton(
                        text = "별빛 없이 띄우기",
                        modifier = Modifier.weight(1f),
                        enabled = canPublish,
                        onClick = {
                            didPublish = true
                            onPublish(draft, false)
                        },
                    )
                    PrimaryButton(
                        text = model.floatButtonTitle,
                        modifier = Modifier.weight(1f),
                        enabled = canFloat,
                        onClick = {
                            onPublish(draft, true)
                        },
                    )
                }
            }
        }

        // 34 Leave Draft Sheet
        if (askLeave) {
            LeaveDraftSheet(
                onSaveAndLeave = {
                    askLeave = false
                    save(draft)
                    onClose()
                },
                onKeepWriting = {
                    askLeave = false
                },
                onDiscard = {
                    askLeave = false
                    didPublish = true
                    draft = StarDraft()
                    if (revising != null) {
                        model.reviseDrafts.remove(revising.id)
                    } else {
                        model.saveDraft(StarDraft())
                    }
                    onClose()
                },
            )
        }
    }
}

/** 34 작성 중 나가기 시트 */
@Composable
private fun LeaveDraftSheet(
    onSaveAndLeave: () -> Unit,
    onKeepWriting: () -> Unit,
    onDiscard: () -> Unit,
) {
    YouniyaSheet("leave-sheet", onDismiss = onKeepWriting) {
        Column(
            Modifier.padding(start = Space.xl, end = Space.xl, top = Space.md, bottom = Space.xl),
            verticalArrangement = Arrangement.spacedBy(Space.lg),
        ) {
            SheetGrabber()
            Column(verticalArrangement = Arrangement.spacedBy(Space.sm)) {
                Text("쓰던 글을 어떻게 할까요?", style = YText.h3, color = YColor.textPrimary)
                Text(
                    "글은 사라지지 않게 임시로 저장해 둘 수 있어요.",
                    style = YText.bodyM,
                    color = YColor.textSecondary,
                )
            }
            Column(verticalArrangement = Arrangement.spacedBy(Space.md)) {
                PrimaryButton("임시 저장하고 나가기", onClick = onSaveAndLeave)
                SecondaryButton("계속 쓰기", onClick = onKeepWriting)
                DangerButton("버리기", onClick = onDiscard)
            }
        }
    }
}
