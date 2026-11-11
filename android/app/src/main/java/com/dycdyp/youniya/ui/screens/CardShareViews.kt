package com.dycdyp.youniya.ui.screens

import kotlinx.coroutines.launch
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.unit.Density
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.graphics.layer.drawLayer
import androidx.compose.ui.graphics.rememberGraphicsLayer
import android.app.Activity
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.view.View
import android.view.ViewGroup
import android.widget.Toast
import androidx.compose.foundation.Canvas
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
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.requiredSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.FileProvider
import com.dycdyp.youniya.R
import com.dycdyp.youniya.data.AppModel
import com.dycdyp.youniya.data.MonthConstellation
import com.dycdyp.youniya.data.Mood
import com.dycdyp.youniya.data.StarItem
import com.dycdyp.youniya.data.StarShapeSpec
import com.dycdyp.youniya.ui.components.ConstellationFigureView
import com.dycdyp.youniya.ui.components.GhostButton
import com.dycdyp.youniya.ui.components.MoodTag
import com.dycdyp.youniya.ui.components.PrimaryButton
import com.dycdyp.youniya.ui.components.SecondaryButton
import com.dycdyp.youniya.ui.components.SheetGrabber
import com.dycdyp.youniya.ui.components.StarlightBadge
import com.dycdyp.youniya.ui.design.ShapeStar
import com.dycdyp.youniya.ui.design.StarField
import com.dycdyp.youniya.ui.theme.LocalMotionReduced
import com.dycdyp.youniya.ui.theme.NotoSerifKR
import com.dycdyp.youniya.ui.theme.Pretendard
import com.dycdyp.youniya.ui.theme.Radius
import com.dycdyp.youniya.ui.theme.Space
import com.dycdyp.youniya.ui.theme.YColor
import com.dycdyp.youniya.ui.theme.YText
import androidx.lifecycle.setViewTreeLifecycleOwner
import androidx.lifecycle.setViewTreeViewModelStoreOwner
import androidx.savedstate.setViewTreeSavedStateRegistryOwner
import com.dycdyp.youniya.ui.theme.sky
import java.io.File
import java.io.FileOutputStream
import java.time.Instant
import java.time.OffsetDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

object ShareCard {
    val Width: Dp = 360.dp
    val Height: Dp = 640.dp
}

// MARK: - 12-14 별 카드 이미지

@Composable
fun StarShareCard(
    model: AppModel,
    star: StarItem,
    withTitle: Boolean,
    modifier: Modifier = Modifier,
) {
    val date = star.parsedDate
    val monthKey = MonthConstellation.monthKey(date)
    val c = model.constellation(monthKey)
    val dayText = formatKstMonthDay(star.createdAt)
    val constTitle = c.title.replace(" · ", " ")
    val topLine = "$dayText · $constTitle"

    val moods = remember(star) {
        val list = (star.analysis?.tones ?: star.allMoods).distinct()
        list.take(3)
    }

    Box(
        modifier = modifier
            .size(ShareCard.Width, ShareCard.Height)
            .clip(RoundedCornerShape(0.dp)),
    ) {
        StarField()

        // Top line & title
        Column(
            modifier = Modifier.fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                text = topLine,
                style = YText.caption,
                color = YColor.textTertiary,
                modifier = Modifier.padding(top = 64.dp),
            )
            if (withTitle) {
                Text(
                    text = star.title,
                    fontFamily = NotoSerifKR,
                    fontWeight = FontWeight.SemiBold,
                    fontSize = 20.sp,
                    letterSpacing = (-0.06).sp,
                    color = YColor.textPrimary.copy(alpha = 0.9f),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    textAlign = TextAlign.Center,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = Space.xl)
                        .padding(top = 18.dp),
                )
            }
        }

        // Star Mark at (180, 300) center
        Box(
            modifier = Modifier
                .size(120.dp)
                .offset(x = 180.dp - 60.dp, y = 300.dp - 60.dp),
            contentAlignment = Alignment.Center,
        ) {
            if (star.isFloated) {
                ShapeStar(
                    spec = star.shape ?: StarShapeSpec(5, StarShapeSpec.Sharpness.normal),
                    color = star.mood.color,
                    size = 120.dp,
                    halo = true,
                )
            } else {
                Canvas(modifier = Modifier.size(56.dp)) {
                    drawCircle(
                        brush = Brush.radialGradient(
                            0f to star.mood.color,
                            1f to star.mood.color.copy(alpha = 0f),
                            center = center,
                            radius = 28.dp.toPx(),
                        ),
                        radius = 28.dp.toPx(),
                    )
                    drawCircle(
                        color = Color.White.copy(alpha = 0.9f),
                        radius = 4.dp.toPx(),
                    )
                }
            }
        }

        // Starlight & Mood tags at y=430
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 430.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(Space.md),
        ) {
            if (star.isFloated && star.starlight != null) {
                StarlightBadge(value = star.starlight)
            } else {
                Text(
                    text = "별빛 없는 별",
                    style = YText.labelS,
                    color = YColor.textSecondary,
                )
            }

            Row(horizontalArrangement = Arrangement.spacedBy(Space.sm)) {
                moods.forEach { mood ->
                    MoodTag(mood = mood)
                }
            }
        }

        CardFooter(modifier = Modifier.align(Alignment.BottomCenter))
    }
}

