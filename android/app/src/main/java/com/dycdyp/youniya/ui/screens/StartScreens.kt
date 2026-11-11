package com.dycdyp.youniya.ui.screens

import android.content.Context
import androidx.activity.compose.BackHandler
import androidx.browser.customtabs.CustomTabColorSchemeParams
import androidx.browser.customtabs.CustomTabsIntent
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
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
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import androidx.core.net.toUri
import com.dycdyp.youniya.R
import com.dycdyp.youniya.data.AppModel
import com.dycdyp.youniya.data.GoogleSignIn
import com.dycdyp.youniya.data.NicknameResult
import com.dycdyp.youniya.ui.components.CheckboxRow
import com.dycdyp.youniya.ui.components.GhostButton
import com.dycdyp.youniya.ui.components.LogoMark
import com.dycdyp.youniya.ui.components.LogoSize
import com.dycdyp.youniya.ui.components.NoticeBanner
import com.dycdyp.youniya.ui.components.PrimaryButton
import com.dycdyp.youniya.ui.components.SheetGrabber
import com.dycdyp.youniya.ui.components.SocialButton
import com.dycdyp.youniya.ui.components.SocialProvider
import com.dycdyp.youniya.ui.components.TopAppBar
import com.dycdyp.youniya.ui.components.noRippleClick
import com.dycdyp.youniya.ui.design.StarField
import com.dycdyp.youniya.ui.design.cosmos
import com.dycdyp.youniya.ui.theme.LocalMotionReduced
import com.dycdyp.youniya.ui.theme.Radius
import com.dycdyp.youniya.ui.theme.Space
import com.dycdyp.youniya.ui.theme.YColor
import com.dycdyp.youniya.ui.theme.YText
import com.dycdyp.youniya.ui.theme.sky
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * 01 Splash (AN-01-1). The system splash (AN-01) shows the Logo Mark at the screen's center;
 * here it rises 53dp to its 01 place while the sky, wordmark and slogan fade in (0.4s).
 */
@Composable
fun SplashScreen(onDone: () -> Unit) {
    val reduced = LocalMotionReduced.current
    val rise = remember { Animatable(if (reduced) 0f else 53f) }
    val fade = remember { Animatable(if (reduced) 1f else 0f) }
    LaunchedEffect(Unit) {
        if (!reduced) {
            launch { rise.animateTo(0f, tween(400, easing = FastOutSlowInEasing)) }
            fade.animateTo(1f, tween(400))
        }
        delay(2000)
        onDone()
    }
    Box(Modifier.fillMaxSize().background(YColor.bgCanvas)) {
        StarField(Modifier.alpha(fade.value))
        Column(
            Modifier.fillMaxSize().padding(Space.xl),
            verticalArrangement = Arrangement.spacedBy(Space.lg, Alignment.CenterVertically),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            LogoMark(LogoSize.Large, Modifier.offset(y = rise.value.dp))
            Text("YOUNIYA", style = YText.display, color = YColor.textPrimary, modifier = Modifier.alpha(fade.value))
            Text("텍스트로 시각화한 우리 모두의 우주", style = YText.bodyM, color = YColor.textSecondary, modifier = Modifier.alpha(fade.value))
        }
    }
}

