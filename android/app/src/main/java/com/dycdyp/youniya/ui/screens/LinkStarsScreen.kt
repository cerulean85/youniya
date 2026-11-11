package com.dycdyp.youniya.ui.screens

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.dycdyp.youniya.R
import com.dycdyp.youniya.data.AppModel
import com.dycdyp.youniya.data.Mood
import com.dycdyp.youniya.data.StarItem
import com.dycdyp.youniya.ui.components.GhostButton
import com.dycdyp.youniya.ui.components.PrimaryButton
import com.dycdyp.youniya.ui.components.SheetGrabber
import com.dycdyp.youniya.ui.components.StarRow
import com.dycdyp.youniya.ui.components.TopAppBar
import com.dycdyp.youniya.ui.components.noRippleClick
import com.dycdyp.youniya.ui.design.StarField
import com.dycdyp.youniya.ui.theme.Radius
import com.dycdyp.youniya.ui.theme.Space
import com.dycdyp.youniya.ui.theme.YColor
import com.dycdyp.youniya.ui.theme.YText
import com.dycdyp.youniya.ui.theme.sky
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.YearMonth
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

private sealed interface LinkFilter {
    data object All : LinkFilter
    data object Lit : LinkFilter
    data object Unlit : LinkFilter
    data class ByMood(val mood: Mood) : LinkFilter
}

private val KST = ZoneId.of("Asia/Seoul")

/**
 * 12-7 / 12-8 이을 별 고르기 (iOS LinkStarsView):
 * pick stars already written, from a searchable, filterable list grouped by month,
 * or from a calendar.
 */
