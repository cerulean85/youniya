package com.dycdyp.youniya.ui.screens

import androidx.activity.compose.BackHandler
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.requiredSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.dycdyp.youniya.R
import com.dycdyp.youniya.data.AppModel
import com.dycdyp.youniya.data.StarItem
import com.dycdyp.youniya.ui.components.GhostButton
import com.dycdyp.youniya.ui.components.LogoMark
import com.dycdyp.youniya.ui.components.LogoSize
import com.dycdyp.youniya.ui.components.MenuButton
import com.dycdyp.youniya.ui.components.PrimaryButton
import com.dycdyp.youniya.ui.components.SheetGrabber
import com.dycdyp.youniya.ui.components.StarRow
import com.dycdyp.youniya.ui.components.noRippleClick
import com.dycdyp.youniya.ui.design.StarField
import com.dycdyp.youniya.ui.design.Twinkle
import com.dycdyp.youniya.ui.design.cosmos
import com.dycdyp.youniya.ui.design.dimScale
import com.dycdyp.youniya.ui.design.rememberClock
import com.dycdyp.youniya.ui.design.twinkle
import com.dycdyp.youniya.ui.theme.LocalMotionReduced
import com.dycdyp.youniya.ui.theme.NotoSerifKR
import com.dycdyp.youniya.ui.theme.Pretendard
import com.dycdyp.youniya.ui.theme.Radius
import com.dycdyp.youniya.ui.theme.Space
import com.dycdyp.youniya.ui.theme.YColor
import com.dycdyp.youniya.ui.theme.YText
import com.dycdyp.youniya.ui.theme.sky
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.Locale

enum class SkyTab(val title: String, val icon: Int) {
    Sky("오늘", R.drawable.icon_moon),
    Nebula("별자리", R.drawable.icon_nebula),
    Plaza("우주 광장", R.drawable.icon_star),
    Records("기록", R.drawable.icon_archive),
}

sealed interface MainNav {
    data class StarDetail(val starId: String) : MainNav
    data class StarEdit(val starId: String) : MainNav
    data class LinkExisting(val starId: String) : MainNav
    data class Compose(
        val rewriteOf: StarItem? = null,
        val revising: StarItem? = null,
        val floatingKept: StarItem? = null,
    ) : MainNav
    data class ConstellationStory(val month: String) : MainNav
    data object MilkyWay : MainNav
    data class NebulaStars(val kind: NebulaStarKind = NebulaStarKind.Floated) : MainNav
}

