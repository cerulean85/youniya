package com.dycdyp.youniya.ui.screens

import android.app.Activity
import android.content.Context
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.requiredSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
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
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.dycdyp.youniya.data.AppModel
import com.dycdyp.youniya.ui.components.FlowTopBar
import com.dycdyp.youniya.ui.components.GhostButton
import com.dycdyp.youniya.ui.components.PrimaryButton
import com.dycdyp.youniya.ui.design.StarField
import com.dycdyp.youniya.ui.theme.Radius
import com.dycdyp.youniya.ui.theme.Space
import com.dycdyp.youniya.ui.theme.YColor
import com.dycdyp.youniya.ui.theme.YText

import com.dycdyp.youniya.ui.theme.sky

/**
 * 08-10 (568:15248): shown once a month after the card of the star that
 * filled the last place. 「별자리 카드로 나누기」 opens the 08-9 sheet.
 */
@Composable
fun ConstellationCompleteView(
    model: AppModel,
    month: String,
    onClose: () -> Unit = {},
    onShowNebula: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val activity = context as? Activity
    val c = model.constellation(month)
    val a = sky()
    var showShareSheet by remember { mutableStateOf(false) }

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(Color.Black.copy(alpha = 0.55f)),
    ) {
        StarField()
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Color.Black.copy(alpha = 0.55f)),
        )

        Column(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .navigationBarsPadding()
                .padding(horizontal = Space.xl)
                .padding(bottom = Space.lg),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(Space.lg),
        ) {
            FlowTopBar(title = "", onClose = onClose)

            Text(
                text = "${c.name}를 완성했어요",
                style = YText.h2,
                color = YColor.textPrimary,
                textAlign = TextAlign.Center,
                modifier = Modifier.semantics { heading() },
            )

            // Scaled Card preview (scale 0.72 -> 259.2 x 460.8)
            Box(
                modifier = Modifier
                    .size((360 * 0.72f).dp, (640 * 0.72f).dp)
                    .dropShadow(RoundedCornerShape(20.dp), Shadow(radius = 24.dp, color = a.brandPrimary.copy(alpha = 0.45f)))
                    .clip(RoundedCornerShape(20.dp))
                    .border(1.dp, Color.White.copy(alpha = 0.28f), RoundedCornerShape(20.dp)),
                contentAlignment = Alignment.Center,
            ) {
                Box(
                    modifier = Modifier
                        .requiredSize(ShareCard.Width, ShareCard.Height)
                        .graphicsLayer {
                            scaleX = 0.72f
                            scaleY = 0.72f
                        },
                ) {
                    ConstellationShareCard(model = model, constellation = c)
                }
            }

            Text(
                text = "${c.monthLabel}에 띄운 별 ${c.stars.size}개가 ${c.name}를 모두 채웠어요.",
                style = YText.bodyM,
                color = YColor.textSecondary,
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth(),
            )

            Spacer(modifier = Modifier.weight(1f))

            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(Space.sm),
            ) {
                PrimaryButton(text = "별자리 카드로 나누기", onClick = { showShareSheet = true })
                GhostButton(text = "별자리 보기", onClick = onShowNebula)
            }
        }

        if (showShareSheet) {
            YouniyaSheet(seed = "constellation-share", onDismiss = { showShareSheet = false }) {
                CardShareSheetContent(
                    title = "별자리 카드로 나누기",
                    cardPreview = {
                        ConstellationShareCard(model = model, constellation = c)
                    },
                    onInstagram = { bitmap ->
                        run {
                                                        val uri = CardShareUtil.saveBitmapToCache(context, bitmap)
                            CardShareUtil.shareToInstagramStories(context, uri)
                        }
                        showShareSheet = false
                    },
                    onSaveImage = { bitmap ->
                        run {
                                                        CardShareUtil.saveToGallery(context, bitmap)
                        }
                        showShareSheet = false
                    },
                    onOtherApps = { bitmap ->
                        run {
                                                        val uri = CardShareUtil.saveBitmapToCache(context, bitmap)
                            CardShareUtil.shareToOtherApps(context, uri, "별자리 카드로 나누기")
                        }
                        showShareSheet = false
                    },
                )
            }
        }
    }
}

object ConstellationCompleteTracker {
    private fun key(month: String) = "constellationCompleteShown.$month"

    fun wasShown(context: Context, month: String): Boolean {
        val prefs = context.getSharedPreferences("constellation_complete", Context.MODE_PRIVATE)
        return prefs.getBoolean(key(month), false)
    }

    fun markShown(context: Context, month: String) {
        val prefs = context.getSharedPreferences("constellation_complete", Context.MODE_PRIVATE)
        prefs.edit().putBoolean(key(month), true).apply()
    }
}