@Composable
fun LinkStarsScreen(
    model: AppModel,
    starId: String,
    onBack: () -> Unit,
    onLinked: (Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    val star = model.stars.firstOrNull { it.id == starId }
    val alreadyLinked = remember(star) { (star?.linkedIds ?: emptyList()).toSet() }

    var filter by remember { mutableStateOf<LinkFilter>(LinkFilter.All) }
    var query by remember { mutableStateOf("") }
    var picked by remember { mutableStateOf<Set<String>>(emptySet()) }
    var preview by remember { mutableStateOf<StarItem?>(null) }
    var saving by remember { mutableStateOf(false) }
    var byCalendar by remember { mutableStateOf(false) }

    val currentYearMonth = remember { YearMonth.now(KST) }
    var calMonth by remember { mutableStateOf(currentYearMonth) }
    var calDay by remember { mutableStateOf<LocalDate?>(null) }

    val scope = rememberCoroutineScope()

    BackHandler(enabled = true, onBack = onBack)

    val candidates = remember(model.stars, filter, query, starId, alreadyLinked) {
        val q = query.trim()
        model.stars.filter { s ->
            if (s.id == starId || alreadyLinked.contains(s.id)) return@filter false
            when (val f = filter) {
                is LinkFilter.All -> Unit
                is LinkFilter.Lit -> if (!s.isFloated) return@filter false
                is LinkFilter.Unlit -> if (s.isFloated) return@filter false
                is LinkFilter.ByMood -> if (s.mood != f.mood && !(s.extraMoods ?: emptyList()).contains(f.mood)) return@filter false
            }
            if (q.isNotEmpty()) {
                val matchesTitle = s.title.contains(q, ignoreCase = true)
                val matchesBody = s.body.contains(q, ignoreCase = true)
                if (!matchesTitle && !matchesBody) return@filter false
            }
            true
        }.sortedByDescending { it.parsedDate ?: java.time.ZonedDateTime.now() }
    }

    val monthGroups = remember(candidates) {
        val formatter = DateTimeFormatter.ofPattern("yyyy년 M월", Locale.KOREAN)
        val order = mutableListOf<String>()
        val byMonth = mutableMapOf<String, MutableList<StarItem>>()
        for (s in candidates) {
            val date = s.parsedDate ?: java.time.ZonedDateTime.now()
            val key = formatter.format(date)
            if (!byMonth.containsKey(key)) order.add(key)
            byMonth.getOrPut(key) { mutableListOf() }.add(s)
        }
        order.map { it to (byMonth[it] ?: emptyList()) }
    }

    fun togglePicked(id: String) {
        picked = if (picked.contains(id)) picked - id else picked + id
    }

    Box(
        modifier
            .fillMaxSize()
            .background(YColor.bgCanvas),
    ) {
        StarField()

        Column(
            Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .navigationBarsPadding(),
        ) {
            TopAppBar(title = "", onBack = onBack)

            Column(
                Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = Space.xl)
                    .padding(bottom = 96.dp),
                verticalArrangement = Arrangement.spacedBy(Space.lg),
            ) {
                // Header
                Column(
                    verticalArrangement = Arrangement.spacedBy(Space.sm),
                    modifier = Modifier.semantics(mergeDescendants = true) { heading() },
                ) {
                    Text("이을 별 고르기", style = YText.h1, color = YColor.textPrimary)
                    Text(
                        "「${star?.title ?: ""}」와 이을 별을 골라 주세요. 여러 개를 고를 수 있어요.",
                        style = YText.bodyM,
                        color = YColor.textSecondary,
                    )
                    Text(
                        "별을 누르면 내용을 볼 수 있어요 · 오른쪽 원을 누르면 바로 골라져요",
                        style = YText.caption,
                        color = sky().brandPrimaryText,
                    )
                }

                // Segment (목록 | 달력)
                SegmentControl(
                    byCalendar = byCalendar,
                    onSelect = { byCalendar = it },
                )

                if (byCalendar) {
                    CalendarView(
                        calMonth = calMonth,
                        calDay = calDay,
                        candidates = candidates,
                        picked = picked,
                        onMonthShift = { shift ->
                            val next = calMonth.plusMonths(shift.toLong())
                            if (!next.isAfter(currentYearMonth)) {
                                calMonth = next
                                calDay = null
                            }
                        },
                        canShiftNext = calMonth.isBefore(currentYearMonth),
                        onDaySelect = { day -> calDay = day },
                        onPreview = { preview = it },
                        onToggle = { togglePicked(it) },
                    )
                } else {
                    // Search
                    SearchInput(query = query, onQueryChange = { query = it })

                    // Chips
                    FilterChipsRow(
                        currentFilter = filter,
                        onSelect = { filter = it },
                    )

                    // Grouped List
                    if (candidates.isEmpty()) {
                        Text(
                            text = if (query.isEmpty()) "이을 수 있는 별이 아직 없어요." else "‘$query’이 담긴 별이 없어요.",
                            style = YText.bodyM,
                            color = YColor.textTertiary,
                            textAlign = TextAlign.Center,
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(vertical = Space.xxxl),
                        )
                    } else {
                        monthGroups.forEach { (month, stars) ->
                            Row(
                                Modifier.fillMaxWidth(),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.SpaceBetween,
                            ) {
                                Text(month, style = YText.labelM, color = YColor.textPrimary)
                                Text("별 ${stars.size}개", style = YText.caption, color = YColor.textTertiary)
                            }
                            stars.forEach { item ->
                                PickableStarRow(
                                    star = item,
                                    isPicked = picked.contains(item.id),
                                    onPreview = { preview = item },
                                    onToggle = { togglePicked(item.id) },
                                )
                            }
                        }
                    }
                }
            }
        }

        // Floating bottom link button
        AnimatedVisibility(
            visible = picked.isNotEmpty(),
            enter = slideInVertically(initialOffsetY = { it }) + fadeIn(),
            exit = slideOutVertically(targetOffsetY = { it }) + fadeOut(),
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .fillMaxWidth()
                .padding(horizontal = Space.xl, vertical = Space.xl)
                .navigationBarsPadding(),
        ) {
            PrimaryButton(
                text = "${picked.size}개 별 잇기",
                enabled = !saving,
                onClick = {
                    saving = true
                    scope.launch {
                        val count = picked.size
                        val ok = model.linkStars(starId, picked.toList())
                        saving = false
                        if (ok) {
                            onLinked(count)
                        }
                    }
                },
            )
        }

        // 12-9 미리보기 시트
        if (preview != null) {
            val previewStar = preview!!
            val linked = model.linkedStars(previewStar.id)
            YouniyaSheet("link-preview", onDismiss = { preview = null }) {
                Column(
                    Modifier
                        .fillMaxWidth()
                        .padding(horizontal = Space.xl)
                        .padding(top = Space.md, bottom = Space.xl),
                    verticalArrangement = Arrangement.spacedBy(Space.lg),
                ) {
                    SheetGrabber()

                    Column(
                        Modifier
                            .fillMaxWidth()
                            .heightIn(max = 380.dp)
                            .verticalScroll(rememberScrollState()),
                        verticalArrangement = Arrangement.spacedBy(Space.md),
                    ) {
                        Text(
                            text = previewStar.longDateText + (if (previewStar.isFloated) "" else " · 별빛 없는 별"),
                            style = YText.caption,
                            color = YColor.textTertiary,
                        )
                        Text(
                            text = previewStar.title,
                            style = YText.h2,
                            color = YColor.textPrimary,
                        )
                        Text(
                            text = previewStar.body,
                            style = YText.bodyM,
                            color = YColor.textSecondary,
                        )
                        if (linked.isNotEmpty()) {
                            Text(
                                text = "이미 이어진 별 ${linked.size} · " + linked.joinToString(" ") { "「${it.title}」" },
                                style = YText.caption,
                                color = YColor.starBright,
                            )
                        }
                    }

                    Column(
                        Modifier.fillMaxWidth(),
                        verticalArrangement = Arrangement.spacedBy(Space.md),
                    ) {
                        val isPicked = picked.contains(previewStar.id)
                        PrimaryButton(
                            text = if (isPicked) "고르지 않기" else "이 별 고르기",
                            onClick = {
                                togglePicked(previewStar.id)
                                preview = null
                            },
                        )
                        GhostButton(
                            text = "닫기",
                            onClick = { preview = null },
                        )
                    }
                }
            }
        }
    }
}

