package com.dycdyp.youniya.ui.screens

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import com.dycdyp.youniya.R
import com.dycdyp.youniya.data.ApiError
import com.dycdyp.youniya.data.AppModel
import com.dycdyp.youniya.data.StarDraft
import com.dycdyp.youniya.data.StarItem
import com.dycdyp.youniya.ui.components.ActionSheetContent
import com.dycdyp.youniya.ui.components.noRippleClick
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.util.UUID

private sealed interface ComposeStep {
    data object Writing : ComposeStep
    data class Reading(val attemptId: String, val draft: StarDraft) : ComposeStep
    data class Birth(val star: StarItem) : ComposeStep
    data class Card(val star: StarItem) : ComposeStep
    data class Crisis(val star: StarItem, val floated: Boolean) : ComposeStep
    data class SendFailed(val draft: StarDraft, val floated: Boolean) : ComposeStep
    data class AnalysisFailed(val star: StarItem) : ComposeStep
}

/**
 * Full-screen compose flow (iOS ComposeFlowView):
 * Writing -> Confirm (05-3) -> Reading (06) -> Birth (61~64) -> Card (07-1).
 * Unlit: Writing -> Birth -> Home.
 */
@Composable
fun ComposeFlow(
    model: AppModel,
    onClose: () -> Unit,
    onShowNebula: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var step by remember { mutableStateOf<ComposeStep>(ComposeStep.Writing) }
    var confirmFloatDraft by remember { mutableStateOf<StarDraft?>(null) }
    var showShortage by remember { mutableStateOf(false) }
    var shortageDraft by remember { mutableStateOf<StarDraft?>(null) }

    var stopping by remember { mutableStateOf(false) }
    var stopped by remember { mutableStateOf(false) }
    var readingElapsedMs by remember { mutableLongStateOf(0L) }

    val scope = rememberCoroutineScope()

    fun stopReading(attemptId: String) {
        if (stopping) return
        stopping = true
        scope.launch {
            val (wasStopped, _) = model.stopStarlight(attemptId)
            if (wasStopped) {
                stopped = true
                model.loadCoins()
                model.message = "별빛 받기를 그만뒀어요. 무료와 코인은 그대로예요."
                onClose()
            } else {
                stopping = false
                model.message = "그만두지 못했어요. 조금만 더 기다려 주세요"
            }
        }
    }

    fun startReading(draft: StarDraft) {
        val attemptId = UUID.randomUUID().toString().lowercase()
        stopping = false
        stopped = false
        readingElapsedMs = 0L
        step = ComposeStep.Reading(attemptId, draft)

        scope.launch {
            try {
                val (star, crisis) = model.publishLit(draft, attemptId)
                if (stopped) return@launch

                model.loadCoins()
                if (crisis) {
                    step = ComposeStep.Crisis(star, floated = false)
                } else if (star.isFloated && star.analysis != null) {
                    step = ComposeStep.Birth(star)
                } else {
                    step = ComposeStep.AnalysisFailed(star)
                }
            } catch (e: ApiError) {
                android.util.Log.w("YouniyaFlow", "lit failed ${e.status} ${e.code} ${e.message}")
                if (stopped) return@launch

                when {
                    e.code == "offline" -> {
                        scope.launch { model.stopStarlight(attemptId) }
                        step = ComposeStep.SendFailed(draft, floated = true)
                    }
                    e.status == 402 -> {
                        step = ComposeStep.Writing
                        shortageDraft = draft
                        showShortage = true
                        model.loadCoins()
                    }
                    e.status == 409 && e.code == "starlight_cancelled" -> {
                        model.message = "별빛 받기를 그만뒀어요. 무료와 코인은 그대로예요."
                        val starId = e.starId
                        if (starId != null) {
                            scope.launch { model.starAfterStop(starId) }
                        }
                        onClose()
                    }
                    e.status == 502 || e.code == "analysis_failed" -> {
                        val kept = e.starId?.let { model.starAfterStop(it) } ?: model.stars.firstOrNull()
                        if (kept != null) {
                            step = ComposeStep.AnalysisFailed(kept)
                        } else {
                            step = ComposeStep.Writing
                            model.message = "별을 읽지 못했어요. 글은 그대로 보관돼요."
                        }
                    }
                    e.status == 422 -> {
                        step = ComposeStep.Writing
                        model.message = e.message
                    }
                    else -> {
                        step = ComposeStep.Writing
                        model.handle(e)
                    }
                }
            } catch (e: Exception) {
                android.util.Log.w("YouniyaFlow", "lit failed", e)
                if (stopped) return@launch
                step = ComposeStep.Writing
                model.handle(e)
            }
        }
    }

    fun publishUnlit(draft: StarDraft) {
        scope.launch {
            val res = model.publish(draft, floated = false)
            if (res != null) {
                val (star, crisis) = res
                if (crisis) {
                    step = ComposeStep.Crisis(star, floated = false)
                } else {
                    step = ComposeStep.Birth(star)
                }
            }
        }
    }

    // Reading timer to measure slow threshold (8s)
    LaunchedEffect(step) {
        if (step is ComposeStep.Reading) {
            val start = System.currentTimeMillis()
            while (step is ComposeStep.Reading) {
                readingElapsedMs = System.currentTimeMillis() - start
                delay(100)
            }
        }
    }

    // System Back handling
    when (val currentStep = step) {
        is ComposeStep.Reading -> {
            val canStop = readingElapsedMs >= 8000L
            BackHandler(enabled = true) {
                if (canStop) {
                    stopReading(currentStep.attemptId)
                }
            }
        }
        is ComposeStep.Card -> {
            BackHandler(enabled = true) {
                onClose()
            }
        }
        is ComposeStep.Birth -> {
            BackHandler(enabled = true) {
                onClose()
            }
        }
        is ComposeStep.Crisis -> {
            BackHandler(enabled = true) {
                onClose()
            }
        }
        is ComposeStep.SendFailed, is ComposeStep.AnalysisFailed -> {
            BackHandler(enabled = true) {
                onClose()
            }
        }
        is ComposeStep.Writing -> {
            // StarMakingScreen manages its own back press (leave sheet)
        }
    }

    Box(modifier = modifier.fillMaxSize().noRippleClick { }) {
        when (val s = step) {
            is ComposeStep.Writing -> {
                StarMakingScreen(
                    model = model,
                    onClose = onClose,
                    onPublish = { draft, floated ->
                        if (floated) {
                            if (draft.body.length < AppModel.minFloatLength) {
                                model.message = "${AppModel.minFloatLength}자부터 별빛을 받을 수 있어요"
                                return@StarMakingScreen
                            }
                            if (model.floatNeedsCharge) {
                                shortageDraft = draft
                                showShortage = true
                            } else {
                                confirmFloatDraft = draft
                            }
                        } else {
                            publishUnlit(draft)
                        }
                    },
                )
            }

            is ComposeStep.Reading -> {
                PrismAnalysisView(
                    isReading = true,
                    stopping = stopping,
                    onStop = { stopReading(s.attemptId) },
                )
            }

            is ComposeStep.Birth -> {
                StarBirthView(
                    shape = s.star.shape,
                    color = s.star.mood.color,
                    unlit = !s.star.isFloated,
                    onShow = {
                        if (!s.star.isFloated) {
                            onClose()
                        } else {
                            step = ComposeStep.Card(s.star)
                        }
                    },
                )
            }

            is ComposeStep.Card -> {
                StarCardView(
                    star = s.star,
                    onClose = onClose,
                    onShowNebula = onShowNebula,
                )
            }

            is ComposeStep.Crisis -> {
                CrisisCareView(
                    onContinue = {
                        step = ComposeStep.Birth(s.star)
                    },
                )
            }

            is ComposeStep.SendFailed -> {
                StatusView(
                    icon = R.drawable.icon_wifi_off,
                    title = "연결이 잠시 끊겼어요",
                    message = "쓰던 글은 이 기기에 안전하게 있어요.",
                    actions = listOf(
                        StatusAction(
                            title = "다시 시도",
                            style = StatusAction.Style.Primary,
                            run = {
                                if (s.floated) startReading(s.draft) else publishUnlit(s.draft)
                            },
                        ),
                    ),
                )
            }

            is ComposeStep.AnalysisFailed -> {
                StatusView(
                    icon = R.drawable.icon_warning,
                    title = "별을 읽지 못했어요",
                    message = "글은 그대로 보관되고, 코인도 차감되지 않았어요.",
                    actions = listOf(
                        StatusAction(
                            title = "다시 시도",
                            style = StatusAction.Style.Primary,
                            run = {
                                scope.launch {
                                    try {
                                        val floated = model.floatAgain(s.star.id)
                                        step = ComposeStep.Birth(floated)
                                    } catch (e: ApiError) {
                                        if (e.code == "offline") {
                                            model.message = "연결을 확인해 주세요"
                                        } else {
                                            model.handle(e)
                                        }
                                    } catch (e: Exception) {
                                        model.handle(e)
                                    }
                                }
                            },
                        ),
                        StatusAction(
                            title = "별빛 없이 띄우기",
                            style = StatusAction.Style.Secondary,
                            run = {
                                val kept = model.keepInstead(s.star.id) ?: s.star
                                step = ComposeStep.Birth(kept)
                            },
                        ),
                    ),
                )
            }
        }

        // 05-3 / 05-4 별빛을 받아 띄울까요? 확인 시트
        if (confirmFloatDraft != null) {
            val draft = confirmFloatDraft!!
            val floatCostLine = if (model.isFloatFree) {
                "오늘 무료 1번 남았어요."
            } else {
                "오늘 무료를 다 썼어요. 코인 ${AppModel.floatCost}개가 사용돼요(지금 ${model.coins}개)."
            }
            val floatPrimaryTitle = if (model.isFloatFree) {
                "별빛 받고 띄우기 · 오늘 무료 1번"
            } else {
                "별빛 받고 띄우기 · ${AppModel.floatCost}코인"
            }

            YouniyaSheet("float-confirm", onDismiss = { confirmFloatDraft = null }) {
                ActionSheetContent(
                    title = "별빛을 받아 띄울까요?",
                    message = "별빛 프리즘이 글을 읽고 별빛·깊이·고유한 별 모양을 줘요. $floatCostLine\n별빛을 받으면 이 글은 잠겨서 고칠 수 없어요. 고치고 싶으면 '고쳐 쓰기'로 새 별을 만들 수 있어요.",
                    primaryText = floatPrimaryTitle,
                    onPrimary = {
                        confirmFloatDraft = null
                        startReading(draft)
                    },
                    secondaryText = "조금 더 쓸게요",
                    onSecondary = { confirmFloatDraft = null },
                    secondaryIsGhost = true,
                )
            }
        }

        // 29-1 별빛 받기 · 코인 부족 시트
        if (showShortage) {
            YouniyaSheet("float-shortage", onDismiss = { showShortage = false }) {
                ActionSheetContent(
                    title = "코인이 조금 부족해요",
                    message = "오늘 무료 별빛 받기는 이미 썼어요. 별빛을 받으려면 코인 ${AppModel.floatCost}개가 필요해요. 지금 코인 ${model.coins}개예요. 별빛 없이 띄우는 건 무료예요.",
                    primaryText = "코인 충전",
                    onPrimary = {
                        showShortage = false
                        model.message = "코인 충전은 다음 단계에서 만들어요."
                    },
                    secondaryText = "별빛 없이 띄우기",
                    onSecondary = {
                        showShortage = false
                        shortageDraft?.let { publishUnlit(it) }
                    },
                    ghostText = "계속 쓰기",
                    onGhost = { showShortage = false },
                )
            }
        }
    }
}
