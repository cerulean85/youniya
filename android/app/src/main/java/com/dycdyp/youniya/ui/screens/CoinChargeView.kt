package com.dycdyp.youniya.ui.screens

import android.app.Activity
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
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
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.dycdyp.youniya.BuildConfig
import com.dycdyp.youniya.R
import com.dycdyp.youniya.data.AppModel
import com.dycdyp.youniya.data.BillingOutcome
import com.dycdyp.youniya.ui.components.CheckboxRow
import com.dycdyp.youniya.ui.components.PrimaryButton
import com.dycdyp.youniya.ui.components.TopAppBar
import com.dycdyp.youniya.ui.components.noRippleClick
import com.dycdyp.youniya.ui.design.StarField
import com.dycdyp.youniya.ui.design.cosmos
import com.dycdyp.youniya.ui.theme.Radius
import com.dycdyp.youniya.ui.theme.Space
import com.dycdyp.youniya.ui.theme.YColor
import com.dycdyp.youniya.ui.theme.YText
import com.dycdyp.youniya.ui.theme.sky
import kotlinx.coroutines.launch

data class CoinPackage(
    val coins: Int,
    val defaultPrice: String,
    val bonus: Int = 0,
) {
    val defaultPriceText: String
        get() = if (bonus > 0) "$defaultPrice · 보너스 $bonus 포함" else defaultPrice

    companion object {
        val all = listOf(
            CoinPackage(coins = 110, defaultPrice = "₩1,100"),
            CoinPackage(coins = 330, defaultPrice = "₩3,300"),
            CoinPackage(coins = 1100, defaultPrice = "₩9,900", bonus = 100),
        )
    }
}

/**
 * 28 Coin Charge (iOS CoinChargeView, StoreKitCoins & CoinsAPI 대응)
 * Google Play 결제 연동: 상품 목록 · 필수 동의 · 충전하기 · 102 완료 · 38 미완료
 */
@Composable
fun CoinChargeView(
    model: AppModel,
    onBack: () -> Unit,
    onPolicy: () -> Unit,
    onHistory: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val activity = context as? Activity
    val scope = rememberCoroutineScope()

    var selected by remember { mutableStateOf(CoinPackage.all[1]) }
    var agreed by remember { mutableStateOf(false) }
    var charged by remember { mutableStateOf<Int?>(null) }
    var paymentFailed by remember { mutableStateOf(false) }
    var storeUnavailable by remember { mutableStateOf(false) }
    var isPurchasing by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        model.loadCoins()
        model.playBilling.startConnection {
            scope.launch {
                model.playBilling.queryProducts()
            }
        }
    }

    fun charge() {
        if (!agreed || isPurchasing) return
        isPurchasing = true
        paymentFailed = false
        storeUnavailable = false

        if (activity == null) {
            isPurchasing = false
            return
        }

        model.playBilling.launchBilling(
            activity = activity,
            coins = selected.coins,
            userId = model.userId,
        ) { outcome ->
            isPurchasing = false
            when (outcome) {
                is BillingOutcome.Success -> {
                    paymentFailed = false
                    charged = outcome.added
                }
                is BillingOutcome.Pending -> {
                    paymentFailed = true
                }
                is BillingOutcome.StoreUnavailable -> {
                    storeUnavailable = true
                    paymentFailed = true
                }
                is BillingOutcome.Cancelled -> {
                    // 사용자가 취소하면 아무것도 안 함
                }
                is BillingOutcome.Failed -> {
                    if (outcome.code == "purchase_pending") {
                        paymentFailed = true
                    }
                }
            }
        }
    }

    BackHandler(onBack = onBack)
    Box(modifier.fillMaxSize()) {
        StarField()
        Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding()) {
            TopAppBar(title = "코인 충전", onBack = onBack)

            Column(
                modifier = Modifier
                    .weight(1f)
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = Space.xl)
                    .padding(top = Space.sm, bottom = Space.lg),
                verticalArrangement = Arrangement.spacedBy(Space.lg),
            ) {
                Column(
                    verticalArrangement = Arrangement.spacedBy(Space.sm),
                    modifier = Modifier.semantics { heading() },
                ) {
                    Text("코인 충전", style = YText.h1, color = YColor.textPrimary)
                    Text(
                        "필요한 만큼만 충전해요. 기록은 코인 없이도 쓸 수 있어요.",
                        style = YText.bodyM,
                        color = YColor.textSecondary,
                    )
                }

                // Balance & History link
                Row(
                    modifier = Modifier
                        .noRippleClick(onHistory)
                        .padding(vertical = Space.xs),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(Space.xs),
                ) {
                    Text("지금 코인 ${model.coins}개", style = YText.labelS, color = YColor.starBright)
                    Text("· 내역 보기", style = YText.labelS, color = YColor.textSecondary)
                    Icon(
                        painter = painterResource(R.drawable.icon_chevron_right),
                        contentDescription = null,
                        modifier = Modifier.size(14.dp),
                        tint = YColor.textSecondary,
                    )
                }

                CoinHero()

                // Coin packages
                Column(verticalArrangement = Arrangement.spacedBy(Space.md)) {
                    CoinPackage.all.forEach { pkg ->
                        val isSelected = pkg == selected
                        val priceText = model.playBilling.getPriceText(pkg.coins)
                        val hasPlayProduct = model.playBilling.productDetailsMap["coin_${pkg.coins}"] != null

                        CoinPackageCard(
                            pkg = pkg,
                            priceText = priceText,
                            isSelected = isSelected,
                            onClick = {
                                if (BuildConfig.DEBUG && !hasPlayProduct) {
                                    // 디버그 빌드 전용: Play 상품을 못 받는 환경에서는 상품 카드를 누르면 dev purchase
                                    isPurchasing = true
                                    scope.launch {
                                        val outcome = model.playBilling.purchaseDev(pkg.coins)
                                        isPurchasing = false
                                        when (outcome) {
                                            is BillingOutcome.Success -> {
                                                paymentFailed = false
                                                charged = outcome.added
                                            }
                                            is BillingOutcome.Pending -> paymentFailed = true
                                            else -> {}
                                        }
                                    }
                                } else {
                                    selected = pkg
                                }
                            },
                        )
                    }
                }
            }

            // Bottom section: Refund note, required consent, and Charge button
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = Space.xl)
                    .padding(bottom = Space.xl),
                verticalArrangement = Arrangement.spacedBy(Space.lg),
            ) {
                Text(
                    "충전한 코인만큼 남아 있을 때만 환불할 수 있어요.\n환불을 요청하면 코인 사용 내역이 Google Play에 전달돼요.",
                    style = YText.caption,
                    color = YColor.textTertiary,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth(),
                )
                CheckboxRow(
                    label = "(필수) 결제·환불 정책에 동의해요",
                    checked = agreed,
                    onToggle = { agreed = !agreed },
                    onOpen = onPolicy,
                )
                PrimaryButton(
                    text = if (isPurchasing) "결제 중…" else "충전하기",
                    enabled = agreed && !isPurchasing,
                    onClick = ::charge,
                )
            }
        }

        // 102 충전 완료 화면
        charged?.let { amount ->
            StatusView(
                icon = R.drawable.icon_check,
                title = "충전이 끝났어요",
                message = "코인 ${amount}개가 들어왔어요. 지금 코인은 ${model.coins}개예요.",
                actions = listOf(
                    StatusAction(title = "하던 곳으로 돌아가기", style = StatusAction.Style.Primary, run = onBack),
                    StatusAction(title = "코인 사용 내역 보기", style = StatusAction.Style.Ghost, run = onHistory),
                ),
            )
        }

        // 38 결제 미완료 화면
        if (paymentFailed) {
            StatusView(
                icon = R.drawable.icon_lock,
                title = if (storeUnavailable) "지금은 코인을 충전할 수 없어요" else "결제가 끝나지 않았어요",
                message = if (storeUnavailable) {
                    "Google Play에서 코인 상품을 불러오지 못했어요. 결제는 되지 않았어요. 잠시 후 다시 시도해 주세요."
                } else {
                    "코인은 차감되거나 지급되지 않았어요."
                },
                actions = listOf(
                    StatusAction(
                        title = if (storeUnavailable) "다시 시도하기" else "다시 결제하기",
                        style = StatusAction.Style.Primary,
                        run = ::charge,
                    ),
                    StatusAction(
                        title = "닫기",
                        style = StatusAction.Style.Ghost,
                        run = { paymentFailed = false },
                    ),
                ),
            )
        }
    }
}