/** The main shell (iOS MainView): four tabs, the write FAB, the menu button and the drawer. */
@Composable
fun MainScreen(model: AppModel) {
    var tab by rememberSaveable { mutableStateOf(SkyTab.Sky) }
    var drawerOpen by remember { mutableStateOf(false) }
    var showWelcome by remember { mutableStateOf(false) }
    var navStack by remember { mutableStateOf<List<MainNav>>(emptyList()) }
    val scope = rememberCoroutineScope()
    val prefs = LocalContext.current.getSharedPreferences("app", 0)
    val compose = { navStack = navStack + MainNav.Compose() }

    BackHandler(enabled = drawerOpen) { drawerOpen = false }
    BackHandler(enabled = !drawerOpen && navStack.isNotEmpty()) { navStack = navStack.dropLast(1) }
    BackHandler(enabled = !drawerOpen && navStack.isEmpty() && tab != SkyTab.Sky) { tab = SkyTab.Sky }

    Box(Modifier.fillMaxSize()) {
        StarField()
        Column(Modifier.fillMaxSize()) {
            Box(Modifier.weight(1f).fillMaxWidth().statusBarsPadding()) {
                when (tab) {
                    SkyTab.Sky -> when (model.starCount) {
                        0 -> {
                            FirstNightSky(onCompose = compose)
                            LaunchedEffect(Unit) {
                                if (!prefs.getBoolean("seen_welcome", false)) {
                                    prefs.edit().putBoolean("seen_welcome", true).apply()
                                    showWelcome = true
                                }
                            }
                        }
                        null -> Unit
                        else -> Home(
                            model = model,
                            stars = model.stars,
                            onCompose = compose,
                            onSeeAll = { tab = SkyTab.Records },
                            onOpenStar = { star -> navStack = navStack + MainNav.StarDetail(star.id) },
                            onOpenConstellation = { tab = SkyTab.Nebula },
                        )
                    }
                    SkyTab.Nebula -> ConstellationView(
                        model = model,
                        onOpen = { title ->
                            when (title) {
                                "나의 은하수" -> navStack = navStack + MainNav.MilkyWay
                                "떠 있는 별" -> navStack = navStack + MainNav.NebulaStars(NebulaStarKind.Floated)
                                "깊은 별" -> navStack = navStack + MainNav.NebulaStars(NebulaStarKind.Deep)
                                else -> model.message = "$title 화면을 열어요."
                            }
                        },
                        onStory = { month ->
                            navStack = navStack + MainNav.ConstellationStory(month)
                        },
                        onOpenStar = { star ->
                            navStack = navStack + MainNav.StarDetail(star.id)
                        },
                    )
                    else -> ComingSoon(tab.title)
                }
                MenuButton(Modifier.align(Alignment.TopEnd).padding(end = 16.dp, top = 2.dp)) { drawerOpen = true }
            }
            SkyTabBar(tab, onSelect = { tab = it }, onCompose = compose)
        }
        Drawer(model, open = drawerOpen, onClose = { drawerOpen = false }, onSelect = { title ->
            drawerOpen = false
            when (title) {
                "별빛 기록" -> tab = SkyTab.Records
                else -> model.message = "$title 화면은 다음 단계에서 만들어요."
            }
        })

        when (val top = navStack.lastOrNull()) {
            is MainNav.StarDetail -> {
                StarDetailScreen(
                    model = model,
                    starId = top.starId,
                    onBack = { navStack = navStack.dropLast(1) },
                    onRewrite = {
                        val s = model.stars.firstOrNull { it.id == top.starId }
                        if (s != null) navStack = navStack + MainNav.Compose(rewriteOf = s)
                    },
                    onEdit = { navStack = navStack + MainNav.StarEdit(top.starId) },
                    onFloat = {
                        val s = model.stars.firstOrNull { it.id == top.starId }
                        if (s != null) navStack = navStack + MainNav.Compose(floatingKept = s)
                    },
                    onRevise = {
                        val s = model.stars.firstOrNull { it.id == top.starId }
                        if (s != null) navStack = navStack + MainNav.Compose(revising = s)
                    },
                    onLinkExisting = { navStack = navStack + MainNav.LinkExisting(top.starId) },
                    onOpenLinked = { other -> navStack = navStack + MainNav.StarDetail(other.id) },
                    onDeleted = { navStack = navStack.dropLast(1) },
                )
            }
            is MainNav.StarEdit -> {
                StarEditScreen(
                    model = model,
                    starId = top.starId,
                    onClose = { navStack = navStack.dropLast(1) },
                )
            }
            is MainNav.LinkExisting -> {
                LinkStarsScreen(
                    model = model,
                    starId = top.starId,
                    onBack = { navStack = navStack.dropLast(1) },
                    onLinked = { navStack = navStack.dropLast(1) },
                )
            }
            is MainNav.Compose -> {
                ComposeFlow(
                    model = model,
                    rewriteOf = top.rewriteOf,
                    revising = top.revising,
                    floatingKept = top.floatingKept,
                    onClose = { navStack = navStack.dropLast(1) },
                    onShowNebula = {
                        navStack = navStack.dropLast(1)
                        tab = SkyTab.Nebula
                    },
                    onOpenStar = { star ->
                        navStack = navStack.dropLast(1) + MainNav.StarDetail(star.id)
                    },
                )
            }
            is MainNav.ConstellationStory -> {
                ConstellationStoryView(
                    model = model,
                    month = top.month,
                    onBack = { navStack = navStack.dropLast(1) },
                    onOpenStar = { star -> navStack = navStack + MainNav.StarDetail(star.id) },
                )
            }
            is MainNav.MilkyWay -> {
                MilkyWayView(
                    model = model,
                    onBack = { navStack = navStack.dropLast(1) },
                    onOpenStar = { star -> navStack = navStack + MainNav.StarDetail(star.id) },
                )
            }
            is MainNav.NebulaStars -> {
                NebulaStarsView(
                    model = model,
                    initialKind = top.kind,
                    onBack = { navStack = navStack.dropLast(1) },
                    onOpenStar = { star -> navStack = navStack + MainNav.StarDetail(star.id) },
                )
            }
            null -> Unit
        }
    }
    if (showWelcome) WelcomeSheet(onCompose = { showWelcome = false; compose() }, onBrowse = { showWelcome = false })
}

