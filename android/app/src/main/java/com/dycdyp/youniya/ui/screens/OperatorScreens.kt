package com.dycdyp.youniya.ui.screens

import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.activity.compose.BackHandler
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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
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
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.dycdyp.youniya.data.AppModel
import com.dycdyp.youniya.data.formatKstShortDate
import com.dycdyp.youniya.ui.components.TopAppBar
import com.dycdyp.youniya.ui.components.noRippleClick
import com.dycdyp.youniya.ui.design.StarField
import com.dycdyp.youniya.ui.design.cosmos
import com.dycdyp.youniya.ui.theme.Radius
import com.dycdyp.youniya.ui.theme.Space
import com.dycdyp.youniya.ui.theme.YColor
import com.dycdyp.youniya.ui.theme.YText
import com.dycdyp.youniya.ui.theme.sky

sealed interface NotificationTarget {
    data class Star(val starId: String) : NotificationTarget
    data object Nickname : NotificationTarget
    data object PlazaRestricted : NotificationTarget
    data object Plaza : NotificationTarget
    data object CoinHistory : NotificationTarget
    data class Notice(val noticeId: String) : NotificationTarget
    data object NotificationSettings : NotificationTarget
    data object Inbox : NotificationTarget

    val label: String?
        get() = when (this) {
            is Star -> "별 보기"
            is Nickname -> "이름 바꾸기"
            is PlazaRestricted -> "자세히"
            is Plaza -> "우주 광장"
            is CoinHistory -> "코인 사용 내역"
            is Notice -> "공지 보기"
            is NotificationSettings -> "설정 › 알림"
            is Inbox -> null
        }

    companion object {
        fun from(map: Map<String, Any?>?): NotificationTarget? {
            if (map == null) return null
            return when (map["screen"] as? String) {
                "star" -> (map["star_id"] as? String)?.let { Star(it) } ?: Inbox
                "nickname" -> Nickname
                "plaza_restricted" -> PlazaRestricted
                "plaza" -> Plaza
                "coin_history" -> CoinHistory
                "notice" -> (map["notice_id"] as? String)?.let { Notice(it) } ?: Inbox
                "notification_settings" -> NotificationSettings
                "notifications" -> Inbox
                else -> null
            }
        }

        fun fromJson(obj: kotlinx.serialization.json.JsonObject?): NotificationTarget? {
            if (obj == null) return null
            val screen = obj["screen"]?.let { if (it is kotlinx.serialization.json.JsonPrimitive) it.content else null } ?: return null
            return when (screen) {
                "star" -> obj["star_id"]?.let { if (it is kotlinx.serialization.json.JsonPrimitive) it.content else null }?.let { Star(it) } ?: Inbox
                "nickname" -> Nickname
                "plaza_restricted" -> PlazaRestricted
                "plaza" -> Plaza
                "coin_history" -> CoinHistory
                "notice" -> obj["notice_id"]?.let { if (it is kotlinx.serialization.json.JsonPrimitive) it.content else null }?.let { Notice(it) } ?: Inbox
                "notification_settings" -> NotificationSettings
                "notifications" -> Inbox
                else -> null
            }
        }

        fun fromJsonString(jsonStr: String?): NotificationTarget? {
            if (jsonStr.isNullOrBlank()) return Inbox
            return runCatching {
                val element = com.dycdyp.youniya.data.ApiJson.parseToJsonElement(jsonStr)
                if (element is kotlinx.serialization.json.JsonObject) fromJson(element) else Inbox
            }.getOrDefault(Inbox)
        }
    }
}

data class InboxItem(
    val id: String,
    val kind: String,
    val title: String,
    val body: String,
    val target: NotificationTarget?,
    val createdAt: String?,
    val read: Boolean,
)

data class AppNoticeItem(
    val id: String,
    val title: String,
    val body: String,
    val publishedAt: String?,
)

/**
 * 130 알림 (iOS InboxView)
 */
