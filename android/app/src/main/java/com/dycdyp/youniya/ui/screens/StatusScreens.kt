package com.dycdyp.youniya.ui.screens

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.dycdyp.youniya.R
import com.dycdyp.youniya.ui.components.GhostButton
import com.dycdyp.youniya.ui.components.PrimaryButton
import com.dycdyp.youniya.ui.components.SecondaryButton
import com.dycdyp.youniya.ui.design.StarField
import com.dycdyp.youniya.ui.theme.Space
import com.dycdyp.youniya.ui.theme.YColor
import com.dycdyp.youniya.ui.theme.YText
import com.dycdyp.youniya.ui.theme.sky

data class StatusAction(
    val title: String,
    val style: Style,
    val disabled: Boolean = false,
    val run: () -> Unit,
) {
    enum class Style { Primary, Secondary, Ghost }
}

/**
 * Figma status screens (35, 36, iOS StatusView):
 * an orb with an icon, a title, a short note, and actions over the star field.
 */
@Composable
fun StatusView(
    icon: Int,
    title: String,
    message: String,
    actions: List<StatusAction>,
    modifier: Modifier = Modifier,
) {
    Box(modifier.fillMaxSize()) {
        StarField()

        Column(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .navigationBarsPadding()
                .padding(horizontal = Space.xl, vertical = Space.xl),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Spacer(Modifier.weight(1f))

            StatusHero(icon = icon)

            Spacer(Modifier.size(Space.lg))

            Column(
                verticalArrangement = Arrangement.spacedBy(Space.lg),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Text(
                    title,
                    style = YText.h2,
                    color = YColor.textPrimary,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.semantics { heading() },
                )
                Text(
                    message,
                    style = YText.bodyM,
                    color = YColor.textSecondary,
                    textAlign = TextAlign.Center,
                )
            }

            Spacer(Modifier.size(Space.lg))

            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(Space.md),
            ) {
                actions.forEach { action ->
                    when (action.style) {
                        StatusAction.Style.Primary -> PrimaryButton(
                            text = action.title,
                            enabled = !action.disabled,
                            onClick = action.run,
                        )
                        StatusAction.Style.Secondary -> SecondaryButton(
                            text = action.title,
                            enabled = !action.disabled,
                            onClick = action.run,
                        )
                        StatusAction.Style.Ghost -> GhostButton(
                            text = action.title,
                            onClick = action.run,
                        )
                    }
                }
            }

            Spacer(Modifier.weight(1f))
        }
    }
}

/**
 * Figma status `Hero` (120×120, iOS StatusHero):
 * two orbits, a violet orb with a gold icon, two stars.
 */
@Composable
fun StatusHero(
    icon: Int,
    modifier: Modifier = Modifier,
) {
    val a = sky()

    Box(
        modifier = modifier.size(120.dp),
        contentAlignment = Alignment.TopStart,
    ) {
        // Outer orbit
        Box(
            Modifier
                .size(120.dp)
                .alpha(0.3f)
                .border(1.dp, a.brandPrimary, CircleShape),
        )

        // Middle orbit
        Box(
            Modifier
                .offset(x = 14.dp, y = 14.dp)
                .size(92.dp)
                .alpha(0.5f)
                .border(1.dp, a.brandPrimary, CircleShape),
        )

        // Center orb
        Box(
            Modifier
                .offset(x = 28.dp, y = 28.dp)
                .size(64.dp)
                .dropShadow(CircleShape, Shadow(radius = 12.dp, color = a.brandPrimary.copy(alpha = 0.4f)))
                .background(a.tintPrimary, CircleShape)
                .border(1.dp, a.borderFocus, CircleShape),
        )

        // Gold icon in center
        Image(
            painter = painterResource(icon),
            contentDescription = null,
            colorFilter = ColorFilter.tint(YColor.starBright),
            modifier = Modifier
                .offset(x = 45.dp, y = 45.dp)
                .size(30.dp),
        )

        // Star dot 1 (gold)
        Box(
            Modifier
                .offset(x = 97.dp, y = 17.dp)
                .size(6.dp)
                .dropShadow(CircleShape, Shadow(radius = 14.dp, color = YColor.starBright.copy(alpha = 0.5f)))
                .background(YColor.starBright, CircleShape),
        )

        // Star dot 2 (cyan)
        Box(
            Modifier
                .offset(x = 12.dp, y = 94.dp)
                .size(5.dp)
                .dropShadow(CircleShape, Shadow(radius = 10.dp, color = YColor.starClear.copy(alpha = 0.4f)))
                .background(YColor.starClear, CircleShape),
        )
    }
}

