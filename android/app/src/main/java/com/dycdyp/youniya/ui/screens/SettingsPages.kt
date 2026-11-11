package com.dycdyp.youniya.ui.screens

import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.statusBarsPadding
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
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
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.dycdyp.youniya.R
import com.dycdyp.youniya.data.AppModel
import com.dycdyp.youniya.data.BlockedKeeper
import com.dycdyp.youniya.data.CoinEntry
import com.dycdyp.youniya.data.NotificationAccess
import com.dycdyp.youniya.data.StarReminder
import com.dycdyp.youniya.data.formatKstShortDate
import com.dycdyp.youniya.ui.components.ActionSheetContent
import com.dycdyp.youniya.ui.components.DangerButton
import com.dycdyp.youniya.ui.components.GhostButton
import com.dycdyp.youniya.ui.components.PrimaryButton
import com.dycdyp.youniya.ui.components.SecondaryButton
import com.dycdyp.youniya.ui.components.SheetGrabber
import com.dycdyp.youniya.ui.components.TopAppBar
import com.dycdyp.youniya.ui.components.noRippleClick
import com.dycdyp.youniya.ui.design.StarField
import com.dycdyp.youniya.ui.design.cosmos
import com.dycdyp.youniya.ui.theme.Radius
import com.dycdyp.youniya.ui.theme.SkyThemes
import com.dycdyp.youniya.ui.theme.Space
import com.dycdyp.youniya.ui.theme.YColor
import com.dycdyp.youniya.ui.theme.YText
import com.dycdyp.youniya.ui.theme.sky
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.io.File
import java.io.FileOutputStream
import java.time.format.DateTimeFormatter
import java.util.Locale

private sealed interface SettingsSheet {
    data object DeleteAccount : SettingsSheet
    data object WithdrawShares : SettingsSheet
    data object Export : SettingsSheet
    data class Exporting(val isPdf: Boolean) : SettingsSheet
    data object ReminderTime : SettingsSheet
    data object SignOut : SettingsSheet
    data object NotificationsOff : SettingsSheet
    data object PolicyList : SettingsSheet
}

/**
 * 87 Settings (iOS SettingsView):
 * motion, sound, notifications, plaza, data, help.
 */