/** iOS SkyHeader: "오늘" (H1) and a subtitle. */
@Composable
private fun SkyHeader(subtitle: String) {
    Column(Modifier.fillMaxWidth().semantics(mergeDescendants = true) { heading() }, verticalArrangement = Arrangement.spacedBy(Space.xs)) {
        Text("오늘", style = YText.h1, color = YColor.textPrimary)
        Text(subtitle, style = YText.bodyM, color = YColor.textSecondary)
    }
}

/** 03 첫 밤하늘: no stars yet. */
@Composable
private fun FirstNightSky(onCompose: () -> Unit) {
    val a = sky()
    Column(
        Modifier.fillMaxSize().padding(start = Space.xl, end = Space.xl, top = Space.lg, bottom = Space.xl),
        verticalArrangement = Arrangement.spacedBy(Space.xl),
    ) {
        SkyHeader("첫 별을 기다리고 있어요")
        Column(
            Modifier.weight(1f).fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(Space.xl, Alignment.CenterVertically),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Box(
                Modifier.size(160.dp).cosmos("empty-slot", CircleShape).drawBehind {
                    val w = 1.dp.toPx()
                    drawCircle(a.brandPrimary, radius = size.minDimension / 2 - w / 2, center = Offset(size.width / 2, size.height / 2),
                        style = Stroke(w, pathEffect = PathEffect.dashPathEffect(floatArrayOf(4.dp.toPx(), 6.dp.toPx()))))
                },
                contentAlignment = Alignment.Center,
            ) {
                Image(painterResource(R.drawable.empty_slot_star), null,
                    Modifier.size(36.dp).twinkle(Twinkle(2.0, listOf(0.0 to 1.0, 0.255 to 0.3, 0.63 to 1.0, 1.0 to 0.3)), dimScale))
            }
            Column(verticalArrangement = Arrangement.spacedBy(Space.sm), horizontalAlignment = Alignment.CenterHorizontally) {
                Text("아직 떠 있는 별이 없어요", style = YText.h3, color = YColor.textPrimary, textAlign = TextAlign.Center)
                Text("마음에 머무는 이야기를 적으면\n첫 별이 조용히 떠올라요.", style = YText.bodyM, color = YColor.textSecondary, textAlign = TextAlign.Center)
            }
            PrimaryButton("첫 별 만들기", onClick = onCompose)
            Text("별 띄우기는 하루 한 번 무료예요", style = YText.caption, color = YColor.starBright)
        }
    }
}