/**
 * 122 별을 찾을 수 없어요 (iOS NotFoundView):
 * deleted, or tidied away on another device.
 */
@Composable
fun NotFoundView(
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
) {
    StatusView(
        icon = R.drawable.icon_star,
        title = "별을 찾을 수 없어요",
        message = "이미 지웠거나 다른 기기에서 정리한 별이에요.",
        actions = listOf(
            StatusAction(
                title = "오늘로 돌아가기",
                style = StatusAction.Style.Primary,
                run = onBack,
            ),
        ),
        modifier = modifier,
    )
}

// MARK: - 39–41 App notices

sealed interface AppNotice {
    data object LoginExpired : AppNotice // 39
    data object UpdateRequired : AppNotice // 40
    data class Maintenance(val window: String) : AppNotice // 41
    data object AccountDeleted : AppNotice // 113
    data object RateLimited : AppNotice // 120
}

@Composable
fun AppNoticeView(
    notice: AppNotice,
    retryAvailableAt: Long? = null,
    onDismiss: () -> Unit = {},
    onSignOut: () -> Unit = {},
    modifier: Modifier = Modifier,
) {
    val context = androidx.compose.ui.platform.LocalContext.current
    when (notice) {
        is AppNotice.LoginExpired -> {
            StatusView(
                icon = R.drawable.icon_user,
                title = "다시 로그인해 주세요",
                message = "쓴 글은 그대로 남아 있어요.",
                actions = listOf(
                    StatusAction(
                        title = "로그인",
                        style = StatusAction.Style.Primary,
                        run = {
                            onDismiss()
                            onSignOut()
                        },
                    ),
                ),
                modifier = modifier,
            )
        }
        is AppNotice.UpdateRequired -> {
            StatusView(
                icon = R.drawable.icon_info,
                title = "새 버전이 필요해요",
                message = "더 안전하게 쓰기 위해 업데이트가 필요해요.",
                actions = listOf(
                    StatusAction(
                        title = "업데이트",
                        style = StatusAction.Style.Primary,
                        run = {
                            val pkg = context.packageName
                            val intent = android.content.Intent(
                                android.content.Intent.ACTION_VIEW,
                                android.net.Uri.parse("market://details?id=$pkg"),
                            ).apply { addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK) }
                            runCatching { context.startActivity(intent) }
                                .onFailure {
                                    val web = android.content.Intent(
                                        android.content.Intent.ACTION_VIEW,
                                        android.net.Uri.parse("https://play.google.com/store/apps/details?id=$pkg"),
                                    ).apply { addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK) }
                                    runCatching { context.startActivity(web) }
                                }
                        },
                    ),
                ),
                modifier = modifier,
            )
        }
        is AppNotice.Maintenance -> {
            StatusView(
                icon = R.drawable.icon_moon,
                title = "잠시 점검 중이에요",
                message = "${notice.window}\n기록은 안전하게 보관돼요.",
                actions = listOf(
                    StatusAction(
                        title = "닫기",
                        style = StatusAction.Style.Ghost,
                        run = onDismiss,
                    ),
                ),
                modifier = modifier,
            )
        }
        is AppNotice.AccountDeleted -> {
            StatusView(
                icon = R.drawable.icon_moon,
                title = "계정을 삭제했어요",
                message = "그동안 띄운 별과 별자리가 모두 사라졌어요.\n언제든 다시 첫 별을 띄울 수 있어요.",
                actions = listOf(
                    StatusAction(
                        title = "처음 화면으로",
                        style = StatusAction.Style.Primary,
                        run = {
                            onDismiss()
                            onSignOut()
                        },
                    ),
                ),
                modifier = modifier,
            )
        }
        is AppNotice.RateLimited -> {
            var now by androidx.compose.runtime.remember { androidx.compose.runtime.mutableLongStateOf(System.currentTimeMillis()) }
            androidx.compose.runtime.LaunchedEffect(Unit) {
                while (true) {
                    kotlinx.coroutines.delay(1000)
                    now = System.currentTimeMillis()
                }
            }
            val leftMillis = (retryAvailableAt ?: 0L) - now
            val leftSeconds = (leftMillis / 1000).coerceAtLeast(0)
            val minutes = ((leftSeconds + 59) / 60).toInt()
            val base = "요청이 한꺼번에 몰렸어요. 쓰던 글은 그대로 있고 코인도 차감되지 않았어요."
            val msg = if (leftSeconds > 0) "$base ${minutes}분 뒤에 다시 시도할 수 있어요." else "$base 조금 뒤에 다시 시도해 주세요."
            val btnTitle = if (leftSeconds > 0) "${minutes}분 뒤에 다시 시도" else "다시 시도하기"

            StatusView(
                icon = R.drawable.icon_moon,
                title = "잠시 숨을 고르고 있어요",
                message = msg,
                actions = listOf(
                    StatusAction(
                        title = btnTitle,
                        style = StatusAction.Style.Primary,
                        disabled = leftSeconds > 0,
                        run = onDismiss,
                    ),
                ),
                modifier = modifier,
            )
        }
    }
}