@Composable
fun InboxView(
    model: AppModel,
    onBack: () -> Unit,
    onOpen: (NotificationTarget) -> Unit,
    modifier: Modifier = Modifier,
) {
    var loaded by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        model.loadInbox()
        loaded = true
    }

    BackHandler(onBack = onBack)
    Box(modifier.fillMaxSize()) {
        StarField()
        Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding()) {
            TopAppBar(title = "알림", onBack = onBack)

            LazyColumn(
                modifier = Modifier
                    .weight(1f)
                    .padding(horizontal = Space.xl)
                    .padding(vertical = Space.sm),
                verticalArrangement = Arrangement.spacedBy(Space.md),
            ) {
                item {
                    Text(
                        "운영자 조치와 공지를 모아 둬요. 누르면 관련 화면으로 가요.",
                        style = YText.caption,
                        color = YColor.textTertiary,
                    )
                }

                if (model.inbox.isEmpty() && loaded) {
                    item {
                        Text(
                            "아직 받은 알림이 없어요. 운영자 조치와 공지가 생기면 여기에 모여요.",
                            style = YText.bodyM,
                            color = YColor.textTertiary,
                            textAlign = TextAlign.Center,
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(vertical = Space.xxxl),
                        )
                    }
                }

                items(model.inbox, key = { it.id }) { item ->
                    InboxRow(
                        item = item,
                        onClick = {
                            model.markRead(listOf(item.id))
                            if (item.target != null && item.target != NotificationTarget.Inbox) {
                                onOpen(item.target)
                            }
                        },
                    )
                }
            }
        }
    }
}

@Composable
private fun InboxRow(
    item: InboxItem,
    onClick: () -> Unit,
) {
    val a = sky()
    val shape = RoundedCornerShape(Radius.lg)
    val (label, color) = when (item.target) {
        is NotificationTarget.Notice -> "공지" to a.text
        is NotificationTarget.Nickname -> "운영자 요청" to YColor.starBright
        is NotificationTarget.PlazaRestricted -> "이용 제한" to YColor.brandWarm
        is NotificationTarget.Plaza -> "이용 제한 해제" to YColor.emotionCalm
        is NotificationTarget.Star -> "광장에서 내려감" to YColor.emotionAnger
        is NotificationTarget.CoinHistory -> "코인" to YColor.starClear
        is NotificationTarget.NotificationSettings -> "알림 동의" to YColor.textSecondary
        NotificationTarget.Inbox, null -> if (item.kind == "report_result") "신고 처리 결과" to YColor.emotionCalm else "알림" to YColor.textSecondary
    }

    val dateText = formatKstShortDate(item.createdAt) ?: ""
    val targetLabel = item.target?.label?.let { "$it ›" }
    val footer = listOfNotNull(dateText.ifEmpty { null }, targetLabel).joinToString(" · ")

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(shape)
            .background(YColor.bgSurface, shape)
            .cosmos("inbox-${item.id}", shape, intensity = 0.5)
            .border(1.dp, YColor.borderDefault, shape)
            .alpha(if (item.read) 0.85f else 1f)
            .noRippleClick(onClick)
            .padding(Space.lg),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(Space.md),
            verticalAlignment = Alignment.Top,
        ) {
            // Unread / Read indicator dot
            Box(
                modifier = Modifier
                    .padding(top = 5.dp)
                    .size(7.dp)
                    .background(color.copy(alpha = if (item.read) 0.35f else 1f), CircleShape),
            )

            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(Space.xs),
            ) {
                Text(label, style = YText.caption, color = color)
                Text(item.title, style = YText.labelM, color = YColor.textPrimary)
                Text(
                    item.body,
                    style = YText.bodyS,
                    color = YColor.textSecondary,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
                if (footer.isNotEmpty()) {
                    Text(footer, style = YText.caption, color = YColor.textTertiary)
                }
            }
        }
    }
}

/**
 * 131 공지 상세 (iOS NoticeDetailView)
 */
@Composable
fun NoticeDetailView(
    model: AppModel,
    noticeId: String,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val notice = model.notices.firstOrNull { it.id == noticeId }

    LaunchedEffect(noticeId) {
        if (notice == null) {
            model.loadNotices()
        }
    }

    BackHandler(onBack = onBack)
    Box(modifier.fillMaxSize()) {
        StarField()
        Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding()) {
            TopAppBar(title = "공지", onBack = onBack)

            Column(
                modifier = Modifier
                    .weight(1f)
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = Space.xl)
                    .padding(vertical = Space.sm),
                verticalArrangement = Arrangement.spacedBy(Space.md),
            ) {
                if (notice != null) {
                    val dateText = formatKstShortDate(notice.publishedAt) ?: ""
                    Text(
                        "$dateText · 공지",
                        style = YText.caption,
                        color = YColor.textTertiary,
                    )
                    Text(
                        notice.title,
                        style = YText.h2,
                        color = YColor.textPrimary,
                        modifier = Modifier.semantics { heading() },
                    )
                    Text(
                        notice.body,
                        style = YText.bodyM,
                        color = YColor.textSecondary,
                    )
                }
            }
        }
    }
}
