package com.dycdyp.youniya.ui.screens

import androidx.compose.ui.semantics.contentDescription
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
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
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Icon
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
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.dycdyp.youniya.R
import com.dycdyp.youniya.data.AppModel
import com.dycdyp.youniya.data.Mood
import com.dycdyp.youniya.data.StarItem
import com.dycdyp.youniya.ui.components.GhostButton
import com.dycdyp.youniya.ui.components.PrimaryButton
import com.dycdyp.youniya.ui.components.StarRow
import com.dycdyp.youniya.ui.components.TopAppBar
import com.dycdyp.youniya.ui.components.noRippleClick
import com.dycdyp.youniya.ui.design.StarField
import com.dycdyp.youniya.ui.design.Twinkle
import com.dycdyp.youniya.ui.design.cosmos
import com.dycdyp.youniya.ui.design.dimScale
import com.dycdyp.youniya.ui.design.twinkle
import com.dycdyp.youniya.ui.theme.Radius
import com.dycdyp.youniya.ui.theme.Space
import com.dycdyp.youniya.ui.theme.YColor
import com.dycdyp.youniya.ui.theme.YText
import com.dycdyp.youniya.ui.theme.sky
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.YearMonth
import java.time.format.DateTimeFormatter
import java.time.format.TextStyle
import java.util.Locale

/** Filters on the records tab (115, 118, iOS RecordsFilter). */
sealed interface RecordsFilter {
    data object All : RecordsFilter
    data object Floated : RecordsFilter
    data object Kept : RecordsFilter
    data class ByMood(val mood: Mood) : RecordsFilter
}

private enum class RecordsMode { List, Calendar }

/**
 * 115 기록 · 목록 / 116 달력 / 117 검색 / 118 간직한 별 / 119 비어 있음.
 * (iOS RecordsView)
 */
@Composable
fun RecordsView(
    model: AppModel,
    onOpenStar: (StarItem) -> Unit,
    onBrightness: () -> Unit,
    onCompose: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var mode by remember { mutableStateOf(RecordsMode.List) }
    var filter by remember { mutableStateOf<RecordsFilter>(RecordsFilter.All) }
    var query by remember { mutableStateOf("") }
    val trimmed = query.trim()

    val filteredStars = remember(model.stars, filter, trimmed) {
        model.stars.filter { s ->
            when (val f = filter) {
                is RecordsFilter.All -> true
                is RecordsFilter.Floated -> s.isFloated
                is RecordsFilter.Kept -> !s.isFloated
                is RecordsFilter.ByMood -> s.mood == f.mood || (s.extraMoods?.contains(f.mood) == true)
            }
        }.filter { s ->
            trimmed.isEmpty() || s.title.contains(trimmed, ignoreCase = true) || s.body.contains(trimmed, ignoreCase = true)
        }
    }

    Column(
        modifier = modifier
            .fillMaxSize()
            .padding(horizontal = Space.xl)
            .padding(top = Space.lg),
        verticalArrangement = Arrangement.spacedBy(Space.lg),
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(Space.xs)) {
            Text("기록", style = YText.h1, color = YColor.textPrimary, modifier = Modifier.semantics { heading() })
            Text(
                if (filter == RecordsFilter.Kept) "별빛 없이 띄운 별 ${model.stars.count { !it.isFloated }}개"
                else "지금까지 띄운 별 ${model.stars.size}개",
                style = YText.bodyM,
                color = YColor.textSecondary,
            )
            LinkChip(title = "밝기 흐름 보기 ›", onClick = onBrightness)
        }

        // Segment switch: 목록 / 달력
        RecordsSegment(mode = mode, onSelect = { mode = it })

        if (mode == RecordsMode.List) {
            RecordsSearchBar(query = query, onQueryChange = { query = it })
            RecordsChips(filter = filter, onSelect = { filter = it })
            RecordsListContent(
                stars = filteredStars,
                filter = filter,
                trimmedQuery = trimmed,
                onOpenStar = onOpenStar,
                onCompose = onCompose,
            )
        } else {
            RecordsCalendarView(
                stars = model.stars,
                onOpenStar = onOpenStar,
            )
        }
    }
}

