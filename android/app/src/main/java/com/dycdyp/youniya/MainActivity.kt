package com.dycdyp.youniya

import android.os.Bundle
import android.provider.Settings
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import com.dycdyp.youniya.data.AppModel
import com.dycdyp.youniya.ui.screens.ConsentScreen
import com.dycdyp.youniya.ui.screens.LoginScreen
import com.dycdyp.youniya.ui.screens.MainScreen
import com.dycdyp.youniya.ui.screens.NicknameScreen
import com.dycdyp.youniya.ui.screens.SplashScreen
import com.dycdyp.youniya.ui.theme.LocalMotionReduced
import com.dycdyp.youniya.ui.theme.SkyThemes
import androidx.compose.foundation.text.selection.LocalTextSelectionColors
import androidx.compose.foundation.text.selection.TextSelectionColors
import com.dycdyp.youniya.ui.theme.Space
import com.dycdyp.youniya.ui.theme.YColor
import com.dycdyp.youniya.ui.theme.YText
import kotlinx.coroutines.delay

class MainActivity : ComponentActivity() {
    private val model: AppModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        val splash = installSplashScreen()
        // AN-01 → AN-01-1: drop the system splash at once; 01 draws the logo at the same spot and moves it.
        splash.setOnExitAnimationListener { it.remove() }
        // Light system-bar icons on the night sky in both system themes.
        enableEdgeToEdge(
            statusBarStyle = SystemBarStyle.dark(android.graphics.Color.TRANSPARENT),
            navigationBarStyle = SystemBarStyle.dark(android.graphics.Color.TRANSPARENT),
        )
        super.onCreate(savedInstanceState)
        val reduced = Settings.Global.getFloat(contentResolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f) == 0f
        setContent {
            // Text cursor handles and selection in the theme's focus color, not Material blue.
            val selection = TextSelectionColors(handleColor = SkyThemes.violet.focus, backgroundColor = SkyThemes.violet.focus.copy(alpha = 0.35f))
            CompositionLocalProvider(LocalMotionReduced provides reduced, LocalTextSelectionColors provides selection) {
                Root(model)
            }
        }
    }
}

private enum class Stage { Splash, Login, Consent, Nickname, Main }

/** iOS YouniyaApp: splash, then login, consent, nickname (once, right after consent), main. */
@Composable
private fun Root(model: AppModel) {
    var splashDone by remember { mutableStateOf(false) }
    val stage = when {
        !splashDone -> Stage.Splash
        !model.isSignedIn -> Stage.Login
        !model.hasConsented -> Stage.Consent
        model.justConsented && model.nickname == null -> Stage.Nickname
        else -> Stage.Main
    }
    Box(Modifier.fillMaxSize().background(YColor.bgCanvas)) {
        AnimatedContent(stage, transitionSpec = { fadeIn() togetherWith fadeOut() }, label = "root") { s ->
            when (s) {
                Stage.Splash -> SplashScreen { splashDone = true }
                Stage.Login -> LoginScreen(model)
                Stage.Consent -> ConsentScreen(model)
                Stage.Nickname -> NicknameScreen(model, onBack = { model.skipNickname() }, onDone = {})
                Stage.Main -> MainScreen(model)
            }
        }
        Toast(model.message) { model.message = null }
    }
}

/** 42 토스트: bottom center, 3 seconds. */
@Composable
private fun Toast(message: String?, onDone: () -> Unit) {
    LaunchedEffect(message) {
        if (message != null) { delay(3000); onDone() }
    }
    if (message == null) return
    Box(Modifier.fillMaxSize().navigationBarsPadding().padding(bottom = 96.dp), contentAlignment = Alignment.BottomCenter) {
        Text(
            message, style = YText.labelM, color = YColor.textPrimary,
            modifier = Modifier.widthIn(max = 342.dp)
                .background(YColor.bgSurfaceRaised, RoundedCornerShape(100.dp))
                .padding(horizontal = Space.lg, vertical = Space.md),
        )
    }
}