@Composable
fun SettingsView(
    model: AppModel,
    onBack: () -> Unit,
    onOpenNickname: () -> Unit,
    onOpenSky: () -> Unit,
    onOpenBlocked: () -> Unit,
    onOpenShared: () -> Unit,
    onPolicy: (PolicyDoc) -> Unit,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var sheet by remember { mutableStateOf<SettingsSheet?>(null) }
    var exportProgress by remember { mutableDoubleStateOf(0.0) }

    var pendingPermissionAction by remember { mutableStateOf<(() -> Unit)?>(null) }
    val permissionLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestPermission(),
    ) { granted ->
        if (granted) {
            pendingPermissionAction?.invoke()
        } else {
            sheet = SettingsSheet.NotificationsOff
        }
        pendingPermissionAction = null
    }

    BackHandler(onBack = onBack)
    Box(modifier.fillMaxSize()) {
        StarField()
        Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding()) {
            TopAppBar(title = "설정", onBack = onBack)

            Column(
                modifier = Modifier
                    .weight(1f)
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = Space.xl)
                    .padding(top = Space.sm, bottom = Space.xl),
                verticalArrangement = Arrangement.spacedBy(Space.sm),
            ) {
                Column(
                    verticalArrangement = Arrangement.spacedBy(Space.sm),
                    modifier = Modifier.semantics { heading() },
                ) {
                    Text("나에게 맞는 밤하늘", style = YText.h2, color = YColor.textPrimary)
                    Text(
                        "필요한 것만 켜 두세요. 언제든 바꿀 수 있어요.",
                        style = YText.bodyM,
                        color = YColor.textSecondary,
                    )
                }

                // 계정
                SettingsSection("계정") {
                    model.providerName?.let { p ->
                        SettingsRowLayout(icon = R.drawable.icon_shield, title = "로그인 계정") {
                            Text(p, style = YText.bodyS, color = YColor.textSecondary)
                        }
                    }
                    model.joinedAt?.let { j ->
                        SettingsRowLayout(icon = R.drawable.icon_star, title = "가입한 날") {
                            Text(j, style = YText.bodyS, color = YColor.textSecondary)
                        }
                    }
                    SettingsRow(
                        icon = R.drawable.icon_user,
                        title = "별지기 이름",
                        value = model.nickname ?: "정하기",
                        onClick = onOpenNickname,
                    )
                }

                // 화면과 움직임
                SettingsSection("화면과 움직임") {
                    SettingsRow(icon = R.drawable.icon_moon, title = "우주의 색", onClick = onOpenSky)
                    SettingsToggleRow(
                        icon = R.drawable.icon_star,
                        title = "애니메이션 줄이기",
                        isOn = model.reduceAnimations,
                        onToggle = { model.setReduceAnimations(!model.reduceAnimations) },
                    )
                }

                // 알림
                val reminderNote = if (model.starReminder) {
                    "별을 띄우지 않은 날에만 고른 시각에 한 번 알려 드려요. 연속 기록이나 재촉하는 알림은 보내지 않아요."
                } else {
                    "연속 기록이나 재촉하는 알림은 보내지 않아요."
                }
                SettingsSection("알림", note = reminderNote) {
                    SettingsToggleRow(
                        icon = R.drawable.icon_bell,
                        title = "별 만들기 알림",
                        isOn = model.starReminder,
                        onToggle = {
                            if (!model.starReminder) {
                                if (NotificationAccess.hasPermission(context)) {
                                    model.setStarReminder(true)
                                } else {
                                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
                                        pendingPermissionAction = { model.setStarReminder(true) }
                                        permissionLauncher.launch(android.Manifest.permission.POST_NOTIFICATIONS)
                                    } else {
                                        model.setStarReminder(true)
                                    }
                                }
                            } else {
                                model.setStarReminder(false)
                            }
                        },
                    )
                    if (model.starReminder) {
                        SettingsRow(
                            icon = R.drawable.icon_moon,
                            title = "알림 시각",
                            value = StarReminder.timeText(model.reminderMinutes),
                            onClick = { sheet = SettingsSheet.ReminderTime },
                        )
                    }
                    SettingsToggleRow(
                        icon = R.drawable.icon_info,
                        title = "새 기능·혜택 알림",
                        isOn = model.marketingOptIn,
                        onToggle = {
                            if (!model.marketingOptIn) {
                                if (NotificationAccess.hasPermission(context)) {
                                    model.setMarketing(true)
                                } else {
                                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
                                        pendingPermissionAction = { model.setMarketing(true) }
                                        permissionLauncher.launch(android.Manifest.permission.POST_NOTIFICATIONS)
                                    } else {
                                        model.setMarketing(true)
                                    }
                                }
                            } else {
                                model.setMarketing(false)
                            }
                        },
                    )
                }

                // 우주 광장
                SettingsSection("우주 광장") {
                    // 나눈 별 lives in the plaza tab (「내가 나눈 별 N개 ›」), as on iOS since 2026-11-10.
                    SettingsRow(
                        icon = R.drawable.icon_close,
                        title = "차단한 별지기",
                        value = "${model.blockedList.size}명",
                        onClick = onOpenBlocked,
                    )
                    SettingsRow(
                        icon = R.drawable.icon_lock,
                        title = "모든 공유 거두기",
                        onClick = { sheet = SettingsSheet.WithdrawShares },
                    )
                }

                // 데이터
                SettingsSection("데이터") {
                    SettingsRow(icon = R.drawable.icon_export, title = "데이터 내보내기", onClick = { sheet = SettingsSheet.Export })
                    SettingsRow(icon = R.drawable.icon_trash, title = "계정 영구 삭제", onClick = { sheet = SettingsSheet.DeleteAccount })
                }

                // 도움
                SettingsSection("도움") {
                    SettingsRow(icon = R.drawable.icon_phone, title = "24시간 위기 상담", value = "109") {
                        val dial = Intent(Intent.ACTION_DIAL, Uri.parse("tel:109")).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        runCatching { context.startActivity(dial) }
                    }
                    SettingsRow(icon = R.drawable.icon_file, title = "약관 및 정책", onClick = { sheet = SettingsSheet.PolicyList })
                    SettingsRow(icon = R.drawable.icon_logout, title = "로그아웃", onClick = { sheet = SettingsSheet.SignOut })
                }
            }
        }

        // Bottom sheets
        sheet?.let { currentSheet ->
            when (currentSheet) {
                is SettingsSheet.DeleteAccount -> {
                    YouniyaSheet("sheet-delete", onDismiss = { sheet = null }) {
                        ActionSheetContent(
                            title = "계정을 영구 삭제할까요?",
                            message = "별과 별자리, 은하수, 계정 정보가 모두 흔적 없이 사라지고 되돌릴 수 없어요. 먼저 내 데이터를 내보내 둘 수 있어요.",
                            primaryText = "영구 삭제",
                            onPrimary = {
                                sheet = null
                                if (model.provider == "apple") {
                                    com.dycdyp.youniya.data.AppleSignIn.start(context, com.dycdyp.youniya.data.AppleSignIn.Purpose.Delete)
                                } else {
                                    model.deleteAccount()
                                }
                            },
                            secondaryText = "먼저 내보내기",
                            onSecondary = { sheet = SettingsSheet.Export },
                            ghostText = "취소",
                            onGhost = { sheet = null },
                            destructive = true,
                        )
                    }
                }
                is SettingsSheet.WithdrawShares -> {
                    YouniyaSheet("sheet-withdraw", onDismiss = { sheet = null }) {
                        ActionSheetContent(
                            title = "나눈 별을 모두 거둘까요?",
                            message = "우주 광장에서 나눈 별을 거둬요. 그동안 받은 공명과 별빛 한 줄은 그대로 간직돼요. 언제든 다시 나눌 수 있어요.",
                            primaryText = "모두 거두기",
                            onPrimary = {
                                sheet = null
                                model.withdrawAllShares()
                            },
                            secondaryText = "그대로 두기",
                            onSecondary = { sheet = null },
                        )
                    }
                }
                is SettingsSheet.Export -> {
                    YouniyaSheet("sheet-export", onDismiss = { sheet = null }) {
                        ActionSheetContent(
                            title = "어떤 형식으로 내보낼까요?",
                            message = "쓴 별을 모두 파일로 내려받아요. 파일은 내 기기에만 저장돼요.",
                            primaryText = "텍스트 파일로",
                            onPrimary = {
                                sheet = SettingsSheet.Exporting(isPdf = false)
                            },
                            secondaryText = "PDF로",
                            onSecondary = {
                                sheet = SettingsSheet.Exporting(isPdf = true)
                            },
                            ghostText = "닫기",
                            onGhost = { sheet = null },
                        )
                    }
                }
                is SettingsSheet.Exporting -> {
                    LaunchedEffect(Unit) {
                        exportProgress = 0.0
                        for (i in 1..10) {
                            delay(140)
                            exportProgress = i / 10.0
                        }
                        delay(200)
                        sheet = null
                        // Share export file
                        val text = model.exportText()
                        val shareIntent = Intent(Intent.ACTION_SEND).apply {
                            type = "text/plain"
                            putExtra(Intent.EXTRA_TEXT, text)
                        }
                        context.startActivity(Intent.createChooser(shareIntent, "YOUNIYA 데이터 내보내기"))
                    }
                    YouniyaSheet("sheet-exporting", onDismiss = { sheet = null }) {
                        ExportProgressSheet(
                            detail = "별 ${model.stars.size}개와 별자리 이야기를 ${if (currentSheet.isPdf) "PDF" else "텍스트"} 파일로 모으고 있어요. 창을 닫아도 이어서 만들어요.",
                            progress = exportProgress.toFloat(),
                            onClose = { sheet = null },
                        )
                    }
                }
                is SettingsSheet.NotificationsOff -> {
                    YouniyaSheet("sheet-notif-off", onDismiss = { sheet = null }) {
                        ActionSheetContent(
                            title = "알림이 꺼져 있어요",
                            message = "알림을 받으려면 휴대전화 설정에서 YOUNIYA 알림을 켜 주세요.",
                            primaryText = "설정 열기",
                            onPrimary = {
                                sheet = null
                                NotificationAccess.openSettings(context)
                            },
                            secondaryText = "닫기",
                            onSecondary = { sheet = null },
                        )
                    }
                }
                is SettingsSheet.SignOut -> {
                    YouniyaSheet("sheet-signout", onDismiss = { sheet = null }) {
                        SignOutSheet(
                            onSignOut = {
                                sheet = null
                                model.signOut()
                            },
                            onCancel = { sheet = null },
                        )
                    }
                }
                is SettingsSheet.ReminderTime -> {
                    YouniyaSheet("sheet-time", onDismiss = { sheet = null }) {
                        ReminderTimeSheet(
                            initialMinutes = model.reminderMinutes,
                            onSave = { m ->
                                sheet = null
                                model.updateReminderMinutes(m)
                            },
                            onCancel = { sheet = null },
                        )
                    }
                }
                is SettingsSheet.PolicyList -> {
                    YouniyaSheet("sheet-policies", onDismiss = { sheet = null }) {
                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = Space.xl, vertical = Space.lg),
                            verticalArrangement = Arrangement.spacedBy(Space.md),
                        ) {
                            SheetGrabber()
                            Text("약관 및 정책", style = YText.h3, color = YColor.textPrimary)
                            listOf(PolicyDoc.Terms, PolicyDoc.Privacy, PolicyDoc.Sensitive, PolicyDoc.Payment).forEach { doc ->
                                Box(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .noRippleClick {
                                            sheet = null
                                            onPolicy(doc)
                                        }
                                        .padding(vertical = Space.md),
                                ) {
                                    Text(doc.title, style = YText.bodyM, color = YColor.textPrimary)
                                }
                            }
                            GhostButton("닫기", onClick = { sheet = null })
                        }
                    }
                }
            }
        }
    }
}

