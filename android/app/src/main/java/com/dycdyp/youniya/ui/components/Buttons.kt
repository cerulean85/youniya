package com.dycdyp.youniya.ui.components

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.dycdyp.youniya.R
import com.dycdyp.youniya.ui.design.cosmos
import com.dycdyp.youniya.ui.theme.Radius
import com.dycdyp.youniya.ui.theme.Space
import com.dycdyp.youniya.ui.theme.YColor
import com.dycdyp.youniya.ui.theme.YText
import com.dycdyp.youniya.ui.theme.sky

private val ButtonShape = RoundedCornerShape(Radius.md)

/** A clickable with no ripple (the app has no Material ripple, as on iOS) that reports pressed. */
@Composable
private fun Modifier.pressable(enabled: Boolean, role: Role = Role.Button, onClick: () -> Unit, source: MutableInteractionSource): Modifier =
    this.clickable(interactionSource = source, indication = null, enabled = enabled, role = role, onClick = onClick)

/** Figma Button/Primary: theme gradient, 48dp, radius 12, the tint's glow (Figma blur 24). */
@Composable
fun PrimaryButton(text: String, modifier: Modifier = Modifier, enabled: Boolean = true, onClick: () -> Unit) {
    val a = sky()
    val source = remember { MutableInteractionSource() }
    val pressed by source.collectIsPressedAsState()
    val colors = if (pressed) (a.pressed?.toList() ?: listOf(a.bottom, a.bottom)) else listOf(a.top, a.bottom)
    Box(
        modifier
            .fillMaxWidth()
            .heightIn(min = 48.dp)
            .then(if (enabled) Modifier.dropShadow(ButtonShape, Shadow(radius = 24.dp, color = a.tint.copy(alpha = 0.4f))) else Modifier)
            .background(if (enabled) Brush.verticalGradient(colors) else Brush.linearGradient(listOf(YColor.borderDefault, YColor.borderDefault)), ButtonShape)
            .pressable(enabled, onClick = onClick, source = source)
            .padding(horizontal = Space.xl, vertical = Space.md),
        contentAlignment = Alignment.Center,
    ) {
        Text(text, style = YText.labelM, color = if (enabled) YColor.textOnBrand else YColor.textSecondary, textAlign = TextAlign.Center)
    }
}

/** Figma Button/Secondary: outlined in brand/primary over a faint Cosmos BG. */
@Composable
fun SecondaryButton(text: String, modifier: Modifier = Modifier, enabled: Boolean = true, onClick: () -> Unit) {
    val a = sky()
    val source = remember { MutableInteractionSource() }
    val pressed by source.collectIsPressedAsState()
    Box(
        modifier
            .fillMaxWidth()
            .heightIn(min = 48.dp)
            .alpha(if (enabled) 1f else 0.4f)
            .cosmos("secondary", ButtonShape, intensity = 0.55)
            .background(if (pressed) a.tintPrimary else Color.Transparent, ButtonShape)
            .border(1.dp, a.brandPrimary, ButtonShape)
            .pressable(enabled, onClick = onClick, source = source)
            .padding(horizontal = Space.xl, vertical = Space.md),
        contentAlignment = Alignment.Center,
    ) {
        Text(text, style = YText.labelM, color = a.brandPrimary, textAlign = TextAlign.Center)
    }
}

/** Figma Button/Ghost: text only, text/secondary. */
@Composable
fun GhostButton(text: String, modifier: Modifier = Modifier, compact: Boolean = false, onClick: () -> Unit) {
    val source = remember { MutableInteractionSource() }
    val pressed by source.collectIsPressedAsState()
    Box(
        modifier
            .fillMaxWidth()
            .heightIn(min = 48.dp)
            .alpha(if (pressed) 0.6f else 1f)
            .pressable(true, onClick = onClick, source = source)
            .padding(horizontal = if (compact) Space.xs else Space.xl, vertical = Space.md),
        contentAlignment = Alignment.Center,
    ) {
        Text(text, style = YText.labelM, color = YColor.textSecondary, maxLines = 1, textAlign = TextAlign.Center)
    }
}

/** Figma Button/Danger: red gradient for what can't be undone. */
@Composable
fun DangerButton(text: String, modifier: Modifier = Modifier, enabled: Boolean = true, onClick: () -> Unit) {
    val source = remember { MutableInteractionSource() }
    val pressed by source.collectIsPressedAsState()
    Box(
        modifier
            .fillMaxWidth()
            .heightIn(min = 48.dp)
            .alpha(if (!enabled) 0.4f else if (pressed) 0.85f else 1f)
            .dropShadow(ButtonShape, Shadow(radius = 24.dp, color = Color(0xFFF87171).copy(alpha = 0.4f)))
            .background(Brush.verticalGradient(listOf(Color(0xFFBC5457), Color(0xFFA5202A))), ButtonShape)
            .pressable(enabled, onClick = onClick, source = source)
            .padding(horizontal = Space.xl, vertical = Space.md),
        contentAlignment = Alignment.Center,
    ) {
        Text(text, style = YText.labelM, color = Color.White, textAlign = TextAlign.Center)
    }
}

enum class SocialProvider { Apple, Google }

