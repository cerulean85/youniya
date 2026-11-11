package com.dycdyp.youniya.ui.screens

import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.dycdyp.youniya.data.AppModel
import com.dycdyp.youniya.data.StarItem
import com.dycdyp.youniya.ui.components.NoticeBanner
import com.dycdyp.youniya.ui.components.PrimaryButton
import com.dycdyp.youniya.ui.components.SecondaryButton
import com.dycdyp.youniya.ui.components.TopAppBar
import com.dycdyp.youniya.ui.design.StarField
import com.dycdyp.youniya.ui.design.cosmos
import com.dycdyp.youniya.ui.theme.Radius
import com.dycdyp.youniya.ui.theme.Space
import com.dycdyp.youniya.ui.theme.YColor
import com.dycdyp.youniya.ui.theme.YText
import com.dycdyp.youniya.ui.theme.sky

/**
 * 14 Rewrite (iOS RewriteView):
 * write again on a previous star's question.
 */
@Composable
fun RewriteScreen(
    model: AppModel,
    previous: StarItem,
    question: String?,
    onBack: () -> Unit,
    onPublish: (String, Boolean) -> Unit,
    modifier: Modifier = Modifier,
) {
    var text by remember { mutableStateOf("") }
    val focusRequester = remember { FocusRequester() }
    val canPublish = text.trim().isNotEmpty()
    val canFloat = text.length >= AppModel.minFloatLength

    BackHandler(enabled = true, onBack = onBack)

    LaunchedEffect(Unit) {
        focusRequester.requestFocus()
    }

    val cardShape = RoundedCornerShape(Radius.lg)

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
                .imePadding(),
        ) {
            TopAppBar(title = "별 잇기 · 새 별 쓰기", onBack = onBack)

            Column(
                Modifier
                    .fillMaxSize()
                    .padding(horizontal = Space.xl)
                    .padding(top = Space.sm, bottom = Space.xl),
                verticalArrangement = Arrangement.spacedBy(Space.lg),
            ) {
                // Previous question card
                if (!question.isNullOrBlank()) {
                    Column(
                        Modifier
                            .fillMaxWidth()
                            .cosmos("rewrite-q-${previous.id}", cardShape)
                            .background(YColor.bgSurface, cardShape)
                            .border(1.dp, YColor.borderDefault, cardShape)
                            .padding(Space.lg),
                        verticalArrangement = Arrangement.spacedBy(Space.sm),
                    ) {
                        Text(
                            text = "이어 쓰는 글 · ${previous.title}",
                            style = YText.caption,
                            color = YColor.textTertiary,
                        )
                        Text(
                            text = question,
                            style = YText.observation,
                            color = YColor.textPrimary,
                        )
                    }
                }

                // Editor box
                Box(
                    Modifier
                        .fillMaxWidth()
                        .heightIn(min = 120.dp, max = 260.dp)
                        .cosmos("rewrite-editor", cardShape)
                        .background(YColor.bgSurface, cardShape)
                        .border(1.dp, YColor.borderDefault, cardShape)
                        .padding(Space.lg),
                ) {
                    if (text.isEmpty()) {
                        Text(
                            text = "이번에는 어떤 마음이 떠오르나요?",
                            style = YText.journalBody,
                            color = YColor.textTertiary,
                        )
                    }
                    BasicTextField(
                        value = text,
                        onValueChange = { text = it },
                        modifier = Modifier.semantics { contentDescription = "이번에는 어떤 마음이 떠오르나요?" }
                            .fillMaxSize()
                            .focusRequester(focusRequester),
                        textStyle = YText.journalBody.copy(color = YColor.textSecondary),
                        cursorBrush = SolidColor(sky().borderFocus),
                    )
                }

                // Character count
                val countText = if (canFloat) {
                    "${text.length}자"
                } else {
                    "${text.length}자 · ${AppModel.minFloatLength - text.length}자 더 쓰면 별빛을 받을 수 있어요"
                }
                Text(
                    text = countText,
                    style = YText.caption,
                    color = YColor.textTertiary,
                    modifier = Modifier.fillMaxWidth(),
                    textAlign = TextAlign.End,
                )

                if (canPublish && !canFloat) {
                    NoticeBanner(message = "짧은 글은 '별빛 없이 띄우기'로 띄울 수 있어요")
                }

                Spacer(Modifier.weight(1f))

                Row(
                    Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(Space.md),
                ) {
                    SecondaryButton(
                        text = "별빛 없이 띄우기",
                        modifier = Modifier.weight(1f),
                        enabled = canPublish,
                        onClick = { onPublish(text, false) },
                    )
                    PrimaryButton(
                        text = model.floatButtonTitle,
                        modifier = Modifier.weight(1f),
                        enabled = canFloat,
                        onClick = { onPublish(text, true) },
                    )
                }
            }
        }
    }
}