/** Segment pill switch (Figma 115–119) */
@Composable
private fun RecordsSegment(mode: RecordsMode, onSelect: (RecordsMode) -> Unit) {
    val a = sky()
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(CircleShape)
            .background(YColor.bgSurfaceRaised, CircleShape)
            .cosmos("records-seg", CircleShape)
            .border(1.dp, YColor.borderDefault, CircleShape)
            .padding(Space.xs),
        horizontalArrangement = Arrangement.spacedBy(Space.xs),
    ) {
        listOf(RecordsMode.List to "목록", RecordsMode.Calendar to "달력").forEach { (m, title) ->
            val on = mode == m
            Box(
                modifier = Modifier
                    .weight(1f)
                    .clip(CircleShape)
                    .background(if (on) a.brandPrimary else Color.Transparent, CircleShape)
                    .noRippleClick { onSelect(m) }
                    .padding(vertical = Space.sm),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    title,
                    style = YText.labelM,
                    color = if (on) YColor.textOnBrand else YColor.textSecondary,
                )
            }
        }
    }
}

/** Search bar (Figma 117) */
@Composable
private fun RecordsSearchBar(query: String, onQueryChange: (String) -> Unit) {
    val a = sky()
    var focused by remember { mutableStateOf(false) }
    val focusRequester = remember { FocusRequester() }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(44.dp)
            .clip(RoundedCornerShape(Radius.md))
            .background(YColor.bgSurface, RoundedCornerShape(Radius.md))
            .cosmos("records-search", RoundedCornerShape(Radius.md))
            .border(1.dp, if (focused || query.isNotEmpty()) a.brandPrimary else YColor.borderDefault, RoundedCornerShape(Radius.md))
            .padding(start = 14.dp, end = Space.md),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Space.sm),
    ) {
        Icon(
            painter = painterResource(R.drawable.icon_search),
            contentDescription = null,
            modifier = Modifier.size(16.dp),
            tint = if (focused || query.isNotEmpty()) YColor.textPrimary else YColor.textTertiary,
        )
        Box(modifier = Modifier.weight(1f)) {
            if (query.isEmpty()) {
                Text("제목이나 내용으로 찾기", style = YText.bodyM, color = YColor.textTertiary)
            }
            BasicTextField(
                value = query,
                onValueChange = onQueryChange,
                modifier = Modifier.semantics { contentDescription = "제목이나 내용으로 찾기" }
                    .fillMaxWidth()
                    .focusRequester(focusRequester)
                    .onFocusChanged { focused = it.isFocused },
                textStyle = YText.bodyM.copy(color = YColor.textPrimary),
                cursorBrush = SolidColor(a.borderFocus),
                singleLine = true,
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
            )
        }
        if (query.isNotEmpty()) {
            Box(
                modifier = Modifier
                    .size(32.dp)
                    .noRippleClick { onQueryChange("") },
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    painter = painterResource(R.drawable.icon_close),
                    contentDescription = "검색어 지우기",
                    modifier = Modifier.size(16.dp),
                    tint = YColor.textSecondary,
                )
            }
        }
    }
}

/** Filter chips (Figma 115) */
@Composable
private fun RecordsChips(filter: RecordsFilter, onSelect: (RecordsFilter) -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .horizontalScroll(rememberScrollState()),
        horizontalArrangement = Arrangement.spacedBy(Space.sm),
    ) {
        FilterPillChip(title = "전체", isSelected = filter == RecordsFilter.All) { onSelect(RecordsFilter.All) }
        FilterPillChip(title = "띄운 별", isSelected = filter == RecordsFilter.Floated) { onSelect(RecordsFilter.Floated) }
        FilterPillChip(title = "별빛 없는 별", isSelected = filter == RecordsFilter.Kept) { onSelect(RecordsFilter.Kept) }
        Mood.entries.forEach { m ->
            val isSel = filter is RecordsFilter.ByMood && filter.mood == m
            DotChip(title = m.label, isSelected = isSel, dot = m.color) {
                onSelect(if (isSel) RecordsFilter.All else RecordsFilter.ByMood(m))
            }
        }
    }
}