/** 04 홈 · 오늘 */
@Composable
private fun Home(
    model: AppModel,
    stars: List<StarItem>,
    onCompose: () -> Unit,
    onSeeAll: () -> Unit,
    onOpenStar: (StarItem) -> Unit = {},
    onOpenConstellation: () -> Unit = {},
) {
    val a = sky()
    val today = LocalDate.now().format(DateTimeFormatter.ofPattern("M월 d일 EEEE", Locale.KOREAN))
    Column(
        Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = Space.xl, vertical = Space.lg),
        verticalArrangement = Arrangement.spacedBy(Space.lg),
    ) {
        SkyHeader("$today · 오늘은 어떤 마음이 머물렀나요?")
        PrimaryButton("오늘의 별 만들기", onClick = onCompose)

        Row(
            Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(
                "최근 별",
                style = YText.labelM,
                color = YColor.textSecondary,
                modifier = Modifier.semantics { heading() },
            )
            Row(
                Modifier.noRippleClick(onSeeAll),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(2.dp),
            ) {
                Text("전체 보기", style = YText.labelS, color = a.borderFocus)
                Icon(
                    painterResource(R.drawable.icon_chevron_right),
                    null,
                    Modifier.size(16.dp),
                    tint = a.borderFocus,
                )
            }
        }

        Column(verticalArrangement = Arrangement.spacedBy(Space.md)) {
            stars.take(4).forEach { star ->
                StarRow(star = star, onClick = { onOpenStar(star) })
            }
        }

        // 04 홈 맨 아래 한 줄 링크: MonthConstellationLink
        MonthConstellationLink(
            model = model,
            onOpen = onOpenConstellation,
        )
    }
}

@Composable
private fun ComingSoon(title: String) {
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Text("$title · 다음 단계에서 만들어요", style = YText.bodyM, color = YColor.textTertiary)
    }
}