/** Segment: 목록 | 달력 */
@Composable
private fun SegmentControl(
    byCalendar: Boolean,
    onSelect: (Boolean) -> Unit,
) {
    val a = sky()
    Row(
        Modifier
            .fillMaxWidth()
            .background(YColor.bgSurfaceRaised, CircleShape)
            .border(1.dp, YColor.borderDefault, CircleShape)
            .padding(Space.xs),
        horizontalArrangement = Arrangement.spacedBy(Space.xs),
    ) {
        listOf(false to "목록", true to "달력").forEach { (cal, label) ->
            val on = byCalendar == cal
            Box(
                Modifier
                    .weight(1f)
                    .background(if (on) a.brandPrimary else Color.Transparent, CircleShape)
                    .noRippleClick { onSelect(cal) }
                    .padding(vertical = Space.sm)
                    .semantics { selected = on },
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = label,
                    style = YText.labelM,
                    color = if (on) YColor.textOnBrand else YColor.textSecondary,
                )
            }
        }
    }
}

@Composable
private fun SearchInput(
    query: String,
    onQueryChange: (String) -> Unit,
) {
    Row(
        Modifier
            .fillMaxWidth()
            .height(44.dp)
            .background(YColor.bgSurface, RoundedCornerShape(Radius.md))
            .border(1.dp, YColor.borderDefault, RoundedCornerShape(Radius.md))
            .padding(horizontal = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Space.sm),
    ) {
        Image(
            painter = painterResource(R.drawable.icon_search),
            contentDescription = null,
            modifier = Modifier.size(18.dp),
        )
        Box(Modifier.weight(1f)) {
            if (query.isEmpty()) {
                Text(
                    "제목이나 내용으로 찾기",
                    style = YText.bodyM,
                    color = YColor.textTertiary,
                )
            }
            BasicTextField(
                value = query,
                onValueChange = onQueryChange,
                textStyle = YText.bodyM.copy(color = YColor.textPrimary),
                cursorBrush = SolidColor(sky().borderFocus),
                modifier = Modifier.semantics { contentDescription = "제목이나 내용으로 찾기" }.fillMaxWidth(),
                singleLine = true,
            )
        }
    }
}