/** 87-5 로그아웃할까요? */
@Composable
private fun SignOutSheet(
    onSignOut: () -> Unit,
    onCancel: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(start = Space.xl, end = Space.xl, top = Space.md, bottom = Space.xxl),
        verticalArrangement = Arrangement.spacedBy(Space.lg),
    ) {
        SheetGrabber()
        Column(verticalArrangement = Arrangement.spacedBy(Space.sm)) {
            Text("로그아웃할까요?", style = YText.h3, color = YColor.textPrimary)
            Text(
                "쓴 글과 별은 그대로 남아 있어요. 다시 로그인하면 이어서 볼 수 있어요.",
                style = YText.bodyM,
                color = YColor.textSecondary,
            )
        }
        Column(verticalArrangement = Arrangement.spacedBy(Space.md)) {
            PrimaryButton("로그아웃", onClick = onSignOut)
            GhostButton("취소", onClick = onCancel)
        }
    }
}

/** 87-2 알림 시각 고르기 */
@Composable
private fun ReminderTimeSheet(
    initialMinutes: Int,
    onSave: (Int) -> Unit,
    onCancel: () -> Unit,
) {
    var hour by remember { mutableIntStateOf((initialMinutes / 60) % 24) }
    var minute by remember { mutableIntStateOf((initialMinutes % 60) / 5 * 5) }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(start = Space.xl, end = Space.xl, top = Space.md, bottom = Space.xxl),
        verticalArrangement = Arrangement.spacedBy(Space.lg),
    ) {
        SheetGrabber()
        Column(verticalArrangement = Arrangement.spacedBy(Space.sm)) {
            Text("언제 알려 드릴까요?", style = YText.h3, color = YColor.textPrimary)
            Text(
                "별을 띄우지 않은 날에만, 이 시각에 한 번 조용히 알려 드려요.",
                style = YText.bodyM,
                color = YColor.textSecondary,
            )
        }

        // Time selector
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = Space.md),
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            val isPm = hour >= 12
            val displayHour = when {
                hour == 0 -> 12
                hour > 12 -> hour - 12
                else -> hour
            }

            // Am/Pm
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Box(
                    modifier = Modifier
                        .clip(CircleShape)
                        .background(if (!isPm) sky().tintPrimary else Color.Transparent)
                        .noRippleClick { if (isPm) hour -= 12 }
                        .padding(horizontal = Space.md, vertical = Space.xs),
                ) { Text("오전", style = YText.labelM, color = if (!isPm) YColor.textPrimary else YColor.textTertiary) }
                Box(
                    modifier = Modifier
                        .clip(CircleShape)
                        .background(if (isPm) sky().tintPrimary else Color.Transparent)
                        .noRippleClick { if (!isPm) hour += 12 }
                        .padding(horizontal = Space.md, vertical = Space.xs),
                ) { Text("오후", style = YText.labelM, color = if (isPm) YColor.textPrimary else YColor.textTertiary) }
            }

            Spacer(Modifier.width(Space.xl))

            // Hour
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(
                    modifier = Modifier
                        .size(36.dp)
                        .noRippleClick {
                            val h = if (hour == 0) 23 else hour - 1
                            hour = h
                        },
                    contentAlignment = Alignment.Center,
                ) { Text("−", style = YText.h3, color = YColor.textSecondary) }
                Text(
                    "%02d시".format(displayHour),
                    style = YText.h2,
                    color = YColor.textPrimary,
                    modifier = Modifier.padding(horizontal = Space.sm),
                )
                Box(
                    modifier = Modifier
                        .size(36.dp)
                        .noRippleClick {
                            val h = (hour + 1) % 24
                            hour = h
                        },
                    contentAlignment = Alignment.Center,
                ) { Text("+", style = YText.h3, color = YColor.textSecondary) }
            }

            Spacer(Modifier.width(Space.md))

            // Minute (5 min steps)
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(
                    modifier = Modifier
                        .size(36.dp)
                        .noRippleClick {
                            minute = if (minute == 0) 55 else minute - 5
                        },
                    contentAlignment = Alignment.Center,
                ) { Text("−", style = YText.h3, color = YColor.textSecondary) }
                Text(
                    "%02d분".format(minute),
                    style = YText.h2,
                    color = YColor.textPrimary,
                    modifier = Modifier.padding(horizontal = Space.sm),
                )
                Box(
                    modifier = Modifier
                        .size(36.dp)
                        .noRippleClick {
                            minute = (minute + 5) % 60
                        },
                    contentAlignment = Alignment.Center,
                ) { Text("+", style = YText.h3, color = YColor.textSecondary) }
            }
        }

        Column(verticalArrangement = Arrangement.spacedBy(Space.md)) {
            PrimaryButton("저장") { onSave(hour * 60 + minute) }
            GhostButton("취소", onClick = onCancel)
        }
    }
}

