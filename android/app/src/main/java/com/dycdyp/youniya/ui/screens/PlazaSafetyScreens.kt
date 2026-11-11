package com.dycdyp.youniya.ui.screens

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp
import com.dycdyp.youniya.R
import com.dycdyp.youniya.ui.components.ActionSheetContent
import com.dycdyp.youniya.ui.components.CheckboxRow
import com.dycdyp.youniya.ui.components.DangerButton
import com.dycdyp.youniya.ui.components.GhostButton
import com.dycdyp.youniya.ui.components.PrimaryButton
import com.dycdyp.youniya.ui.components.SecondaryButton
import com.dycdyp.youniya.ui.components.SheetGrabber
import com.dycdyp.youniya.ui.components.noRippleClick
import com.dycdyp.youniya.ui.design.cosmos
import com.dycdyp.youniya.ui.theme.Radius
import com.dycdyp.youniya.ui.theme.Space
import com.dycdyp.youniya.ui.theme.YColor
import com.dycdyp.youniya.ui.theme.YText

// MARK: - 09-6 Operator Gold Banner

@Composable
fun OperatorBanner(
    title: String,
    message: String,
    link: String = "자세히",
    onClick: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(Radius.lg))
            .background(YColor.tintGold.copy(alpha = 0.6f))
            .border(1.dp, YColor.starBright.copy(alpha = 0.55f), RoundedCornerShape(Radius.lg))
            .noRippleClick(onClick)
            .padding(Space.lg),
        verticalArrangement = Arrangement.spacedBy(Space.xs),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(text = title, style = YText.labelM, color = YColor.starBright)
            Text(text = "$link ›", style = YText.labelS, color = YColor.starBright)
        }
        Text(text = message, style = YText.caption, color = YColor.textSecondary)
    }
}

// MARK: - 09-7 Plaza Restricted Sheet

@Composable
fun PlazaRestrictedSheetContent(
    restrictedText: String,
    onDismiss: () -> Unit,
    onInquiry: () -> Unit,
) {
    ActionSheetContent(
        title = "광장 이용이 잠시 멈춰 있어요",
        message = "${restrictedText}까지 별을 나누거나 공명·곁에 두기·별빛 한 줄을 남길 수 없어요. 신고가 확인되어 운영자가 정한 조치예요.\n내 기록과 별은 그대로이고, 광장의 다른 별은 계속 읽을 수 있어요.",
        primaryText = "확인",
        onPrimary = onDismiss,
        secondaryText = "문의하기",
        onSecondary = {
            onDismiss()
            onInquiry()
        },
    )
}

// MARK: - 75-2 Block Confirm Sheet

@Composable
fun BlockConfirmSheet(
    onBlock: () -> Unit,
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
            Text("이 별지기를 차단할까요?", style = YText.h3, color = YColor.textPrimary)
            Text(
                "차단하면 이 사람의 별과 별빛 한 줄이 내 화면에 더 이상 보이지 않아요. 상대에게는 알리지 않고, 설정 › 차단한 별지기에서 언제든 풀 수 있어요.",
                style = YText.bodyM,
                color = YColor.textSecondary,
            )
        }
        Column(verticalArrangement = Arrangement.spacedBy(Space.md)) {
            DangerButton(text = "차단하기", onClick = onBlock)
            GhostButton(text = "취소", onClick = onCancel)
        }
    }
}

// MARK: - Plaza Top App Bar with Optional More Button

@Composable
fun PlazaTopAppBar(
    title: String,
    onBack: () -> Unit,
    onMore: (() -> Unit)? = null,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .height(52.dp)
            .padding(horizontal = Space.md),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier = Modifier
                .size(40.dp)
                .noRippleClick(onBack),
            contentAlignment = Alignment.Center,
        ) {
            androidx.compose.foundation.Image(
                painter = painterResource(R.drawable.icon_back),
                contentDescription = "뒤로",
                modifier = Modifier.size(24.dp),
            )
        }
        Text(
            text = title,
            style = YText.labelM,
            color = YColor.textPrimary,
            textAlign = androidx.compose.ui.text.style.TextAlign.Center,
            modifier = Modifier.weight(1f),
        )
        if (onMore != null) {
            PlazaMoreButton(onClick = onMore)
        } else {
            Spacer(Modifier.size(40.dp))
        }
    }
}

