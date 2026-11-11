package com.dycdyp.youniya.ui.screens

import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
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
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextAlign
import com.dycdyp.youniya.data.AppModel
import com.dycdyp.youniya.data.Mood
import com.dycdyp.youniya.ui.components.FlowTopBar
import com.dycdyp.youniya.ui.components.MoodChip
import com.dycdyp.youniya.ui.components.NoticeBanner
import com.dycdyp.youniya.ui.components.PrimaryButton
import com.dycdyp.youniya.ui.design.StarField
import com.dycdyp.youniya.ui.theme.Space
import com.dycdyp.youniya.ui.theme.YColor
import com.dycdyp.youniya.ui.theme.YText
import com.dycdyp.youniya.ui.theme.sky
import kotlinx.coroutines.launch

/**
 * 글 수정 (iOS StarEditView):
 * A star without starlight changes mood, title and body.
 * A star with starlight is locked: only its title changes.
 */
@Composable
fun StarEditScreen(
    model: AppModel,
    starId: String,
    onClose: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val star = model.stars.firstOrNull { it.id == starId }
    val floated = star?.isFloated ?: false

    var mood by remember(star) { mutableStateOf(star?.mood ?: Mood.calm) }
    var title by remember(star) { mutableStateOf(star?.title ?: "") }
    var text by remember(star) { mutableStateOf(star?.body ?: "") }
    var saving by remember { mutableStateOf(false) }
    var showCrisis by remember { mutableStateOf(false) }

    val scope = rememberCoroutineScope()
    val titleFocus = remember { FocusRequester() }
    val bodyFocus = remember { FocusRequester() }

    val canSave = text.trim().isNotEmpty() && !saving

    BackHandler(enabled = true) {
        if (!saving) onClose()
    }

    if (showCrisis) {
        CrisisCareView(onContinue = onClose)
        return
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
                .navigationBarsPadding()
                .imePadding()
                .padding(horizontal = Space.xl)
                .padding(top = Space.sm, bottom = Space.xl),
            verticalArrangement = Arrangement.spacedBy(Space.lg),
        ) {
            FlowTopBar(title = "글 수정", onClose = onClose)

            if (floated) {
                NoticeBanner(message = "별빛을 받은 글은 잠겨 있어 제목만 고칠 수 있어요. 글을 고치려면 '고쳐 쓰기'로 새 별을 만들어 주세요.")
            }

            // Mood chips
            Row(
                Modifier.horizontalScroll(rememberScrollState()),
                horizontalArrangement = Arrangement.spacedBy(Space.sm),
            ) {
                Mood.entries.forEach { m ->
                    val isSelected = mood == m
                    val chipAlpha = if (floated && !isSelected) 0.4f else 1f
                    Box(Modifier.alpha(chipAlpha)) {
                        MoodChip(
                            mood = m,
                            isSelected = isSelected,
                            onClick = { if (!floated) mood = m },
                        )
                    }
                }
            }

            // Title
            Box(Modifier.fillMaxWidth()) {
                if (title.isEmpty()) {
                    Text(
                        "제목을 붙여주세요",
                        style = YText.h2,
                        color = YColor.textTertiary,
                    )
                }
                BasicTextField(
                    value = title,
                    onValueChange = { title = it },
                    modifier = Modifier.semantics { contentDescription = "제목을 붙여주세요" }
                        .fillMaxWidth()
                        .focusRequester(titleFocus),
                    textStyle = YText.h2.copy(color = YColor.textPrimary),
                    cursorBrush = SolidColor(sky().borderFocus),
                    keyboardOptions = KeyboardOptions(imeAction = if (floated) ImeAction.Done else ImeAction.Next),
                    keyboardActions = KeyboardActions(onNext = { bodyFocus.requestFocus() }),
                    singleLine = false,
                )
            }

            // Body
            if (floated) {
                Box(
                    Modifier
                        .fillMaxWidth()
                        .weight(1f)
                        .verticalScroll(rememberScrollState()),
                ) {
                    Text(
                        text = text,
                        style = YText.journalBody,
                        color = YColor.textTertiary,
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
            } else {
                Box(Modifier.fillMaxWidth().weight(1f)) {
                    if (text.isEmpty()) {
                        Text(
                            "마음에 머무는 이야기를 적어주세요.",
                            style = YText.journalBody,
                            color = YColor.textTertiary,
                        )
                    }
                    BasicTextField(
                        value = text,
                        onValueChange = { text = it },
                        modifier = Modifier.semantics { contentDescription = "마음에 머무는 이야기를 적어주세요." }
                            .fillMaxSize()
                            .focusRequester(bodyFocus),
                        textStyle = YText.journalBody.copy(color = YColor.textSecondary),
                        cursorBrush = SolidColor(sky().borderFocus),
                    )
                }
            }

            // Character count
            Text(
                text = "${text.length}자",
                style = YText.caption,
                color = YColor.textTertiary,
                modifier = Modifier.fillMaxWidth(),
                textAlign = TextAlign.End,
            )

            // Save button
            PrimaryButton(
                text = "저장",
                enabled = canSave,
                onClick = {
                    saving = true
                    scope.launch {
                        val crisis = model.editStar(
                            id = starId,
                            mood = if (floated) null else mood,
                            title = title,
                            body = if (floated) null else text,
                        )
                        saving = false
                        if (crisis == true) {
                            showCrisis = true
                        } else if (crisis != null) {
                            onClose()
                        }
                    }
                },
            )
        }
    }
}