// MARK: - 08-9 별자리 완성 카드 이미지

@Composable
fun ConstellationShareCard(
    model: AppModel,
    constellation: MonthConstellation,
    modifier: Modifier = Modifier,
) {
    val c = constellation
    val titleText = formatMonthTitle(c.month)

    val shapesMap = remember(c, model.stars) {
        val map = mutableMapOf<String, StarShapeSpec>()
        for (s in c.stars) {
            val shape = s.shape ?: model.stars.firstOrNull { it.id == s.id }?.shape
            if (shape != null) map[s.id] = shape
        }
        map
    }

    Box(
        modifier = modifier
            .size(ShareCard.Width, ShareCard.Height)
            .clip(RoundedCornerShape(0.dp)),
    ) {
        StarField()

        // Top line
        Text(
            text = titleText,
            style = YText.caption,
            color = YColor.textTertiary,
            modifier = Modifier
                .align(Alignment.TopCenter)
                .padding(top = 64.dp),
        )

        // Constellation Figure across the top (360x320) at y = 88
        Box(
            modifier = Modifier
                .size(360.dp, 320.dp)
                .offset(y = 88.dp)
                .padding(horizontal = 6.dp, vertical = 18.dp),
        ) {
            ConstellationFigureView(
                constellation = c,
                shapes = shapesMap,
            )
        }

        // Text & progress at y = 418
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 418.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                text = c.name,
                fontFamily = NotoSerifKR,
                fontWeight = FontWeight.SemiBold,
                fontSize = 30.sp,
                color = YColor.textPrimary,
                modifier = Modifier.height(38.dp),
            )

            val countText = if (c.isComplete) {
                "${c.total}자리를 모두 채웠어요 · 별 ${c.stars.size}개"
            } else {
                "${c.total}자리 중 ${c.filled}자리를 채웠어요 · 별 ${c.stars.size}개"
            }
            Text(
                text = countText,
                fontFamily = Pretendard,
                fontSize = 14.sp,
                color = YColor.textTertiary.copy(alpha = 0.85f),
                modifier = Modifier.padding(top = 8.dp),
            )

            // Progress capsule
            val progressFraction = (c.filled.toFloat() / maxOf(1, c.total).toFloat()).coerceIn(0f, 1f)
            Box(
                modifier = Modifier
                    .padding(top = 14.dp)
                    .width(200.dp)
                    .height(4.dp)
                    .clip(CircleShape)
                    .background(Color.White.copy(alpha = 0.15f)),
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth(progressFraction)
                        .height(4.dp)
                        .clip(CircleShape)
                        .background(YColor.starBright),
                )
            }
        }

        CardFooter(modifier = Modifier.align(Alignment.BottomCenter))
    }
}

// MARK: - Footer

@Composable
private fun CardFooter(modifier: Modifier = Modifier) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(bottom = 32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            text = "YOUNIYA",
            fontFamily = NotoSerifKR,
            fontWeight = FontWeight.SemiBold,
            fontSize = 18.sp,
            letterSpacing = 2.16.sp,
            color = YColor.textPrimary,
            modifier = Modifier.height(30.dp),
        )
        Text(
            text = "쓴 마음이 별이 되는 밤하늘 일기",
            style = YText.caption,
            color = YColor.textTertiary,
        )
    }
}