// MARK: - Empty state (96–98, 103, 108, 109, 119)

enum class EmptyStateActionStyle { Primary, Outline }

/**
 * Figma empty states (iOS EmptyStateView):
 * a dim star glyph, a title, a short note, and an optional action.
 */
@Composable
fun EmptyStateView(
    title: String,
    message: String,
    modifier: Modifier = Modifier,
    actionTitle: String? = null,
    actionStyle: EmptyStateActionStyle = EmptyStateActionStyle.Primary,
    onAction: (() -> Unit)? = null,
    floatedGlyph: Boolean = true,
) {
    Column(
        modifier = modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(Space.md),
    ) {
        Image(
            painter = painterResource(if (floatedGlyph) R.drawable.star_shape_floated else R.drawable.star_shape_kept),
            contentDescription = null,
            modifier = Modifier
                .padding(bottom = Space.sm)
                .size(40.dp)
                .alpha(0.55f),
        )
        Text(
            text = title,
            style = YText.h3,
            color = YColor.textPrimary,
            textAlign = TextAlign.Center,
        )
        Text(
            text = message,
            style = YText.bodyS,
            color = YColor.textSecondary,
            textAlign = TextAlign.Center,
        )
        if (actionTitle != null && onAction != null) {
            Spacer(Modifier.size(Space.sm))
            when (actionStyle) {
                EmptyStateActionStyle.Primary -> PrimaryButton(
                    text = actionTitle,
                    onClick = onAction,
                )
                EmptyStateActionStyle.Outline -> SecondaryButton(
                    text = actionTitle,
                    onClick = onAction,
                )
            }
        }
    }
}

// MARK: - 114 Export in progress

/** 114 내보내는 중이에요 (iOS ExportProgressSheet) */
@Composable
fun ExportProgressSheet(
    detail: String,
    progress: Float,
    onClose: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val a = sky()
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(start = Space.xl, end = Space.xl, top = Space.md, bottom = Space.xl),
        verticalArrangement = Arrangement.spacedBy(Space.lg),
    ) {
        com.dycdyp.youniya.ui.components.SheetGrabber()

        Column(verticalArrangement = Arrangement.spacedBy(Space.sm)) {
            Text("내보내는 중이에요", style = YText.h3, color = YColor.textPrimary)
            Text(detail, style = YText.bodyM, color = YColor.textSecondary)
        }

        Column(verticalArrangement = Arrangement.spacedBy(Space.sm)) {
            Box(
                Modifier
                    .fillMaxWidth()
                    .height(6.dp)
                    .background(YColor.borderDefault.copy(alpha = 0.5f), androidx.compose.foundation.shape.CircleShape),
            ) {
                Box(
                    Modifier
                        .fillMaxWidth(fraction = progress.coerceIn(0f, 1f))
                        .height(6.dp)
                        .background(a.brandPrimary, androidx.compose.foundation.shape.CircleShape),
                )
            }
            Text(
                "${(progress * 100).toInt()}% · ${if (progress >= 0.5f) "거의 다 됐어요" else "모으는 중이에요"}",
                style = YText.caption,
                color = YColor.textTertiary,
            )
        }

        GhostButton("닫기", onClick = onClose)
    }
}