@Composable
fun SettingsSection(
    title: String,
    modifier: Modifier = Modifier,
    note: String? = null,
    content: @Composable () -> Unit,
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(top = Space.md),
    ) {
        Text(
            title,
            style = YText.labelS,
            color = YColor.textTertiary,
            modifier = Modifier.semantics { heading() },
        )
        content()
        if (note != null) {
            Text(
                note,
                style = YText.caption,
                color = YColor.textTertiary,
                modifier = Modifier.padding(top = Space.xs),
            )
        }
    }
}

@Composable
fun SettingsRow(
    icon: Int,
    title: String,
    modifier: Modifier = Modifier,
    value: String? = null,
    onClick: () -> Unit,
) {
    SettingsRowLayout(icon = icon, title = title, modifier = modifier.noRippleClick(onClick)) {
        if (value != null) {
            Text(value, style = YText.bodyS, color = YColor.textSecondary)
        }
        Icon(
            painter = painterResource(R.drawable.icon_chevron_right),
            contentDescription = null,
            modifier = Modifier.size(20.dp),
            tint = YColor.textTertiary,
        )
    }
}

@Composable
fun SettingsToggleRow(
    icon: Int,
    title: String,
    isOn: Boolean,
    onToggle: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val a = sky()
    SettingsRowLayout(icon = icon, title = title, modifier = modifier.noRippleClick(onToggle)) {
        Box(
            modifier = Modifier
                .size(44.dp, 26.dp)
                .clip(CircleShape)
                .background(if (isOn) a.brandPrimary else YColor.borderDefault, CircleShape)
                .padding(3.dp),
            contentAlignment = if (isOn) Alignment.CenterEnd else Alignment.CenterStart,
        ) {
            Box(Modifier.size(20.dp).background(Color.White, CircleShape))
        }
    }
}