@Composable
internal fun FilterPillChip(title: String, isSelected: Boolean, onClick: () -> Unit) {
    val a = sky()
    Box(
        modifier = Modifier
            .clip(CircleShape)
            .background(if (isSelected) a.tintPrimary else YColor.bgSurface, CircleShape)
            .cosmos("rchip-$title", CircleShape, intensity = 0.6)
            .border(1.dp, if (isSelected) a.brandPrimary else YColor.borderDefault, CircleShape)
            .noRippleClick(onClick)
            .padding(horizontal = Space.md, vertical = Space.sm),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            title,
            style = YText.labelS,
            color = if (isSelected) YColor.textPrimary else YColor.textSecondary,
        )
    }
}

/** List content: grouped by month or empty or search results */
@Composable
private fun RecordsListContent(
    stars: List<StarItem>,
    filter: RecordsFilter,
    trimmedQuery: String,
    onOpenStar: (StarItem) -> Unit,
    onCompose: () -> Unit,
) {
    if (trimmedQuery.isNotEmpty()) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text("‘$trimmedQuery’이 담긴 별 ${stars.size}개", style = YText.labelM, color = YColor.textPrimary)
            Text("제목 · 본문", style = YText.caption, color = YColor.textTertiary)
        }
        if (stars.isEmpty()) {
            EmptyStateView(
                title = "‘$trimmedQuery’이 담긴 별이 없어요",
                message = "다른 말로 찾아보거나, 필터를 바꿔 보세요.",
                floatedGlyph = true,
                modifier = Modifier.padding(top = 48.dp),
            )
        } else {
            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                verticalArrangement = Arrangement.spacedBy(Space.md),
            ) {
                items(stars, key = { it.id }) { star ->
                    StarRow(star = star, onClick = { onOpenStar(star) })
                }
            }
        }
    } else if (stars.isEmpty()) {
        if (filter == RecordsFilter.Kept) {
            EmptyStateView(
                title = "아직 별빛 없는 별이 없어요",
                message = "분석 없이 조용히 두고 싶은 글은\n여기에 모여요.",
                actionTitle = "별 만들기",
                onAction = onCompose,
                floatedGlyph = false,
                modifier = Modifier.padding(top = 48.dp),
            )
        } else {
            EmptyStateView(
                title = "아직 별이 없어요",
                message = "오늘의 마음을 적으면\n이곳에 하나씩 모여요.",
                actionTitle = "오늘의 별 만들기",
                onAction = onCompose,
                floatedGlyph = true,
                modifier = Modifier.padding(top = 48.dp),
            )
        }
    } else {
        // Group by YearMonth
        val grouped = remember(stars) {
            stars.groupBy { star ->
                star.parsedDate?.let { YearMonth.of(it.year, it.monthValue) } ?: YearMonth.now()
            }.toList().sortedByDescending { it.first }
        }

        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            verticalArrangement = Arrangement.spacedBy(Space.lg),
        ) {
            grouped.forEach { (yearMonth, monthStars) ->
                item(key = yearMonth.toString()) {
                    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Text(
                                "${yearMonth.year}년 ${yearMonth.monthValue}월",
                                style = YText.labelM,
                                color = YColor.textPrimary,
                                modifier = Modifier.semantics { heading() },
                            )
                            Text("별 ${monthStars.size}개", style = YText.caption, color = YColor.textTertiary)
                        }
                        Column(verticalArrangement = Arrangement.spacedBy(Space.md)) {
                            monthStars.forEach { star ->
                                StarRow(star = star, onClick = { onOpenStar(star) })
                            }
                        }
                    }
                }
            }
        }
    }
}