/** 02 Login (AN-02): Google first, then Apple (web, AN-02-1), and 초대 계정 (02-1). */
@Composable
fun LoginScreen(model: AppModel) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var invite by remember { mutableStateOf(false) }
    Box(Modifier.fillMaxSize()) {
        StarField()
        Column(
            Modifier.fillMaxSize().safeDrawingPadding().padding(horizontal = Space.xl, vertical = Space.xxxl),
            verticalArrangement = Arrangement.spacedBy(Space.xl),
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(Space.lg)) {
                LogoMark(LogoSize.Small)
                Text("오늘의 마음을\n별로 빚어볼까요", style = YText.h1, color = YColor.textPrimary)
                Text("당신만 볼 수 있는 고요한 밤하늘이에요.\n쓴 글은 암호화되어 안전하게 보관돼요.", style = YText.bodyM, color = YColor.textSecondary)
            }
            Spacer(Modifier.weight(1f))
            Column(verticalArrangement = Arrangement.spacedBy(Space.md)) {
                SocialButton(SocialProvider.Google) {
                    scope.launch {
                        when (val r = GoogleSignIn.idToken(context)) {
                            is GoogleSignIn.Result.Token -> model.signInWithIdToken("google", r.idToken)
                            is GoogleSignIn.Result.Failed -> model.message = r.why
                            GoogleSignIn.Result.Cancelled -> Unit
                        }
                    }
                }
                SocialButton(SocialProvider.Apple) {
                    // AN-02-1 (Sign in with Apple in a Custom Tab) needs the server's return-to-app step.
                    model.message = "안드로이드의 Apple 로그인은 준비 중이에요."
                }
                Text(
                    "처음이라면 다음 화면에서\n이용약관과 개인정보 처리 동의를 받아요.",
                    style = YText.caption, color = YColor.textTertiary, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth(),
                )
                Box(Modifier.fillMaxWidth().heightIn(min = 32.dp).noRippleClick { invite = true }, contentAlignment = Alignment.Center) {
                    Text("초대 계정으로 로그인", style = YText.caption.copy(textDecoration = TextDecoration.Underline), color = sky().borderFocus)
                }
                if (com.dycdyp.youniya.BuildConfig.DEBUG) {
                    Box(Modifier.fillMaxWidth().heightIn(min = 32.dp).noRippleClick {
                        scope.launch { model.devSignIn("android-" + System.currentTimeMillis().toString().takeLast(6)) }
                    }, contentAlignment = Alignment.Center) {
                        Text("개발용: 새 계정으로 로그인", style = YText.caption, color = YColor.textTertiary)
                    }
                }
            }
        }
    }
    if (invite) InviteLoginSheet(model) { invite = false }
}

/** A bottom sheet in the iOS style: raised surface with a Cosmos BG, 24dp top corners, no Material grabber. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun YouniyaSheet(seed: String, onDismiss: () -> Unit, content: @Composable () -> Unit) {
    val state = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val shape = RoundedCornerShape(topStart = Radius.xl, topEnd = Radius.xl)
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = state,
        shape = shape,
        containerColor = YColor.bgSurfaceRaised,
        scrimColor = Color.Black.copy(alpha = 0.5f),
        dragHandle = null,
        contentWindowInsets = { WindowInsets(0) },
    ) {
        Box(Modifier.cosmos(seed, shape).navigationBarsPadding().imePadding()) { content() }
    }
}

/** 02-1 초대 계정으로 로그인. */
@Composable
private fun InviteLoginSheet(model: AppModel, onClose: () -> Unit) {
    val scope = rememberCoroutineScope()
    var username by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var failed by remember { mutableStateOf(false) }
    var working by remember { mutableStateOf(false) }
    var showPassword by remember { mutableStateOf(false) }
    val passwordFocus = remember { FocusRequester() }
    fun signIn() {
        if (username.isEmpty() || password.isEmpty() || working) return
        working = true
        scope.launch {
            val ok = model.inviteSignIn(username, password)
            working = false
            if (ok) onClose() else failed = true
        }
    }
    YouniyaSheet("invite-sheet", onClose) {
        Column(
            Modifier.padding(start = Space.xl, end = Space.xl, top = Space.md, bottom = Space.xxl),
            verticalArrangement = Arrangement.spacedBy(Space.lg),
        ) {
            SheetGrabber()
            Column(verticalArrangement = Arrangement.spacedBy(Space.sm)) {
                Text("초대 계정으로 로그인", style = YText.h3, color = YColor.textPrimary)
                Text("운영팀이 드린 계정으로만 들어올 수 있어요. 처음이라면 Apple이나 Google로 시작해 주세요.", style = YText.bodyM, color = YColor.textSecondary)
            }
            Column(verticalArrangement = Arrangement.spacedBy(Space.md)) {
                FieldBox("아이디", "invite-아이디", error = false) { focusMod ->
                    BasicTextField(
                        username, { username = it; failed = false },
                        modifier = focusMod.fillMaxWidth(),
                        textStyle = YText.bodyM.copy(color = YColor.textPrimary),
                        cursorBrush = SolidColor(sky().borderFocus),
                        singleLine = true,
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email, imeAction = ImeAction.Next, autoCorrectEnabled = false),
                        keyboardActions = KeyboardActions(onNext = { passwordFocus.requestFocus() }),
                    )
                }
                FieldBox("비밀번호", "invite-비밀번호", error = failed) { focusMod ->
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        BasicTextField(
                            password, { password = it; failed = false },
                            modifier = focusMod.focusRequester(passwordFocus).weight(1f),
                            textStyle = YText.bodyM.copy(color = YColor.textPrimary),
                            cursorBrush = SolidColor(sky().borderFocus),
                            singleLine = true,
                            visualTransformation = if (showPassword) VisualTransformation.None else PasswordVisualTransformation(),
                            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password, imeAction = ImeAction.Go, autoCorrectEnabled = false),
                            keyboardActions = KeyboardActions(onGo = { signIn() }),
                        )
                        Box(Modifier.size(44.dp).noRippleClick { showPassword = !showPassword }, contentAlignment = Alignment.Center) {
                            Icon(
                                painterResource(if (showPassword) R.drawable.icon_eye_off else R.drawable.icon_eye),
                                if (showPassword) "비밀번호 숨기기" else "비밀번호 보기",
                                Modifier.size(20.dp), tint = YColor.textSecondary,
                            )
                        }
                    }
                }
                if (failed) Text("아이디나 비밀번호가 맞지 않아요.", style = YText.caption, color = YColor.dangerText)
            }
            Column(verticalArrangement = Arrangement.spacedBy(Space.md)) {
                PrimaryButton("로그인", enabled = username.isNotEmpty() && password.isNotEmpty() && !working) { signIn() }
                GhostButton("취소", onClick = onClose)
            }
        }
    }
}

