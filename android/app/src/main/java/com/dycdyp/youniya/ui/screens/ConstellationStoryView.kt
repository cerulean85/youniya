package com.dycdyp.youniya.ui.screens

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import com.dycdyp.youniya.R
import com.dycdyp.youniya.data.AppModel
import com.dycdyp.youniya.data.MonthConstellation
import com.dycdyp.youniya.data.ServerStory
import com.dycdyp.youniya.data.StarItem
import com.dycdyp.youniya.ui.components.TopAppBar
import com.dycdyp.youniya.ui.components.noRippleClick
import com.dycdyp.youniya.ui.design.StarField
import com.dycdyp.youniya.ui.design.cosmos
import com.dycdyp.youniya.ui.theme.Radius
import com.dycdyp.youniya.ui.theme.Space
import com.dycdyp.youniya.ui.theme.YColor
import com.dycdyp.youniya.ui.theme.YText
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import java.util.Locale

data class StoryLine(
    val star: StarItem,
    val sentence: String,
)

/**
 * 83 별자리 이야기 (iOS NebulaStoryView):
 * one core sentence per star, oldest first, left as written.
 */
@Composable
fun ConstellationStoryView(
    model: AppModel,
    month: String,
    onBack: () -> Unit,
    onOpenStar: (StarItem) -> Unit,
    modifier: Modifier = Modifier,
) {
    var serverStory by remember { mutableStateOf<ServerStory?>(null) }

    LaunchedEffect(month) {
        val story = model.loadConstellationStory(month)
        if (story != null) {
            serverStory = story
        }
    }

    val monthStars = remember(model.stars, month) {
        model.stars.filter { star ->
            star.parsedDate?.let { MonthConstellation.monthKey(it) } == month
        }
    }

    val lines: List<StoryLine> = remember(serverStory, monthStars, model.stars) {
        if (serverStory != null) {
            serverStory!!.entries.mapNotNull { entry ->
                val star = model.stars.firstOrNull { it.id == entry.starId } ?: return@mapNotNull null
                StoryLine(star = star, sentence = entry.sentence)
            }
        } else {
            monthStars
                .sortedBy { it.parsedDate ?: ZonedDateTime.now() }
                .mapNotNull { star ->
                    val parts = star.body
                        .split('.', '!', '?', '。', '\n')
                        .map { it.trim() }
                        .filter { it.isNotEmpty() }
                    val last = parts.lastOrNull() ?: return@mapNotNull null
                    val end = if (star.body.contains("$last.")) "." else if (star.body.contains("$last?")) "?" else ""
                    StoryLine(star = star, sentence = last + end)
                }
        }
    }

    val earliestDate = monthStars.mapNotNull { it.parsedDate }.minOrNull()
    val tagText = if (earliestDate != null) {
        val f = DateTimeFormatter.ofPattern("M월 d일", Locale.KOREAN)
        "별 ${monthStars.size} · ${f.format(earliestDate)}부터"
    } else {
        "별 ${monthStars.size}"
    }

    Box(modifier = modifier.fillMaxSize()) {
        StarField()

        Column(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding(),
        ) {
            TopAppBar(title = "별자리 이야기", onBack = onBack)

            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = Space.xl, vertical = Space.lg),
                verticalArrangement = Arrangement.spacedBy(Space.lg),
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .semantics(mergeDescendants = true) { heading() },
                    verticalArrangement = Arrangement.spacedBy(Space.xs),
                ) {
                    Text(
                        text = "${model.constellation(month).title} 이야기",
                        style = YText.h2,
                        color = YColor.textPrimary,
                    )
                    Text(
                        text = "별마다 고른 핵심 문장을 시간순으로 엮었어요. 원문 문장은 한 글자도 바꾸지 않아요.",
                        style = YText.bodyM,
                        color = YColor.textSecondary,
                    )
                }

                // Tag
                Box(
                    modifier = Modifier
                        .clip(CircleShape)
                        .background(YColor.tintGold)
                        .padding(horizontal = Space.md, vertical = Space.xs),
                ) {
                    Text(
                        text = tagText,
                        style = YText.labelS,
                        color = YColor.starBright,
                    )
                }

                if (lines.isEmpty()) {
                    Text(
                        text = "글이 있는 별을 띄우면 이야기가 엮여요.",
                        style = YText.bodyM,
                        color = YColor.textSecondary,
                    )
                } else {
                    StoryCard(
                        lines = lines,
                        onOpenStar = onOpenStar,
                    )
                }
            }
        }
    }
}

@Composable
private fun StoryCard(
    lines: List<StoryLine>,
    onOpenStar: (StarItem) -> Unit,
    modifier: Modifier = Modifier,
) {
    val shape = RoundedCornerShape(Radius.lg)

    Column(
        modifier = modifier
            .fillMaxWidth()
            .cosmos("story", shape)
            .background(YColor.bgSurface, shape)
            .border(1.dp, YColor.borderDefault, shape)
            .padding(horizontal = Space.lg, vertical = 20.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        lines.forEachIndexed { i, line ->
            if (i > 0) {
                Text(
                    text = "✦",
                    style = YText.labelS,
                    color = YColor.starBright,
                    modifier = Modifier.align(Alignment.CenterHorizontally),
                )
            }

            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .noRippleClick { onOpenStar(line.star) },
                verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(2.dp),
                ) {
                    Text(
                        text = "${line.star.shortDateText} · ${line.star.title}",
                        style = YText.caption,
                        color = YColor.textTertiary,
                    )
                    Image(
                        painter = painterResource(R.drawable.icon_chevron_right),
                        contentDescription = null,
                        modifier = Modifier.size(12.dp),
                    )
                }

                Text(
                    text = "“${line.sentence}”",
                    style = YText.bodyM,
                    color = YColor.textPrimary,
                )
            }
        }
    }
}