/** 116 Calendar view */
@Composable
private fun RecordsCalendarView(
    stars: List<StarItem>,
    onOpenStar: (StarItem) -> Unit,
) {
    val a = sky()
    var currentMonth by remember { mutableStateOf(YearMonth.now()) }
    var selectedDate by remember { mutableStateOf<LocalDate?>(null) }

    val starsByDay = remember(stars) {
        stars.groupBy { it.parsedDate?.toLocalDate() }
    }

    LaunchedEffect(currentMonth) {
        if (selectedDate == null || YearMonth.from(selectedDate) != currentMonth) {
            // opens on latest day this month that has stars
            val datesInMonth = (1..currentMonth.lengthOfMonth()).map { currentMonth.atDay(it) }
            selectedDate = datesInMonth.filter { starsByDay[it]?.isNotEmpty() == true }.maxOrNull()
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(Space.sm),
    ) {
        // Month header with arrows
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(28.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                modifier = Modifier
                    .size(40.dp, 28.dp)
                    .noRippleClick { currentMonth = currentMonth.minusMonths(1) },
                contentAlignment = Alignment.Center,
            ) {
                Icon(painterResource(R.drawable.icon_back), contentDescription = "이전 달", modifier = Modifier.size(24.dp), tint = YColor.textPrimary)
            }
            Text(
                "${currentMonth.year}년 ${currentMonth.monthValue}월",
                style = YText.h3,
                color = YColor.textPrimary,
            )
            Box(
                modifier = Modifier
                    .size(40.dp, 28.dp)
                    .noRippleClick { currentMonth = currentMonth.plusMonths(1) },
                contentAlignment = Alignment.Center,
            ) {
                Icon(painterResource(R.drawable.icon_chevron_right), contentDescription = "다음 달", modifier = Modifier.size(24.dp), tint = YColor.textPrimary)
            }
        }

        // Days of week: 일 월 화 수 목 금 토
        Row(modifier = Modifier.fillMaxWidth()) {
            listOf("일", "월", "화", "수", "목", "금", "토").forEach { dow ->
                Text(
                    dow,
                    style = YText.caption,
                    color = YColor.textTertiary,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.weight(1f),
                )
            }
        }

        // Calendar grid (7 columns)
        val firstDay = currentMonth.atDay(1)
        val leadingBlanks = firstDay.dayOfWeek.value % 7 // Sun=0, Mon=1...Sat=6
        val daysInMonth = currentMonth.lengthOfMonth()
        val totalCells = leadingBlanks + daysInMonth
        val rows = (totalCells + 6) / 7

        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            for (r in 0 until rows) {
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(2.dp)) {
                    for (c in 0 until 7) {
                        val index = r * 7 + c
                        val dayNum = index - leadingBlanks + 1
                        if (dayNum in 1..daysInMonth) {
                            val date = currentMonth.atDay(dayNum)
                            val dayStars = starsByDay[date] ?: emptyList()
                            val hasStars = dayStars.isNotEmpty()
                            val isSelected = selectedDate == date
                            val isFuture = date.isAfter(LocalDate.now())

                            Box(
                                modifier = Modifier
                                    .weight(1f)
                                    .height(48.dp)
                                    .clip(RoundedCornerShape(Radius.md))
                                    .then(
                                        if (isSelected) Modifier
                                            .background(a.tintPrimary, RoundedCornerShape(Radius.md))
                                            .border(1.dp, a.brandPrimary, RoundedCornerShape(Radius.md))
                                        else Modifier
                                    )
                                    .noRippleClick { selectedDate = date },
                                contentAlignment = Alignment.Center,
                            ) {
                                Column(
                                    horizontalAlignment = Alignment.CenterHorizontally,
                                    verticalArrangement = Arrangement.spacedBy(4.dp),
                                ) {
                                    Text(
                                        dayNum.toString(),
                                        style = YText.bodyS,
                                        color = when {
                                            hasStars || isSelected -> YColor.textPrimary
                                            isFuture -> YColor.textTertiary
                                            else -> YColor.textSecondary
                                        },
                                    )
                                    if (hasStars) {
                                        Image(
                                            painter = painterResource(
                                                if (dayStars.any { it.isFloated }) R.drawable.star_shape_floated
                                                else R.drawable.star_shape_kept
                                            ),
                                            contentDescription = null,
                                            modifier = Modifier.size(14.dp),
                                        )
                                    } else {
                                        Spacer(Modifier.size(14.dp))
                                    }
                                }
                            }
                        } else {
                            Spacer(Modifier.weight(1f))
                        }
                    }
                }
            }
        }

        // Selected day details
        selectedDate?.let { date ->
            val dayStars = starsByDay[date] ?: emptyList()
            val formatter = remember { DateTimeFormatter.ofPattern("M월 d일 EEEE", Locale.KOREAN) }
            Spacer(Modifier.height(Space.md))
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(date.format(formatter), style = YText.labelM, color = YColor.textPrimary)
                    Text("별 ${dayStars.size}개", style = YText.caption, color = YColor.textTertiary)
                }
                if (dayStars.isEmpty()) {
                    Text("이날은 쉬어 간 밤이에요.", style = YText.bodyS, color = YColor.textSecondary)
                } else {
                    Column(verticalArrangement = Arrangement.spacedBy(Space.md)) {
                        dayStars.forEach { star ->
                            StarRow(star = star, onClick = { onOpenStar(star) })
                        }
                    }
                }
            }
        }
    }
}