/** Coin package card */
@Composable
private fun CoinPackageCard(
    pkg: CoinPackage,
    priceText: String,
    isSelected: Boolean,
    onClick: () -> Unit,
) {
    val a = sky()
    val shape = RoundedCornerShape(Radius.lg)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(shape)
            .background(YColor.bgSurface, shape)
            .cosmos("coin${pkg.coins}", shape)
            .border(if (isSelected) 2.dp else 1.dp, if (isSelected) a.brandPrimary else YColor.borderDefault, shape)
            .noRippleClick(onClick)
            .padding(Space.lg),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(Space.xs)) {
            Text("코인 %,d".format(pkg.coins), style = YText.labelM, color = YColor.textPrimary)
            Text(priceText, style = YText.bodyS, color = YColor.textSecondary)
        }
    }
}

/** 28 `Hero`: a soft scatter of coins (iOS CoinHero; 342x120 canvas scaled to the width) */
@Composable
fun CoinHero(modifier: Modifier = Modifier) {
    // (center x, center y, core diameter, halo diameter)
    val coins = listOf(
        floatArrayOf(120.5f, 60.5f, 17f, 30f),
        floatArrayOf(171f, 48f, 24f, 44f),
        floatArrayOf(225f, 66f, 14f, 26f),
        floatArrayOf(150f, 96f, 10f, 18f),
        floatArrayOf(205f, 100f, 8f, 14f),
        floatArrayOf(90f, 92f, 6f, 10f),
        floatArrayOf(260f, 36f, 6f, 10f),
    )
    androidx.compose.foundation.Canvas(modifier.fillMaxWidth().aspectRatio(342f / 120f)) {
        val k = size.width / 342f
        for (c in coins) {
            val center = androidx.compose.ui.geometry.Offset(c[0] * k, c[1] * k)
            drawCircle(YColor.starBright.copy(alpha = 0.16f), radius = c[3] / 2 * k, center = center)
            drawCircle(YColor.starBright, radius = c[2] / 2 * k, center = center)
        }
    }
}
