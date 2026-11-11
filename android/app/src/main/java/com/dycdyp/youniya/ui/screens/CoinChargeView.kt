package com.dycdyp.youniya.ui.screens

import androidx.activity.compose.BackHandler
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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
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
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.dycdyp.youniya.R
import com.dycdyp.youniya.data.AppModel
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

data class CoinPackage(
    val coins: Int,
    val price: String,
    val bonus: Int = 0,
) {
    val priceText: String
        get() = if (bonus > 0) "$price · 보너스 $bonus 포함" else price

    companion object {
        val all = listOf(
            CoinPackage(coins = 110, price = "₩1,100"),
            CoinPackage(coins = 330, price = "₩3,300"),
            CoinPackage(coins = 1100, price = "₩9,900", bonus = 100),
        )
    }
}

/**
 * 28 Coin Charge (iOS CoinChargeView)
 * UI만: 상품 목록 · 필수 동의 · 충전하기 버튼
 */
@Composable
fun CoinChargeView(
    model: AppModel,
    onBack: () -> Unit,
    onPolicy: () -> Unit,
    onHistory: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var selected by remember { mutableStateOf(CoinPackage.all[1]) }
    var agreed by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        model.loadCoins()
    }

    BackHandler(onBack = onBack)
    Box(modifier.fillMaxSize()) {
        StarField()
        Column(Modifier.fillMaxSize()) {
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
                        CoinPackageCard(
                            pkg = pkg,
                            isSelected = isSelected,
                            onClick = { selected = pkg },
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
                    "충전한 코인만큼 남아 있을 때만 환불할 수 있어요.\n환불을 요청하면 코인 사용 내역이 앱 스토어에 전달돼요.",
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
                    text = "충전하기",
                    enabled = agreed,
                    onClick = {
                        model.message = "코인 충전은 곧 열려요."
                    },
                )
            }
        }
    }
}

/** Coin package card */
@Composable
private fun CoinPackageCard(
    pkg: CoinPackage,
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
            Text(pkg.priceText, style = YText.bodyS, color = YColor.textSecondary)
        }
        Icon(
            painter = painterResource(R.drawable.icon_coin),
            contentDescription = null,
            modifier = Modifier.size(24.dp),
            tint = YColor.starBright,
        )
    }
}

/** 28 `Hero`: a soft scatter of coins */
@Composable
fun CoinHero(modifier: Modifier = Modifier) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(100.dp)
            .clip(RoundedCornerShape(Radius.lg))
            .background(YColor.tintGold.copy(alpha = 0.15f), RoundedCornerShape(Radius.lg)),
        contentAlignment = Alignment.Center,
    ) {
        Row(
            horizontalArrangement = Arrangement.spacedBy(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(painterResource(R.drawable.icon_coin), null, Modifier.size(36.dp), tint = YColor.starBright)
            Icon(painterResource(R.drawable.icon_coin), null, Modifier.size(48.dp), tint = YColor.starBright)
            Icon(painterResource(R.drawable.icon_coin), null, Modifier.size(36.dp), tint = YColor.starBright)
        }
    }
}