@Composable
fun SettingsRowLayout(
    icon: Int,
    title: String,
    modifier: Modifier = Modifier,
    trailing: @Composable () -> Unit,
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .heightIn(min = 47.dp)
            .padding(vertical = Space.md),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Space.md),
    ) {
        Icon(
            painter = painterResource(icon),
            contentDescription = null,
            modifier = Modifier.size(22.dp),
            tint = YColor.textSecondary,
        )
        Text(title, style = YText.bodyM, color = YColor.textPrimary, modifier = Modifier.weight(1f))
        trailing()
    }
    Box(Modifier.fillMaxWidth().height(1.dp).background(YColor.borderDefault))
}

// MARK: - 68 우주의 색

enum class SkyThemeKey(val key: String, val displayName: String, val detail: String) {
    Violet("violet", "보랏빛 별밤", "차분하고 깊은 기본 밤하늘"),
    Ocean("ocean", "깊은 바다", "고요하게 가라앉는 푸른 밤"),
}

@Composable
fun SkyColorView(
    model: AppModel,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var selected by remember { mutableStateOf(model.skyThemeKey) }

    BackHandler(onBack = onBack)
    Box(modifier.fillMaxSize()) {
        StarField()
        Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding()) {
            TopAppBar(title = "우주의 색", onBack = onBack)

            Column(
                modifier = Modifier
                    .weight(1f)
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = Space.xl)
                    .padding(top = Space.xl, bottom = Space.lg),
                verticalArrangement = Arrangement.spacedBy(Space.lg),
            ) {
                Column(
                    verticalArrangement = Arrangement.spacedBy(Space.lg),
                    modifier = Modifier.semantics { heading() },
                ) {
                    Text("어떤 밤하늘이\n편안한가요?", style = YText.h1, color = YColor.textPrimary)
                    Text(
                        "우주의 색은 사람마다 다르게 느껴져요. 언제든 바꿀 수 있고, 기록은 그대로예요.",
                        style = YText.bodyM,
                        color = YColor.textSecondary,
                    )
                }

                Column(verticalArrangement = Arrangement.spacedBy(Space.md)) {
                    SkyThemeKey.entries.forEach { item ->
                        SkyOptionRow(
                            item = item,
                            isSelected = item.key == selected,
                            onClick = { selected = item.key },
                        )
                    }
                }
            }

            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = Space.xl, vertical = Space.xl),
            ) {
                PrimaryButton("적용하기") {
                    model.setSkyThemeKey(selected)
                    onBack()
                }
            }
        }
    }
}

