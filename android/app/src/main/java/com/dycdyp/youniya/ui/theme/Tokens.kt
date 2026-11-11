package com.dycdyp.youniya.ui.theme

import androidx.compose.runtime.Composable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.LineHeightStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.dycdyp.youniya.R

/** Figma `Color` collection (same values as the iOS asset catalog). */
object YColor {
    val bgCanvas = Color(0xFF0B0F19)
    val bgSurface = Color(0xFF131A2A)
    val bgSurfaceRaised = Color(0xFF1A2338)
    val borderDefault = Color(0xFF334155)
    val textPrimary = Color(0xFFE2E8F0)
    val textSecondary = Color(0xFF94A3B8)
    val textTertiary = Color(0xFF8090A6)
    val textOnBrand = Color(0xFFFFFFFF)
    val starBright = Color(0xFFFBBF24)
    val starClear = Color(0xFF22D3EE)
    val brandWarm = Color(0xFFEC4899)
    val emotionCalm = Color(0xFF34D399)
    val emotionSorrow = Color(0xFFA5B4FC)
    val emotionAnger = Color(0xFFF87171)
    val emotionInsight = Color(0xFFBEF264)
    val dangerText = Color(0xFFF87171)
    val tintGold = Color(0xFFFBBF24).copy(alpha = 0.12f)
}

/** One 우주의 색 theme (68). Only the free ones exist in v1.0. */
data class SkyAccent(
    val top: Color,
    val bottom: Color,
    val tint: Color,
    val strong: Color,
    val focus: Color,
    val text: Color,
    val glows: Triple<Color, Color, Color>,
    val pressed: Pair<Color, Color>? = null,
) {
    val brandPrimary get() = strong
    val brandPrimaryText get() = text
    val borderFocus get() = focus
    val tintPrimary get() = tint.copy(alpha = 0.16f)
    val tintPrimarySoft get() = tint.copy(alpha = 0.12f)
}

object SkyThemes {
    val violet = SkyAccent(
        top = Color(0xFF855ADE), bottom = Color(0xFF6630CE), tint = Color(0xFF8B5CF6),
        strong = Color(0xFF8555EF), focus = Color(0xFFA78BFA), text = Color(0xFF9C74F7),
        glows = Triple(Color(0xFF8B5CF6), Color(0xFFEC4899), Color(0xFF33B5D9)),
        pressed = Color(0xFF7A4DD0) to Color(0xFF5C1FC0),
    )
    val ocean = SkyAccent(
        top = Color(0xFF3672D5), bottom = Color(0xFF004ED2), tint = Color(0xFF3B82F6),
        strong = Color(0xFF2970E3), focus = Color(0xFF60A5FA), text = Color(0xFF4A8BF7),
        glows = Triple(Color(0xFF3B82F6), Color(0xFF6366F1), Color(0xFF22D3EE)),
    )
}

val LocalSky = staticCompositionLocalOf { SkyThemes.violet }
/** System "animation off" or the app's 애니메이션 줄이기 (87). */
val LocalMotionReduced = staticCompositionLocalOf { false }

object Space {
    val xs = 4.dp
    val sm = 8.dp
    val md = 12.dp
    val lg = 16.dp
    val xl = 24.dp
    val xxl = 32.dp
    val xxxl = 48.dp
}

object Radius {
    val sm = 8.dp
    val md = 12.dp
    val lg = 16.dp
    val xl = 24.dp
}

val Pretendard = FontFamily(
    Font(R.font.pretendard_light, FontWeight.Light),
    Font(R.font.pretendard_regular, FontWeight.Normal),
    Font(R.font.pretendard_medium, FontWeight.Medium),
)

val NotoSerifKR = FontFamily(
    Font(R.font.notoserifkr_regular, FontWeight.Normal),
    Font(R.font.notoserifkr_medium, FontWeight.Medium),
    Font(R.font.notoserifkr_semibold, FontWeight.SemiBold),
)

/** Figma text styles, as on iOS (TextStyle in Theme.swift): size, line height, tracking. */
object YText {
    private fun style(family: FontFamily, weight: FontWeight, size: Float, line: Float, tracking: Float) = TextStyle(
        fontFamily = family,
        fontWeight = weight,
        fontSize = size.sp,
        lineHeight = line.sp,
        letterSpacing = tracking.sp,
        lineHeightStyle = LineHeightStyle(LineHeightStyle.Alignment.Center, LineHeightStyle.Trim.None),
    )

    val display = style(NotoSerifKR, FontWeight.SemiBold, 40f, 52f, 3.2f)
    val metric = style(Pretendard, FontWeight.Light, 56f, 64f, -1f)
    val h1 = style(NotoSerifKR, FontWeight.SemiBold, 28f, 38f, -0.3f)
    val h2 = style(NotoSerifKR, FontWeight.Medium, 22f, 32f, -0.2f)
    val h3 = style(NotoSerifKR, FontWeight.Medium, 18f, 28f, 0f)
    val journalBody = style(NotoSerifKR, FontWeight.Normal, 16f, 30f, 0f)
    val observation = style(NotoSerifKR, FontWeight.Normal, 15f, 24f, 0f)
    val bodyM = style(Pretendard, FontWeight.Normal, 14f, 22f, 0f)
    val bodyS = style(Pretendard, FontWeight.Normal, 13f, 20f, 0f)
    val labelM = style(Pretendard, FontWeight.Medium, 14f, 20f, 0f)
    val labelS = style(Pretendard, FontWeight.Medium, 12f, 16f, 0.2f)
    val caption = style(Pretendard, FontWeight.Normal, 12f, 18f, 0.2f)
    val captionTab = style(Pretendard, FontWeight.Normal, 12f, 16f, 0f)
}

@Composable
fun sky(): SkyAccent = LocalSky.current