/** Figma Text Field: label, then a 48dp slate field with a Cosmos BG and a 1dp border. */
@Composable
private fun FieldBox(label: String, seed: String, error: Boolean, input: @Composable (Modifier) -> Unit) {
    var focused by remember { mutableStateOf(false) }
    val shape = RoundedCornerShape(Radius.md)
    val a = sky()
    Column(verticalArrangement = Arrangement.spacedBy(Space.sm)) {
        Text(label, style = YText.labelS, color = YColor.textSecondary)
        Box(
            Modifier.fillMaxWidth().height(48.dp)
                .background(YColor.bgSurface, shape)
                .cosmos(seed, shape)
                .border(1.dp, if (focused) a.borderFocus else if (error) YColor.dangerText else YColor.borderDefault, shape)
                .padding(start = Space.lg, end = Space.md),
            contentAlignment = Alignment.CenterStart,
        ) {
            input(Modifier.onFocusChanged { focused = it.isFocused })
        }
    }
}

private enum class Term(val label: String, val required: Boolean, val path: String?) {
    Terms("(필수) 이용약관", true, "/terms"),
    Privacy("(필수) 개인정보 처리방침", true, "/privacy"),
    Sensitive("(필수) 심리 일기 수집·이용(민감정보)", true, "/sensitive"),
    Marketing("(선택) 새 기능·혜택 알림", false, null),
}

fun openWeb(context: Context, url: String) {
    CustomTabsIntent.Builder()
        .setDefaultColorSchemeParams(CustomTabColorSchemeParams.Builder().setToolbarColor(YColor.bgCanvas.toArgb()).build())
        .build()
        .launchUrl(context, url.toUri())
}

/** 11 Consent: shown once after the first sign-in. */
@Composable
fun ConsentScreen(model: AppModel) {
    val context = LocalContext.current
    var agreed by remember { mutableStateOf(setOf<Term>()) }
    val all = agreed.size == Term.entries.size
    val canStart = Term.entries.filter { it.required }.all { it in agreed }
    BackHandler { model.signOut() }
    Box(Modifier.fillMaxSize()) {
        StarField()
        Column(Modifier.fillMaxSize().safeDrawingPadding()) {
            TopAppBar("가입 동의", onBack = { model.signOut() })
            Column(
                Modifier.weight(1f).padding(start = Space.xl, end = Space.xl, top = Space.sm, bottom = Space.xl),
                verticalArrangement = Arrangement.spacedBy(Space.lg),
            ) {
                Text("시작하기 전에\n함께 약속할게요", style = YText.h1, color = YColor.textPrimary)
                NoticeBanner("쓴 글은 AI 학습에 쓰이지 않아요. 언제든 모두 삭제할 수 있고, YOUNIYA는 상담이나 진단을 대신하지 않아요.")
                Column {
                    CheckboxRow("전체 동의", all, onToggle = { agreed = if (all) emptySet() else Term.entries.toSet() })
                    Term.entries.forEach { t ->
                        CheckboxRow(
                            t.label, t in agreed,
                            onToggle = { agreed = if (t in agreed) agreed - t else agreed + t },
                            onOpen = t.path?.let { p -> { openWeb(context, "https://youniya.dycdyp.com$p") } },
                        )
                    }
                }
                Spacer(Modifier.weight(1f))
                PrimaryButton("동의하고 시작하기", enabled = canStart) { model.acceptConsent(Term.Marketing in agreed) }
            }
        }
    }
}