@Composable
private fun SkyOptionRow(
    item: SkyThemeKey,
    isSelected: Boolean,
    onClick: () -> Unit,
) {
    val a = sky()
    val shape = RoundedCornerShape(Radius.lg)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(shape)
            .background(YColor.bgSurface, shape)
            .cosmos("sky-${item.key}", shape)
            .border(if (isSelected) 2.dp else 1.dp, if (isSelected) a.borderFocus else YColor.borderDefault, shape)
            .noRippleClick(onClick)
            .padding(Space.md),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Space.md),
    ) {
        SkySwatch(item)

        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(Space.xs),
        ) {
            Text(item.displayName, style = YText.labelM, color = YColor.textPrimary)
            Text(item.detail, style = YText.caption, color = YColor.textTertiary)
        }

        Box(
            modifier = Modifier
                .size(22.dp)
                .border(2.dp, if (isSelected) a.brandPrimary else YColor.borderDefault, CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            if (isSelected) {
                Box(Modifier.size(12.dp).background(a.brandPrimary, CircleShape))
            }
        }
    }
}

@Composable
private fun SkySwatch(item: SkyThemeKey) {
    val (c1, c2, c3) = if (item == SkyThemeKey.Violet) {
        Triple(Color(0xFF8B5CF6), Color(0xFFEC4899), Color(0xFF33B5D9))
    } else {
        Triple(Color(0xFF3B82F6), Color(0xFF6366F1), Color(0xFF22D3EE))
    }
    Canvas(
        modifier = Modifier
            .size(76.dp, 52.dp)
            .clip(RoundedCornerShape(Radius.md))
            .background(Color(0xFF0A0D1A)),
    ) {
        drawCircle(c1.copy(alpha = 0.5f), radius = 25.dp.toPx(), center = Offset(20.dp.toPx(), 15.dp.toPx()))
        drawCircle(c2.copy(alpha = 0.4f), radius = 20.dp.toPx(), center = Offset(45.dp.toPx(), 25.dp.toPx()))
        drawCircle(c3.copy(alpha = 0.35f), radius = 15.dp.toPx(), center = Offset(30.dp.toPx(), 35.dp.toPx()))
        drawCircle(c1, radius = 2.dp.toPx(), center = Offset(18.dp.toPx(), 18.dp.toPx()))
        drawCircle(c2, radius = 2.dp.toPx(), center = Offset(44.dp.toPx(), 32.dp.toPx()))
        drawCircle(c3, radius = 2.dp.toPx(), center = Offset(60.dp.toPx(), 14.dp.toPx()))
    }
}

// MARK: - 87-3 차단한 별지기