/** 17 Hero: twinkling constellation (342×130) */
@Composable
fun RecordsHero(modifier: Modifier = Modifier) {
    BoxWithConstraints(
        modifier = modifier
            .fillMaxWidth()
            .height(130.dp),
        contentAlignment = Alignment.TopStart,
    ) {
        val scale = maxWidth / 342.dp
        Image(
            painter = painterResource(R.drawable.records_line),
            contentDescription = null,
            modifier = Modifier
                .offset(x = (170.5f - 269.652f / 2f).dp * scale, y = (68f - 64.9808f / 2f).dp * scale)
                .size(269.652.dp * scale, 64.9808.dp * scale),
        )

        data class HeroStarSpec(val res: Int, val cx: Float, val cy: Float, val size: Float, val keys: List<Pair<Double, Double>>)
        val stars = listOf(
            HeroStarSpec(R.drawable.records_star0, 36f, 90f, 66f, listOf(0.0 to 1.0, 0.12 to 0.3, 0.48 to 1.0, 0.84 to 0.3, 1.0 to 1.0)),
            HeroStarSpec(R.drawable.records_star1, 105f, 45f, 62f, listOf(0.0 to 1.0, 0.625 to 0.3, 1.0 to 1.0)),
            HeroStarSpec(R.drawable.records_star2, 178f, 82f, 66f, listOf(0.0 to 1.0, 0.27 to 0.3, 0.84 to 1.0, 1.0 to 0.3)),
            HeroStarSpec(R.drawable.records_star3, 250f, 36f, 50f, listOf(0.0 to 1.0, 0.02 to 0.3, 0.47 to 1.0, 0.92 to 0.3, 1.0 to 1.0)),
            HeroStarSpec(R.drawable.records_star4, 305f, 100f, 68f, listOf(0.0 to 1.0, 0.205 to 0.3, 0.535 to 1.0, 0.865 to 0.3, 1.0 to 1.0)),
        )

        stars.forEach { s ->
            Image(
                painter = painterResource(s.res),
                contentDescription = null,
                modifier = Modifier
                    .offset(x = (s.cx - s.size / 2f).dp * scale, y = (s.cy - s.size / 2f).dp * scale)
                    .size(s.size.dp * scale)
                    .twinkle(Twinkle(2.0, s.keys), dimScale),
            )
        }
    }
}

/** 18 Kept View (별빛 없는 별) */
@Composable
fun KeptView(
    model: AppModel,
    onBack: () -> Unit,
    onOpenStar: (StarItem) -> Unit,
    modifier: Modifier = Modifier,
) {
    val kept = remember(model.stars) { model.stars.filter { !it.isFloated } }
    val context = androidx.compose.ui.platform.LocalContext.current

    BackHandler(onBack = onBack)
    Box(modifier.fillMaxSize()) {
        StarField()
        Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding()) {
            TopAppBar("별빛 없는 별", onBack = onBack)

            Column(
                modifier = Modifier
                    .weight(1f)
                    .padding(horizontal = Space.xl)
                    .padding(top = Space.sm, bottom = Space.xl),
                verticalArrangement = Arrangement.spacedBy(Space.lg),
            ) {
                Text(
                    "별빛 없이 띄운 별이에요. 언제든 별빛을 받을 수 있어요.",
                    style = YText.bodyM,
                    color = YColor.textSecondary,
                )

                KeptHero()

                if (kept.isEmpty()) {
                    Text(
                        "아직 별빛 없는 별이 없어요.",
                        style = YText.bodyM,
                        color = YColor.textTertiary,
                        textAlign = TextAlign.Center,
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(top = Space.xl),
                    )
                    Spacer(Modifier.weight(1f))
                } else {
                    LazyColumn(
                        modifier = Modifier.weight(1f),
                        verticalArrangement = Arrangement.spacedBy(Space.md),
                    ) {
                        items(kept, key = { it.id }) { star ->
                            StarRow(star = star, onClick = { onOpenStar(star) })
                        }
                    }

                    GhostButton("모두 내보내기") {
                        val exportAll = kept.joinToString("\n\n———\n\n") {
                            listOf(it.title, it.longDateText, "", it.body).joinToString("\n")
                        }
                        val shareIntent = android.content.Intent(android.content.Intent.ACTION_SEND).apply {
                            type = "text/plain"
                            putExtra(android.content.Intent.EXTRA_TEXT, exportAll)
                        }
                        context.startActivity(android.content.Intent.createChooser(shareIntent, "별빛 없는 별 내보내기"))
                    }
                }
            }
        }
    }
}