/** iOS SkyTabBar: 64dp bar on bg/surface with a Cosmos BG and a top rule; the FAB rises 25dp above it. */
@Composable
private fun SkyTabBar(selection: SkyTab, onSelect: (SkyTab) -> Unit, onCompose: () -> Unit) {
    val a = sky()
    Box(Modifier.fillMaxWidth()) {
        Column(
            Modifier.fillMaxWidth()
                .background(YColor.bgSurface)
                .cosmos("tab-bar")
                .drawBehind { drawRect(YColor.borderDefault, size = size.copy(height = 1.dp.toPx())) }
                .navigationBarsPadding(),
        ) {
            Row(
                Modifier.fillMaxWidth().padding(top = 5.dp).height(64.dp).padding(horizontal = 12.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                TabItem(SkyTab.Sky, selection, onSelect)
                TabItem(SkyTab.Nebula, selection, onSelect)
                Spacer(Modifier.width(70.dp))
                TabItem(SkyTab.Plaza, selection, onSelect)
                TabItem(SkyTab.Records, selection, onSelect)
            }
        }
        // FAB center sits 5dp below the bar's top edge.
        Box(
            Modifier.align(Alignment.TopCenter).offset(y = (5 - 30).dp).size(60.dp)
                .dropShadow(CircleShape, Shadow(radius = 24.dp, color = a.tint.copy(alpha = 0.4f)))
                .background(Brush.verticalGradient(listOf(a.top, a.bottom)), CircleShape)
                .border(4.dp, YColor.bgSurface, CircleShape)
                .noRippleClick(onCompose)
                .semantics { contentDescription = "별 만들기" },
            contentAlignment = Alignment.Center,
        ) { WriteStarIcon() }
    }
}

@Composable
private fun TabItem(tab: SkyTab, selection: SkyTab, onSelect: (SkyTab) -> Unit) {
    val active = tab == selection
    val color = if (active) YColor.starBright else YColor.textTertiary
    Column(
        Modifier.width(70.dp).height(52.dp).noRippleClick { onSelect(tab) }.semantics { selected = active },
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        Box(Modifier.size(4.dp), contentAlignment = Alignment.Center) {
            if (active) Image(painterResource(R.drawable.tab_dot_active), null, Modifier.requiredSize(60.dp))
        }
        Icon(painterResource(tab.icon), null, Modifier.size(24.dp), tint = color)
        Text(tab.title, style = YText.captionTab, color = color, maxLines = 1, softWrap = false)
    }
}

/** Figma Icon/write-star: pencil + a sparkle that pulses (6s, 0.8 → 1.25 → 1.15). */
@Composable
private fun WriteStarIcon() {
    val reduced = LocalMotionReduced.current
    val clock = rememberClock()
    val pulse = Twinkle(6.0, listOf(0.0 to 0.8, 0.25 to 1.25, 0.5 to 1.1457))
    Box(Modifier.size(26.dp)) {
        Image(painterResource(R.drawable.fab_pencil), null, Modifier.align(Alignment.Center).offset((-1.67).dp, 1.68.dp).size(15.775.dp))
        Image(painterResource(R.drawable.fab_sparkle), null,
            Modifier.align(Alignment.Center).offset(7.56.dp, (-8.13).dp).size(4.98.dp).graphicsLayer {
                val s = if (reduced) 1f else pulse.value(clock.value).toFloat()
                scaleX = s; scaleY = s
            })
    }
}

private data class DrawerItem(val title: String, val subtitle: String, val icon: Int)

private val drawerItems = listOf(
    DrawerItem("별빛 기록", "지나온 별들", R.drawable.icon_star),
    DrawerItem("알림", "운영자 조치 · 공지", R.drawable.icon_bell),
    DrawerItem("코인", "충전 · 사용 내역", R.drawable.icon_coin),
    DrawerItem("설정", "알림 · 데이터 · 약관", R.drawable.icon_settings),
    DrawerItem("문의하기", "궁금한 점 보내기", R.drawable.icon_mail),
)

/** 67-1 서랍: slides in from the right, min(320, 84%) wide, over a 0.65 scrim. */
@Composable
private fun Drawer(model: AppModel, open: Boolean, onClose: () -> Unit, onSelect: (String) -> Unit) {
    val progress by animateFloatAsState(if (open) 1f else 0f, spring(dampingRatio = 0.9f, stiffness = 500f), label = "drawer")
    if (progress == 0f && !open) return
    BoxWithConstraints(Modifier.fillMaxSize()) {
        val width = minOf(320.dp, maxWidth * 0.84f)
        Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.65f * progress)).noRippleClick(onClose))
        val shape = RoundedCornerShape(topStart = Radius.xl, bottomStart = Radius.xl)
        Column(
            Modifier.align(Alignment.CenterEnd).width(width).fillMaxHeight()
                .offset(x = width * (1 - progress))
                .dropShadow(shape, Shadow(radius = 24.dp, color = Color.Black.copy(alpha = 0.4f), offset = androidx.compose.ui.unit.DpOffset(0.dp, 8.dp)))
                .background(YColor.bgSurfaceRaised, shape)
                .cosmos("menu", shape)
                .border(1.dp, YColor.borderDefault, shape)
                .noRippleClick { }
                .statusBarsPadding().navigationBarsPadding()
                .verticalScroll(rememberScrollState())
                .padding(start = Space.sm, end = Space.sm, top = Space.lg),
            verticalArrangement = Arrangement.spacedBy(2.dp),
        ) {
            Row(Modifier.padding(horizontal = 12.dp, vertical = 4.dp), verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Box(Modifier.size(40.dp), contentAlignment = Alignment.Center) {
                    LogoMark(LogoSize.Large, Modifier.requiredSize(112.dp).graphicsLayer { scaleX = 40f / 112f; scaleY = 40f / 112f })
                }
                Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text("YOUNIYA", fontFamily = NotoSerifKR, fontWeight = FontWeight.SemiBold, fontSize = 20.sp, letterSpacing = 1.6.sp, color = YColor.textPrimary)
                    Text("텍스트로 시각화한 우리 모두의 우주", style = YText.caption, color = YColor.textSecondary)
                }
            }
            model.providerName?.let { p ->
                Spacer(Modifier.height(Space.md))
                DrawerRow(DrawerItem(model.nickname ?: "별지기 이름을 정해 주세요",
                    if (p == "초대 계정") "초대 계정으로 로그인 · 계정 보기" else "${p}로 로그인 · 계정 보기", R.drawable.icon_user), null) { onSelect("설정") }
            }
            Box(Modifier.padding(start = 12.dp, end = 12.dp, top = Space.xl - 4.dp, bottom = Space.md - 2.dp).fillMaxWidth().height(1.dp).background(YColor.borderDefault))
            drawerItems.forEach { item ->
                DrawerRow(item, if (item.title == "코인") "%,d코인".format(model.coins) else null) { onSelect(item.title) }
            }
            Spacer(Modifier.height(Space.lg))
            GhostButton("로그아웃 (개발용)", compact = true) { onClose(); model.signOut() }
        }
    }
}