@Composable
fun BlockedKeepersView(
    model: AppModel,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val keepers = model.blockedList

    LaunchedEffect(Unit) {
        model.loadBlocks()
    }

    BackHandler(onBack = onBack)
    Box(modifier.fillMaxSize()) {
        StarField()
        Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding()) {
            TopAppBar(title = "차단한 별지기", onBack = onBack)

            if (keepers.isEmpty()) {
                EmptyStateView(
                    title = "차단한 별지기가 없어요",
                    message = "우주 광장에서 차단한 사람이\n여기에 모여요.",
                    modifier = Modifier.padding(top = Space.xxxl),
                )
            } else {
                LazyColumn(
                    modifier = Modifier
                        .weight(1f)
                        .padding(horizontal = Space.xl)
                        .padding(top = Space.sm, bottom = Space.xxxl),
                    verticalArrangement = Arrangement.spacedBy(Space.md),
                ) {
                    item {
                        Text(
                            "차단한 별지기 ${keepers.size}명이에요. 이 사람들의 별과 별빛 한 줄은 내 화면에 보이지 않아요. 풀면 다시 보여요.",
                            style = YText.bodyM,
                            color = YColor.textSecondary,
                        )
                    }

                    items(keepers, key = { it.id }) { keeper ->
                        BlockedKeeperRow(
                            keeper = keeper,
                            onUnblock = { model.unblock(keeper.id) },
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun BlockedKeeperRow(
    keeper: BlockedKeeper,
    onUnblock: () -> Unit,
) {
    val shape = RoundedCornerShape(Radius.lg)
    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.End,
        verticalArrangement = Arrangement.spacedBy(Space.xs),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(shape)
                .background(YColor.bgSurface, shape)
                .cosmos(keeper.id, shape)
                .border(1.dp, YColor.borderDefault, shape)
                .padding(Space.lg),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(Space.md),
        ) {
            Image(
                painter = painterResource(R.drawable.star_shape_floated),
                contentDescription = null,
                modifier = Modifier.size(18.dp),
            )
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(Space.xs),
            ) {
                Text("익명의 별지기", style = YText.bodyM, color = YColor.textPrimary)
                Text(keeper.detail, style = YText.caption, color = YColor.textTertiary)
            }
        }

        Box(
            modifier = Modifier
                .noRippleClick(onUnblock)
                .padding(vertical = Space.xs, horizontal = Space.xs),
        ) {
            Text("차단 풀기", style = YText.labelS, color = YColor.textSecondary)
        }
    }
}

// MARK: - 33 Coin History

@Composable
fun CoinHistoryView(
    model: AppModel,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
) {
    LaunchedEffect(Unit) {
        model.loadCoinHistory()
    }

    BackHandler(onBack = onBack)
    Box(modifier.fillMaxSize()) {
        StarField()
        Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding()) {
            TopAppBar(title = "코인 내역", onBack = onBack)

            Column(
                modifier = Modifier
                    .weight(1f)
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = Space.xl)
                    .padding(top = Space.sm, bottom = Space.xl),
                verticalArrangement = Arrangement.spacedBy(Space.lg),
            ) {
                CoinHero()

                if (model.coinHistory.isEmpty()) {
                    EmptyStateView(
                        title = "아직 쓴 코인이 없어요",
                        message = "별빛 받기에 쓴 코인이\n여기에 차례로 쌓여요.",
                        modifier = Modifier.padding(top = Space.md),
                    )
                } else {
                    Column(verticalArrangement = Arrangement.spacedBy(Space.md)) {
                        for (entry in model.coinHistory) {
                            CoinHistoryCard(entry)
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun CoinHistoryCard(entry: CoinEntry) {
    val shape = RoundedCornerShape(Radius.lg)
    val amount = if (entry.delta < 0) "−${-entry.delta}" else "+${entry.delta}"
    val dateText = formatKstShortDate(entry.createdAt) ?: ""
    val detail = "$amount · $dateText"

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(shape)
            .background(YColor.bgSurface, shape)
            .cosmos(entry.id, shape)
            .border(1.dp, YColor.borderDefault, shape)
            .padding(Space.lg),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(entry.displayTitle, style = YText.labelM, color = YColor.textPrimary)
        Text(detail, style = YText.bodyS, color = YColor.textSecondary)
    }
}

// MARK: - 32 Inquiry

@Composable
fun InquiryView(
    model: AppModel,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val kinds = listOf("결제", "계정", "기타")
    val apiKinds = mapOf("결제" to "payment", "계정" to "account", "기타" to "other")
    var kind by remember { mutableStateOf<String?>(null) }
    var email by remember { mutableStateOf("") }
    var message by remember { mutableStateOf("") }
    var sent by remember { mutableStateOf(false) }
    var sending by remember { mutableStateOf(false) }

    val emailIsValid = remember(email) {
        val e = email.trim()
        e.length <= 255 && android.util.Patterns.EMAIL_ADDRESS.matcher(e).matches()
    }
    val canSend = kind != null && emailIsValid && message.trim().isNotEmpty()

    BackHandler(onBack = onBack)
    Box(modifier.fillMaxSize()) {
        StarField()
        Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding()) {
            TopAppBar(title = "문의하기", onBack = onBack)

            Column(
                modifier = Modifier
                    .weight(1f)
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = Space.xl)
                    .padding(top = Space.sm, bottom = Space.xl),
                verticalArrangement = Arrangement.spacedBy(Space.lg),
            ) {
                Column(
                    verticalArrangement = Arrangement.spacedBy(Space.sm),
                    modifier = Modifier.semantics { heading() },
                ) {
                    Text("무엇이 궁금하세요?", style = YText.h1, color = YColor.textPrimary)
                    Text("내용과 연락 받을 이메일을 남겨 주세요.", style = YText.bodyM, color = YColor.textSecondary)
                }

                // Kind selection
                Column(verticalArrangement = Arrangement.spacedBy(Space.sm)) {
                    Text("문의 유형", style = YText.labelS, color = YColor.textSecondary)
                    Row(horizontalArrangement = Arrangement.spacedBy(Space.sm)) {
                        kinds.forEach { k ->
                            val on = kind == k
                            FilterPillChip(title = k, isSelected = on) { kind = k }
                        }
                    }
                }

                // Email field
                val shape = RoundedCornerShape(Radius.lg)
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(shape)
                        .background(YColor.bgSurface, shape)
                        .border(1.dp, YColor.borderDefault, shape)
                        .padding(Space.lg),
                    verticalArrangement = Arrangement.spacedBy(Space.xs),
                ) {
                    Text("답장 받을 이메일", style = YText.labelM, color = YColor.textPrimary)
                    BasicTextField(
                        value = email,
                        onValueChange = { email = it },
                        modifier = Modifier.fillMaxWidth(),
                        textStyle = YText.bodyS.copy(color = YColor.textPrimary),
                        cursorBrush = SolidColor(sky().borderFocus),
                        singleLine = true,
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email, autoCorrectEnabled = false),
                        decorationBox = { inner ->
                            if (email.isEmpty()) {
                                Text("name@example.com", style = YText.bodyS, color = YColor.textTertiary)
                            }
                            inner()
                        },
                    )
                }

                // Message field
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(shape)
                        .background(YColor.bgSurface, shape)
                        .border(1.dp, YColor.borderDefault, shape)
                        .padding(Space.lg),
                    verticalArrangement = Arrangement.spacedBy(Space.xs),
                ) {
                    Text("내용", style = YText.labelM, color = YColor.textPrimary)
                    BasicTextField(
                        value = message,
                        onValueChange = { message = it },
                        modifier = Modifier
                            .fillMaxWidth()
                            .heightIn(min = 120.dp),
                        textStyle = YText.bodyS.copy(color = YColor.textPrimary),
                        cursorBrush = SolidColor(sky().borderFocus),
                        keyboardOptions = KeyboardOptions(autoCorrectEnabled = false),
                        decorationBox = { inner ->
                            if (message.isEmpty()) {
                                Text("여기에 적어 주세요", style = YText.bodyS, color = YColor.textTertiary)
                            }
                            inner()
                        },
                    )
                }
            }

            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = Space.xl, vertical = Space.xl),
            ) {
                PrimaryButton(
                    text = if (sent) "보냈어요" else "보내기",
                    enabled = canSend && !sent && !sending,
                    onClick = {
                        sending = true
                        val k = apiKinds[kind ?: "기타"] ?: "other"
                        model.sendInquiry(k, email.trim(), message.trim()) { ok ->
                            sending = false
                            if (ok) {
                                sent = true
                                onBack()
                            }
                        }
                    },
                )
            }
        }
    }
}