/** 18 Kept Hero (342×150) */
@Composable
fun KeptHero(modifier: Modifier = Modifier) {
    BoxWithConstraints(
        modifier = modifier
            .fillMaxWidth()
            .height(150.dp),
        contentAlignment = Alignment.TopStart,
    ) {
        val scale = maxWidth / 342.dp

        Image(
            painter = painterResource(R.drawable.kept_orbit2),
            contentDescription = null,
            modifier = Modifier
                .offset(x = (171f - 100f / 2f).dp * scale, y = (75f - 38f / 2f).dp * scale)
                .size(100.dp * scale, 38.dp * scale),
        )

        data class KeptStarSpec(val res: Int, val cx: Float, val cy: Float, val size: Float, val keys: List<Pair<Double, Double>>)
        val stars = listOf(
            KeptStarSpec(R.drawable.kept_star0, 171f, 75f, 90f, listOf(0.0 to 1.0, 0.12 to 0.3, 0.78 to 1.0, 1.0 to 0.3)),
            KeptStarSpec(R.drawable.kept_star1, 21f, 75f, 58f, listOf(0.0 to 1.0, 0.405 to 0.3, 0.95 to 1.0, 1.0 to 0.3)),
            KeptStarSpec(R.drawable.kept_star2, 271f, 56f, 60f, listOf(0.0 to 1.0, 0.135 to 0.3, 0.56 to 1.0, 0.98 to 0.3, 1.0 to 1.0)),
            KeptStarSpec(R.drawable.kept_star3, 100f, 98f, 48f, listOf(0.0 to 1.0, 0.27 to 0.3, 0.575 to 1.0, 0.88 to 0.3, 1.0 to 1.0)),
            KeptStarSpec(R.drawable.kept_star4, 221f, 95f, 62f, listOf(0.0 to 1.0, 0.29 to 0.3, 0.925 to 1.0, 1.0 to 0.3)),
        )

        stars.forEach { s ->
            Image(
                painter = painterResource(s.res),
                contentDescription = null,
                modifier = Modifier
                    .offset(x = (s.cx - s.size / 2f).dp * scale, y = (s.cy - s.size / 2f).dp * scale)
                    .size(s.size.dp * scale)
                    .twinkle(Twinkle(2.0, s.keys), dimScale),
            )
        }
    }
}

/** Link Chip (iOS LinkChip) */
@Composable
fun LinkChip(title: String, onClick: () -> Unit, modifier: Modifier = Modifier) {
    Box(
        modifier = modifier
            .clip(CircleShape)
            .background(YColor.bgSurfaceRaised, CircleShape)
            .cosmos("chip-$title", CircleShape, intensity = 0.6)
            .border(1.dp, YColor.borderDefault, CircleShape)
            .noRippleClick(onClick)
            .padding(horizontal = Space.md, vertical = Space.xs)
            .height(32.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(title, style = YText.labelS, color = YColor.textSecondary)
    }
}

/** Dot Chip (iOS DotChip) */
@Composable
fun DotChip(
    title: String,
    isSelected: Boolean,
    dot: Color,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    val a = sky()
    Row(
        modifier = modifier
            .clip(CircleShape)
            .background(if (isSelected) a.tintPrimary else YColor.bgSurface, CircleShape)
            .border(1.dp, if (isSelected) a.brandPrimary else YColor.borderDefault, CircleShape)
            .noRippleClick(onClick)
            .padding(horizontal = Space.md, vertical = Space.sm),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Space.sm),
    ) {
        Box(Modifier.size(8.dp).background(dot, CircleShape))
        Text(
            title,
            style = YText.labelS,
            color = if (isSelected) YColor.textPrimary else YColor.textSecondary,
        )
    }
}