// MARK: - 12-13 / 08-9 공유 시트

@Composable
fun CardShareSheetContent(
    title: String,
    withTitle: Boolean? = null,
    onTitleToggle: ((Boolean) -> Unit)? = null,
    onInstagram: (Bitmap) -> Unit,
    onSaveImage: (Bitmap) -> Unit,
    onOtherApps: (Bitmap) -> Unit,
    cardPreview: @Composable () -> Unit,
    modifier: Modifier = Modifier,
) {
    val capture = rememberGraphicsLayer()
    val captureScope = rememberCoroutineScope()
    fun withCard(action: (Bitmap) -> Unit) {
        captureScope.launch { action(capture.toImageBitmap().asAndroidBitmap()) }
    }
    val a = sky()

    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = Space.xl)
            .padding(top = Space.md, bottom = Space.xxl),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(Space.lg),
    ) {
        SheetGrabber()

        Column(
            modifier = Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(Space.sm),
        ) {
            Text(title, style = YText.h3, color = YColor.textPrimary, modifier = Modifier.semantics { heading() })
            Text("글은 담기지 않아요. 별 모양·별빛·날짜·마음만 담겨요.", style = YText.bodyM, color = YColor.textSecondary)
        }

        // Preview (180x320)
        Box(
            modifier = Modifier
                .size(180.dp, 320.dp)
                .dropShadow(RoundedCornerShape(Radius.lg), Shadow(radius = 16.dp, color = a.brandPrimary.copy(alpha = 0.35f)))
                .clip(RoundedCornerShape(Radius.lg))
                .border(1.dp, Color.White.copy(alpha = 0.28f), RoundedCornerShape(Radius.lg)),
            contentAlignment = Alignment.Center,
        ) {
            // The card is laid out at 360×640 with a density of 3, so it is exactly 1080×1920 px (iOS renders
            // at scale 3); it is drawn at half size here, and the same drawing is recorded for the image.
            val real = LocalDensity.current.density
            CompositionLocalProvider(LocalDensity provides Density(3f, 1f), LocalMotionReduced provides true) {
                Box(
                    modifier = Modifier
                        .requiredSize(ShareCard.Width, ShareCard.Height)
                        .graphicsLayer {
                            scaleX = real * 0.5f / 3f
                            scaleY = real * 0.5f / 3f
                        }
                        .drawWithContent {
                            capture.record { this@drawWithContent.drawContent() }
                            drawLayer(capture)
                        },
                ) {
                    cardPreview()
                }
            }
        }

        // Title Switch row if star card
        if (withTitle != null && onTitleToggle != null) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = Space.sm),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(Space.md),
                ) {
                    Icon(
                        painter = painterResource(R.drawable.icon_pencil),
                        contentDescription = null,
                        modifier = Modifier.size(22.dp),
                        tint = YColor.textSecondary,
                    )
                    Text("별 제목 넣기", style = YText.bodyM, color = YColor.textPrimary)
                }

                Switch(
                    checked = withTitle,
                    onCheckedChange = onTitleToggle,
                    colors = SwitchDefaults.colors(
                        checkedThumbColor = Color.White,
                        checkedTrackColor = a.brandPrimary,
                        uncheckedThumbColor = YColor.textTertiary,
                        uncheckedTrackColor = YColor.bgSurfaceRaised,
                    ),
                )
            }
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(1.dp)
                    .background(YColor.borderDefault),
            )
        }

        // 3 Action Buttons
        Column(
            modifier = Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(Space.md),
        ) {
            if (CardShareUtil.instagramAvailable(LocalContext.current)) {
                PrimaryButton(text = "인스타그램 스토리에 공유", onClick = { withCard(onInstagram) })
            }
            SecondaryButton(text = "이미지로 저장", onClick = { withCard(onSaveImage) })
            GhostButton(text = "다른 앱으로 공유", onClick = { withCard(onOtherApps) })
        }
    }
}