/** 21-1 / 21-2 별지기 이름 정하기 (after 11). Checked as it is typed. */
@Composable
fun NicknameScreen(model: AppModel, onBack: () -> Unit, onDone: () -> Unit) {
    val scope = rememberCoroutineScope()
    var name by remember { mutableStateOf("") }
    var result by remember { mutableStateOf<NicknameResult?>(null) }
    var checking by remember { mutableStateOf(false) }
    var saving by remember { mutableStateOf(false) }
    val focus = remember { FocusRequester() }
    val trimmed = name.trim()
    val canSave = result == NicknameResult.Ok && !checking && !saving && trimmed != model.nickname
    val a = sky()

    LaunchedEffect(trimmed) {
        if (trimmed.isEmpty()) { result = null; return@LaunchedEffect }
        checking = true
        delay(400)
        result = model.checkNickname(trimmed)
        checking = false
    }
    LaunchedEffect(Unit) { focus.requestFocus() }
    fun save() {
        saving = true
        scope.launch {
            val r = model.setNickname(trimmed)
            saving = false
            if (r == NicknameResult.Ok) onDone() else result = r
        }
    }
    BackHandler(onBack = onBack)
    Box(Modifier.fillMaxSize()) {
        StarField()
        Column(Modifier.fillMaxSize().safeDrawingPadding()) {
            TopAppBar("가입", onBack = onBack)
            Column(
                Modifier.weight(1f).imePadding().padding(start = Space.xl, end = Space.xl, top = Space.sm, bottom = Space.xl),
                verticalArrangement = Arrangement.spacedBy(Space.lg),
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(Space.sm)) {
                    Text("별지기 이름을 정해 주세요", style = YText.h1, color = YColor.textPrimary)
                    Text("우주 광장에 별을 나누면 이 이름이 함께 보여요. 내가 건넨 별빛 한 줄에도 이 이름이 보여요.", style = YText.bodyM, color = YColor.textSecondary)
                }
                val problem = result as? NicknameResult.Problem
                Column(
                    Modifier.fillMaxWidth()
                        .background(YColor.bgSurface, RoundedCornerShape(Radius.lg))
                        .border(1.2.dp, if (problem != null) YColor.brandWarm else a.borderFocus.copy(alpha = 0.6f), RoundedCornerShape(Radius.lg))
                        .padding(Space.lg),
                    verticalArrangement = Arrangement.spacedBy(Space.xs),
                ) {
                    Text("별지기 이름", style = YText.labelS, color = YColor.textSecondary)
                    Box {
                        if (name.isEmpty()) Text("예: 느린고래", style = YText.h3, color = YColor.textTertiary)
                        BasicTextField(
                            name, { name = it },
                            modifier = Modifier.fillMaxWidth().focusRequester(focus),
                            textStyle = YText.h3.copy(color = YColor.textPrimary),
                            cursorBrush = SolidColor(a.borderFocus),
                            singleLine = true,
                            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done, autoCorrectEnabled = false),
                            keyboardActions = KeyboardActions(onDone = { if (canSave) save() }),
                        )
                    }
                }
                when {
                    problem != null -> Text(problem.why, style = YText.labelS, color = YColor.brandWarm)
                    result == NicknameResult.Ok && trimmed.isNotEmpty() ->
                        Text(if (trimmed == model.nickname) "지금 쓰고 있는 이름이에요" else "✓ 쓸 수 있는 이름이에요 · ${trimmed.length}/12", style = YText.labelS, color = YColor.emotionCalm)
                }
                Column(verticalArrangement = Arrangement.spacedBy(Space.xs)) {
                    listOf("2~12자, 한글·영문·숫자로 정해요.", "다른 별지기와 겹칠 수 없어요.", "실명이나 연락처는 쓰지 않는 게 좋아요.", "30일에 한 번 바꿀 수 있어요.")
                        .forEach { Text("• $it", style = YText.caption, color = YColor.textTertiary) }
                }
                Spacer(Modifier.weight(1f))
                PrimaryButton("이 이름으로 시작하기", enabled = canSave) { save() }
            }
        }
    }
}
