package com.dycdyp.youniya.ui.screens

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.dycdyp.youniya.R
import com.dycdyp.youniya.ui.components.GhostButton
import com.dycdyp.youniya.ui.components.NoticeBanner
import com.dycdyp.youniya.ui.components.PrimaryButton
import com.dycdyp.youniya.ui.design.StarField
import com.dycdyp.youniya.ui.theme.Space
import com.dycdyp.youniya.ui.theme.YColor
import com.dycdyp.youniya.ui.theme.YText
import com.dycdyp.youniya.ui.theme.sky

/**
 * 37 Crisis Care (위기 돌봄, iOS CrisisCareView):
 * shown after saving an entry with crisis signals. Offers 109 line.
 */
@Composable
fun CrisisCareView(
    onContinue: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current

    Box(modifier.fillMaxSize()) {
        StarField()

        Column(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .navigationBarsPadding()
                .padding(Space.xl),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Spacer(Modifier.weight(1f))

            CrisisHero()

            Spacer(Modifier.size(Space.lg))

            Column(
                verticalArrangement = Arrangement.spacedBy(Space.lg),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Text(
                    "지금 많이 힘드신가요?",
                    style = YText.h2,
                    color = YColor.textPrimary,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.semantics { heading() },
                )
                Text(
                    "혼자 견디지 않아도 괜찮아요.\n전문 상담이 24시간 열려 있어요.",
                    style = YText.bodyM,
                    color = YColor.textSecondary,
                    textAlign = TextAlign.Center,
                )
            }

            Spacer(Modifier.size(Space.lg))

            NoticeBanner(message = "자살예방 상담전화 109 (24시간)", warm = true)

            Spacer(Modifier.size(Space.lg))

            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(Space.md),
            ) {
                PrimaryButton("109로 전화하기") {
                    val intent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:109"))
                    context.startActivity(intent)
                }
                GhostButton("괜찮아요, 계속할게요", onClick = onContinue)
            }

            Spacer(Modifier.weight(1f))
        }
    }
}

/**
 * 37 `Hero` (120×120): soft violet orb with heart, two orbits, two stars.
 */
@Composable
private fun CrisisHero() {
    val a = sky()

    Box(
        modifier = Modifier.size(120.dp),
        contentAlignment = Alignment.TopStart,
    ) {
        Box(
            Modifier
                .size(120.dp)
                .alpha(0.3f)
                .border(1.dp, a.brandPrimary, CircleShape),
        )

        Box(
            Modifier
                .offset(x = 14.dp, y = 14.dp)
                .size(92.dp)
                .alpha(0.5f)
                .border(1.dp, a.brandPrimary, CircleShape),
        )

        Box(
            Modifier
                .offset(x = 28.dp, y = 28.dp)
                .size(64.dp)
                .dropShadow(CircleShape, Shadow(radius = 12.dp, color = a.brandPrimary.copy(alpha = 0.4f)))
                .background(a.tintPrimary, CircleShape)
                .border(1.dp, a.borderFocus, CircleShape),
        )

        Image(
            painter = painterResource(R.drawable.icon_heart),
            contentDescription = null,
            colorFilter = ColorFilter.tint(YColor.starBright),
            modifier = Modifier
                .offset(x = 45.dp, y = 45.dp)
                .size(30.dp),
        )

        Box(
            Modifier
                .offset(x = 97.dp, y = 17.dp)
                .size(6.dp)
                .dropShadow(CircleShape, Shadow(radius = 14.dp, color = YColor.starBright.copy(alpha = 0.5f)))
                .background(YColor.starBright, CircleShape),
        )

        Box(
            Modifier
                .offset(x = 12.dp, y = 94.dp)
                .size(5.dp)
                .dropShadow(CircleShape, Shadow(radius = 10.dp, color = YColor.starClear.copy(alpha = 0.4f)))
                .background(YColor.starClear, CircleShape),
        )
    }
}