/** Figma Social Button: Apple light, Google slate with a Cosmos BG; 52dp. */
@Composable
fun SocialButton(provider: SocialProvider, modifier: Modifier = Modifier, onClick: () -> Unit) {
    val source = remember { MutableInteractionSource() }
    val pressed by source.collectIsPressedAsState()
    val apple = provider == SocialProvider.Apple
    Row(
        modifier
            .fillMaxWidth()
            .height(52.dp)
            .alpha(if (pressed) 0.85f else 1f)
            .then(if (apple) Modifier.background(YColor.textPrimary, ButtonShape)
                  else Modifier.background(YColor.bgSurface, ButtonShape).cosmos("google", ButtonShape).border(1.dp, YColor.borderDefault, ButtonShape))
            .pressable(true, onClick = onClick, source = source),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (apple) {
            Image(painterResource(R.drawable.logo_apple), null, Modifier.size(20.dp))
            Spacer(Modifier.width(Space.sm))
            Text("Apple로 계속하기", style = YText.labelM, color = YColor.bgCanvas)
        } else {
            Image(painterResource(R.drawable.logo_google), null, Modifier.size(18.dp))
            Spacer(Modifier.width(Space.sm))
            Text("Google로 계속하기", style = YText.labelM, color = YColor.textPrimary)
        }
    }
}

/** Figma Menu Button: 40dp circle with three lines. */
@Composable
fun MenuButton(modifier: Modifier = Modifier, onClick: () -> Unit) {
    val source = remember { MutableInteractionSource() }
    Column(
        modifier
            .size(40.dp)
            .background(YColor.bgSurface, CircleShape)
            .border(1.dp, YColor.borderDefault, CircleShape)
            .pressable(true, onClick = onClick, source = source)
            .semantics { contentDescription = "메뉴" },
        verticalArrangement = Arrangement.spacedBy(4.dp, Alignment.CenterVertically),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        repeat(3) { Box(Modifier.size(16.dp, 2.dp).background(YColor.textSecondary, RoundedCornerShape(1.dp))) }
    }
}

/** Figma Top App Bar: 52dp, back icon, centered Label/M title. */
@Composable
fun TopAppBar(title: String, onBack: () -> Unit, modifier: Modifier = Modifier) {
    val source = remember { MutableInteractionSource() }
    Row(modifier.fillMaxWidth().height(52.dp).padding(horizontal = Space.md), verticalAlignment = Alignment.CenterVertically) {
        Box(
            Modifier.size(40.dp).pressable(true, onClick = onBack, source = source).semantics { contentDescription = "뒤로" },
            contentAlignment = Alignment.Center,
        ) {
            Image(painterResource(R.drawable.icon_back), null, Modifier.size(24.dp))
        }
        Text(title, style = YText.labelM, color = YColor.textPrimary, textAlign = TextAlign.Center,
            modifier = Modifier.weight(1f).semantics { heading() })
        Spacer(Modifier.size(40.dp))
    }
}

/** Figma Notice Banner (Info): violet tint, info icon. */
@Composable
fun NoticeBanner(message: String, modifier: Modifier = Modifier, warm: Boolean = false) {
    val a = sky()
    Row(
        modifier.fillMaxWidth().background(if (warm) YColor.tintGold else a.tintPrimarySoft, RoundedCornerShape(Radius.lg)).padding(Space.lg),
        horizontalArrangement = Arrangement.spacedBy(Space.md),
    ) {
        Icon(painterResource(if (warm) R.drawable.icon_star else R.drawable.icon_info), null,
            Modifier.size(20.dp), tint = if (warm) YColor.starBright else a.tint)
        Text(message, style = YText.bodyS, color = YColor.textPrimary, modifier = Modifier.weight(1f))
    }
}

/** Figma Checkbox Row: 22dp rounded box, label, chevron to the full text. */
@Composable
fun CheckboxRow(label: String, checked: Boolean, onToggle: () -> Unit, onOpen: (() -> Unit)? = null) {
    val a = sky()
    val toggleSource = remember { MutableInteractionSource() }
    val openSource = remember { MutableInteractionSource() }
    Row(Modifier.fillMaxWidth().padding(vertical = (Space.md - 5.dp)), verticalAlignment = Alignment.CenterVertically) {
        Row(
            Modifier.weight(1f).pressable(true, Role.Checkbox, onToggle, toggleSource),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(Space.md),
        ) {
            Box(
                Modifier.size(22.dp).then(
                    if (checked) Modifier.background(a.brandPrimary, RoundedCornerShape(6.dp))
                    else Modifier.border(1.5.dp, YColor.borderDefault, RoundedCornerShape(6.dp))
                ),
                contentAlignment = Alignment.Center,
            ) {
                if (checked) Image(painterResource(R.drawable.icon_check), null, Modifier.size(14.dp))
            }
            Text(label, style = YText.bodyM, color = YColor.textPrimary)
        }
        Box(
            Modifier.size(32.dp).pressable(true, onClick = onOpen ?: onToggle, source = openSource)
                .then(if (onOpen != null) Modifier.semantics { contentDescription = "$label 전문 보기" } else Modifier),
            contentAlignment = Alignment.Center,
        ) {
            Icon(painterResource(R.drawable.icon_chevron_right), null, Modifier.size(18.dp), tint = YColor.textTertiary)
        }
    }
}

/** The sheet grabber the iOS sheets draw themselves: 40×4 capsule. */
@Composable
fun SheetGrabber() {
    Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
        Box(Modifier.size(40.dp, 4.dp).background(YColor.borderDefault, RoundedCornerShape(2.dp)))
    }
}

fun Modifier.noRippleClick(onClick: () -> Unit): Modifier = this.then(
    Modifier.clickable(interactionSource = null, indication = null, onClick = onClick)
)

@Suppress("unused")
private val unusedDp: Dp = 0.dp