@Composable
private fun FilterChipsRow(
    currentFilter: LinkFilter,
    onSelect: (LinkFilter) -> Unit,
) {
    Row(
        Modifier
            .horizontalScroll(rememberScrollState()),
        horizontalArrangement = Arrangement.spacedBy(Space.sm),
    ) {
        DotChip(
            title = "전체",
            isSelected = currentFilter is LinkFilter.All,
            onClick = { onSelect(LinkFilter.All) },
        )
        DotChip(
            title = "띄운 별",
            isSelected = currentFilter is LinkFilter.Lit,
            onClick = { onSelect(LinkFilter.Lit) },
        )
        DotChip(
            title = "별빛 없는 별",
            isSelected = currentFilter is LinkFilter.Unlit,
            onClick = { onSelect(LinkFilter.Unlit) },
        )
        Mood.entries.forEach { m ->
            DotChip(
                title = m.label,
                isSelected = currentFilter == LinkFilter.ByMood(m),
                dotColor = m.color,
                onClick = {
                    onSelect(if (currentFilter == LinkFilter.ByMood(m)) LinkFilter.All else LinkFilter.ByMood(m))
                },
            )
        }
    }
}

@Composable
private fun DotChip(
    title: String,
    isSelected: Boolean,
    dotColor: Color? = null,
    onClick: () -> Unit,
) {
    val a = sky()
    Row(
        Modifier
            .background(if (isSelected) a.tintPrimary else YColor.bgSurface, CircleShape)
            .border(1.dp, if (isSelected) a.brandPrimary else YColor.borderDefault, CircleShape)
            .noRippleClick(onClick)
            .padding(horizontal = Space.md, vertical = Space.sm)
            .semantics { selected = isSelected },
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        if (dotColor != null) {
            Box(Modifier.size(7.dp).background(dotColor, CircleShape))
        }
        Text(
            text = title,
            style = YText.labelS,
            color = if (isSelected) YColor.textPrimary else YColor.textSecondary,
        )
    }
}

@Composable
private fun PickableStarRow(
    star: StarItem,
    isPicked: Boolean,
    onPreview: () -> Unit,
    onToggle: () -> Unit,
) {
    val a = sky()
    Box(
        Modifier
            .fillMaxWidth()
            .padding(top = 8.dp),
    ) {
        Box(
            Modifier
                .fillMaxWidth()
                .then(
                    if (isPicked) Modifier.border(1.5.dp, a.brandPrimary, RoundedCornerShape(Radius.lg))
                    else Modifier
                ),
        ) {
            StarRow(star = star, onClick = onPreview)
        }

        // Selection circle on top-right
        Box(
            Modifier
                .align(Alignment.TopEnd)
                .offset(x = 6.dp, y = (-8).dp)
                .size(44.dp)
                .noRippleClick(onToggle)
                .semantics {
                    selected = isPicked
                    contentDescription = if (isPicked) "${star.title} 고름" else "${star.title} 고르기"
                },
            contentAlignment = Alignment.Center,
        ) {
            Box(
                Modifier
                    .size(22.dp)
                    .background(if (isPicked) a.brandPrimary else YColor.bgSurface, CircleShape)
                    .border(1.2.dp, if (isPicked) a.brandPrimary else YColor.borderDefault, CircleShape),
                contentAlignment = Alignment.Center,
            ) {
                if (isPicked) {
                    Image(
                        painter = painterResource(R.drawable.icon_check),
                        contentDescription = null,
                        modifier = Modifier.size(12.dp),
                    )
                }
            }
        }
    }
}