@Composable
fun PlazaMoreButton(onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .size(44.dp)
            .clip(CircleShape)
            .background(YColor.bgSurface.copy(alpha = 0.8f))
            .border(1.dp, YColor.borderDefault, CircleShape)
            .noRippleClick(onClick),
        contentAlignment = Alignment.Center,
    ) {
        Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            repeat(3) {
                Box(
                    modifier = Modifier
                        .size(4.dp)
                        .background(YColor.textPrimary, CircleShape)
                )
            }
        }
    }
}

@Composable
fun PlazaMoreMenuPopup(
    visible: Boolean,
    onDismiss: () -> Unit,
    onReport: () -> Unit,
    onBlock: () -> Unit,
) {
    AnimatedVisibility(
        visible = visible,
        enter = fadeIn(),
        exit = fadeOut(),
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .noRippleClick(onDismiss),
        ) {
            Column(
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .padding(end = Space.xl, top = 56.dp)
                    .width(220.dp)
                    .clip(RoundedCornerShape(Radius.xl))
                    .cosmos("more-menu")
                    .background(YColor.bgSurfaceRaised)
                    .border(1.dp, YColor.borderDefault, RoundedCornerShape(Radius.xl))
                    .padding(Space.sm),
                verticalArrangement = Arrangement.spacedBy(2.dp),
            ) {
                // 이 별 신고하기
                val a = com.dycdyp.youniya.ui.theme.sky()
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(Radius.md))
                        .noRippleClick {
                            onDismiss()
                            onReport()
                        }
                        .padding(horizontal = Space.md, vertical = 10.dp),
                    horizontalArrangement = Arrangement.spacedBy(Space.md),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Box(
                        modifier = Modifier
                            .size(36.dp)
                            .clip(RoundedCornerShape(Radius.md))
                            .background(a.tint.copy(alpha = 0.16f)),
                        contentAlignment = Alignment.Center,
                    ) {
                        androidx.compose.foundation.Image(
                            painter = painterResource(R.drawable.icon_warning),
                            contentDescription = null,
                            modifier = Modifier.size(20.dp),
                        )
                    }
                    Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                        Text("이 별 신고하기", style = YText.labelM, color = YColor.textPrimary)
                        Text("운영팀이 살펴봐요", style = YText.caption, color = YColor.textTertiary)
                    }
                }

                // 이 별지기 차단하기
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(Radius.md))
                        .noRippleClick {
                            onDismiss()
                            onBlock()
                        }
                        .padding(horizontal = Space.md, vertical = 10.dp),
                    horizontalArrangement = Arrangement.spacedBy(Space.md),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Box(
                        modifier = Modifier
                            .size(36.dp)
                            .clip(RoundedCornerShape(Radius.md))
                            .background(YColor.brandWarm.copy(alpha = 0.16f)),
                        contentAlignment = Alignment.Center,
                    ) {
                        Text("✕", style = YText.labelM, color = YColor.brandWarm)
                    }
                    Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                        Text("이 별지기 차단하기", style = YText.labelM, color = YColor.brandWarm)
                        Text("이 사람의 글이 더 보이지 않아요", style = YText.caption, color = YColor.textTertiary)
                    }
                }
            }
        }
    }
}

// MARK: - 100 Report Sheet

@Composable
fun ReportSheetContent(
    title: String = "이 별을 신고할까요?",
    message: String = "신고한 별은 운영팀이 살펴봐요. 누가 신고했는지는 알리지 않아요.",
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
    var alsoBlock by remember { mutableStateOf(false) }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = Space.xl, vertical = Space.lg),
        verticalArrangement = Arrangement.spacedBy(Space.lg),
    ) {
        SheetGrabber()
        Column(verticalArrangement = Arrangement.spacedBy(Space.sm)) {
            Text(title, style = YText.h3, color = YColor.textPrimary)
            Text(message, style = YText.bodyM, color = YColor.textSecondary)
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
                checked = alsoBlock,
                onToggle = { alsoBlock = !alsoBlock },
            )
        }
        Column(verticalArrangement = Arrangement.spacedBy(Space.md)) {
            PrimaryButton("신고하기") {
                onReport(selectedReason, alsoBlock)
            }
            SecondaryButton("취소", onClick = onCancel)
        }
    }
}