// MARK: - Utilities for bitmap & sharing

object CardShareUtil {
    fun saveBitmapToCache(context: Context, bitmap: Bitmap, name: String = "youniya_card_${System.currentTimeMillis()}.png"): Uri {
        val imagesFolder = File(context.cacheDir, "shared_images").apply { mkdirs() }
        val file = File(imagesFolder, name)
        FileOutputStream(file).use { out ->
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
        }
        return FileProvider.getUriForFile(
            context,
            "${context.packageName}.fileprovider",
            file,
        )
    }

    /**
     * Instagram Stories with the card as the background image (iOS InstagramStories). Meta requires a
     * Facebook App ID as `source_application`; without one, or without Instagram, the button is hidden.
     */
    fun instagramAvailable(context: Context): Boolean =
        com.dycdyp.youniya.BuildConfig.INSTAGRAM_APP_ID.isNotBlank() &&
            context.packageManager.getLaunchIntentForPackage("com.instagram.android") != null

    fun shareToInstagramStories(context: Context, imageUri: Uri): Boolean {
        if (!instagramAvailable(context)) return false
        val intent = Intent("com.instagram.share.ADD_TO_STORY").apply {
            putExtra("source_application", com.dycdyp.youniya.BuildConfig.INSTAGRAM_APP_ID)
            setDataAndType(imageUri, "image/png")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        context.grantUriPermission("com.instagram.android", imageUri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
        return runCatching { context.startActivity(intent) }.isSuccess
    }

    fun saveToGallery(context: Context, bitmap: Bitmap): Boolean {
        return try {
            val filename = "YOUNIYA_${System.currentTimeMillis()}.png"
            val resolver = context.contentResolver
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val values = ContentValues().apply {
                    put(MediaStore.Images.Media.DISPLAY_NAME, filename)
                    put(MediaStore.Images.Media.MIME_TYPE, "image/png")
                    put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/YOUNIYA")
                    put(MediaStore.Images.Media.IS_PENDING, 1)
                }
                val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values) ?: return false
                resolver.openOutputStream(uri)?.use { out ->
                    bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
                }
                values.clear()
                values.put(MediaStore.Images.Media.IS_PENDING, 0)
                resolver.update(uri, values, null, null)
            } else {
                @Suppress("DEPRECATION")
                val picturesDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES)
                val youniyaDir = File(picturesDir, "YOUNIYA").apply { mkdirs() }
                val file = File(youniyaDir, filename)
                FileOutputStream(file).use { out ->
                    bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
                }
                val values = ContentValues().apply {
                    @Suppress("DEPRECATION")
                    put(MediaStore.Images.Media.DATA, file.absolutePath)
                    put(MediaStore.Images.Media.MIME_TYPE, "image/png")
                }
                resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
            }
            Toast.makeText(context, "이미지로 저장했어요", Toast.LENGTH_SHORT).show()
            true
        } catch (_: Exception) {
            Toast.makeText(context, "저장하지 못했어요", Toast.LENGTH_SHORT).show()
            false
        }
    }

    fun shareToOtherApps(context: Context, imageUri: Uri, title: String) {
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "image/png"
            putExtra(Intent.EXTRA_STREAM, imageUri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        context.startActivity(Intent.createChooser(intent, title))
    }
}

private fun formatKstMonthDay(iso: String?): String {
    if (iso.isNullOrBlank()) return ""
    return try {
        val zdt = Instant.parse(iso).atZone(ZoneId.of("Asia/Seoul"))
        DateTimeFormatter.ofPattern("M월 d일", Locale.KOREAN).format(zdt)
    } catch (_: Exception) {
        try {
            val odt = OffsetDateTime.parse(iso).atZoneSameInstant(ZoneId.of("Asia/Seoul"))
            DateTimeFormatter.ofPattern("M월 d일", Locale.KOREAN).format(odt)
        } catch (_: Exception) {
            ""
        }
    }
}

private fun formatMonthTitle(month: String): String {
    val parts = month.split("-")
    if (parts.size != 2) return "이달의 별자리"
    val m = parts[1].toIntOrNull() ?: return "이달의 별자리"
    return "${parts[0]}년 ${m}월 · 별자리 완성"
}