// 12-8 달력 뷰
@Composable
private fun CalendarView(
    calMonth: YearMonth,
    calDay: LocalDate?,
    candidates: List<StarItem>,
    picked: Set<String>,
    onMonthShift: (Int) -> Unit,
    canShiftNext: Boolean,
    onDaySelect: (LocalDate) -> Unit,
    onPreview: (StarItem) -> Unit,
    onToggle: (String) -> Unit,
) {
    val monthTitle = calMonth.format(DateTimeFormatter.ofPattern("yyyy년 M월", Locale.KOREAN))

    Column(verticalArrangement = Arrangement.spacedBy(Space.md)) {
        // Month navigation
        Row(
            Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Box(
                Modifier
                    .size(44.dp)
                    .noRippleClick { onMonthShift(-1) }
                    .semantics { contentDescription = "지난달" },
                contentAlignment = Alignment.Center,
            ) {
                Image(painterResource(R.drawable.icon_back), null, Modifier.size(20.dp))
            }
            Text(monthTitle, style = YText.h3, color = YColor.textPrimary)
            Box(
                Modifier
                    .size(44.dp)
                    .alpha(if (canShiftNext) 1f else 0.3f)
                    .then(if (canShiftNext) Modifier.noRippleClick { onMonthShift(1) } else Modifier)
                    .semantics { contentDescription = "다음 달" },
                contentAlignment = Alignment.Center,
            ) {
                Image(
                    painterResource(R.drawable.icon_chevron_right),
                    null,
                    Modifier.size(20.dp),
                )
            }
        }

        // Days of week header
        Row(Modifier.fillMaxWidth()) {
            listOf("일", "월", "화", "수", "목", "금", "토").forEach { dayLabel ->
                Text(
                    text = dayLabel,
                    style = YText.caption,
                    color = YColor.textTertiary,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.weight(1f),
                )
            }
        }

        // Calendar grid
        val firstDay = calMonth.atDay(1)
        val dayOfWeekIndex = firstDay.dayOfWeek.value % 7 // Sunday = 0
        val daysInMonth = calMonth.lengthOfMonth()
        val totalCells = dayOfWeekIndex + daysInMonth

        val rows = (totalCells + 6) / 7
        Column(verticalArrangement = Arrangement.spacedBy(Space.sm)) {
            for (r in 0 until rows) {
                Row(Modifier.fillMaxWidth()) {
                    for (c in 0 until 7) {
                        val index = r * 7 + c
                        val dayNum = index - dayOfWeekIndex + 1
                        if (dayNum in 1..daysInMonth) {
                            val day = calMonth.atDay(dayNum)
                            val dayStars = candidates.filter {
                                val d = it.parsedDate?.toLocalDate()
                                d == day
                            }
                            val hasPicked = dayStars.any { picked.contains(it.id) }
                            val isOn = calDay == day

                            DayCell(
                                dayNumber = dayNum,
                                stars = dayStars,
                                isSelected = isOn,
                                hasPicked = hasPicked,
                                onClick = { if (dayStars.isNotEmpty()) onDaySelect(day) },
                                modifier = Modifier.weight(1f),
                            )
                        } else {
                            Spacer(Modifier.weight(1f))
                        }
                    }
                }
            }
        }

        // Selected day stars
        if (calDay != null) {
            val list = candidates.filter { it.parsedDate?.toLocalDate() == calDay }
            val df = DateTimeFormatter.ofPattern("M월 d일 EEEE", Locale.KOREAN)
            Row(
                Modifier.fillMaxWidth().padding(top = Space.md),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Text(calDay.format(df), style = YText.labelM, color = YColor.textPrimary)
                Text("별 ${list.size}개", style = YText.caption, color = YColor.textTertiary)
            }
            list.forEach { s ->
                PickableStarRow(
                    star = s,
                    isPicked = picked.contains(s.id),
                    onPreview = { onPreview(s) },
                    onToggle = { onToggle(s.id) },
                )
            }
        }
    }
}

@Composable
private fun DayCell(
    dayNumber: Int,
    stars: List<StarItem>,
    isSelected: Boolean,
    hasPicked: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val a = sky()
    val shape = RoundedCornerShape(Radius.md)
    val hasStars = stars.isNotEmpty()

    Column(
        modifier = modifier
            .heightIn(min = 44.dp)
            .background(if (isSelected) a.tintPrimary else Color.Transparent, shape)
            .border(1.dp, if (isSelected) a.brandPrimary else Color.Transparent, shape)
            .then(if (hasStars) Modifier.noRippleClick(onClick) else Modifier)
            .semantics { contentDescription = "${dayNumber}일, 별 ${stars.size}개" },
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Box(
            Modifier
                .size(30.dp)
                .then(if (hasPicked) Modifier.border(1.2.dp, a.brandPrimary, CircleShape) else Modifier),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = dayNumber.toString(),
                style = YText.bodyM,
                color = if (!hasStars) YColor.textTertiary else YColor.textPrimary,
            )
        }
        if (hasStars) {
            val hasFloated = stars.any { it.isFloated }
            Box(
                Modifier
                    .size(4.dp)
                    .background(if (hasFloated) a.brandPrimaryText else YColor.textSecondary, CircleShape),
            )
        } else {
            Spacer(Modifier.height(4.dp))
        }
    }
}