@Composable
private fun DrawerRow(item: DrawerItem, trailing: String?, onClick: () -> Unit) {
    val a = sky()
    Row(
        Modifier.fillMaxWidth().noRippleClick(onClick).padding(horizontal = 12.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Box(Modifier.size(36.dp).background(a.tintPrimary, RoundedCornerShape(Radius.md)), contentAlignment = Alignment.Center) {
            Icon(painterResource(item.icon), null, Modifier.size(18.dp), tint = a.brandPrimary)
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(item.title, style = YText.labelM, color = YColor.textPrimary)
            Text(item.subtitle, style = YText.caption, color = YColor.textTertiary)
        }
        trailing?.let { Text(it, style = YText.labelM, color = YColor.starBright) }
    }
}

/** 03-1 첫 로그인 환영 안내: once per device. */
@Composable
private fun WelcomeSheet(onCompose: () -> Unit, onBrowse: () -> Unit) {
    val a = sky()
    YouniyaSheet("welcome-sheet", onBrowse) {
        Column(
            Modifier.padding(start = Space.xl, end = Space.xl, top = Space.md, bottom = Space.xxl),
            verticalArrangement = Arrangement.spacedBy(Space.lg),
        ) {
            SheetGrabber()
            Column(Modifier.semantics(mergeDescendants = true) { heading() }, verticalArrangement = Arrangement.spacedBy(Space.sm)) {
                Text("YOUNIYA에 오신 걸 환영해요", style = YText.h3, color = YColor.textPrimary)
                Text("시작하기 전에 세 가지만 알려 드릴게요.", style = YText.bodyM, color = YColor.textSecondary)
            }
            Column(verticalArrangement = Arrangement.spacedBy(Space.lg)) {
                listOf(
                    Triple(R.drawable.icon_star, "쓴 마음은 단 하나뿐인 별이 돼요", "같은 모양의 별은 하나도 없어요."),
                    Triple(R.drawable.icon_lock, "나누는 건 내가 고른 별뿐이에요", "우주 광장에는 내가 나누기로 고른 별만 별지기 이름과 함께 올라가요."),
                    Triple(R.drawable.icon_shield, "쓴 글은 AI 학습에 쓰이지 않아요", "언제든 모두 지울 수 있어요. 상담이나 진단을 대신하지는 않아요."),
                ).forEach { (icon, title, detail) ->
                    Row(Modifier.semantics(mergeDescendants = true) {}, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                        Box(
                            Modifier.size(40.dp).background(a.tint.copy(alpha = 0.16f), CircleShape).border(1.dp, a.tint.copy(alpha = 0.5f), CircleShape),
                            contentAlignment = Alignment.Center,
                        ) { Icon(painterResource(icon), null, Modifier.size(24.dp), tint = YColor.textPrimary) }
                        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(Space.xs)) {
                            Text(title, fontFamily = Pretendard, fontWeight = FontWeight.Medium, fontSize = 15.sp, color = YColor.textPrimary)
                            Text(detail, style = YText.bodyS, color = YColor.textSecondary)
                        }
                    }
                }
            }
            Column(verticalArrangement = Arrangement.spacedBy(Space.md)) {
                PrimaryButton("첫 별 만들기", onClick = onCompose)
                GhostButton("먼저 둘러볼게요", onClick = onBrowse)
            }
        }
    }
}
