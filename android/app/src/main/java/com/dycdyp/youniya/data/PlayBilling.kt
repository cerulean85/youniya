package com.dycdyp.youniya.data

import android.app.Activity
import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.BillingClientStateListener
import com.android.billingclient.api.BillingFlowParams
import com.android.billingclient.api.BillingResult
import com.android.billingclient.api.ConsumeParams
import com.android.billingclient.api.PendingPurchasesParams
import com.android.billingclient.api.ProductDetails
import com.android.billingclient.api.Purchase
import com.android.billingclient.api.PurchasesUpdatedListener
import com.android.billingclient.api.QueryProductDetailsParams
import com.android.billingclient.api.QueryPurchasesParams
import com.android.billingclient.api.consumePurchase
import com.android.billingclient.api.queryProductDetails
import com.android.billingclient.api.queryPurchasesAsync
import com.dycdyp.youniya.BuildConfig
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.util.UUID

sealed interface BillingOutcome {
    data class Success(val coins: Int, val added: Int) : BillingOutcome
    data object Pending : BillingOutcome
    data object Cancelled : BillingOutcome
    data class Failed(val code: String, val message: String) : BillingOutcome
    data object StoreUnavailable : BillingOutcome
}

@Serializable
data class PurchaseIn(
    val platform: String = "android",
    @SerialName("product_id") val productId: String,
    @SerialName("purchase_token") val purchaseToken: String? = null,
    @SerialName("order_id") val orderId: String? = null,
)

@Serializable
data class PurchaseOut(
    val coins: Int,
    val added: Int,
    @SerialName("already_processed") val alreadyProcessed: Boolean = false,
    val consumed: Boolean = false,
)

/**
 * 28 Google Play 코인 결제 관리자 (iOS StoreKitCoins 대응).
 * BillingClient(enablePendingPurchases) 생성 및 연결 관리,
 * 상품 coin_110 / coin_330 / coin_1100 가격 조회, 결제 플로우, 미소비 구매 재처리.
 */
class PlayBilling(
    private val context: Context,
    private val scope: CoroutineScope,
    private val api: ApiClient,
    private val onCoinsUpdated: (Int) -> Unit,
    private val showToast: (String) -> Unit,
) : PurchasesUpdatedListener {

    private var activeCallback: ((BillingOutcome) -> Unit)? = null
    var productDetailsMap by mutableStateOf<Map<String, ProductDetails>>(emptyMap())
        private set

    val client: BillingClient = BillingClient.newBuilder(context)
        .setListener(this)
        .enablePendingPurchases(
            PendingPurchasesParams.newBuilder()
                .enableOneTimeProducts()
                .build()
        )
        .build()

    init {
        startConnection()
    }

    fun startConnection(onConnected: (() -> Unit)? = null) {
        if (client.isReady) {
            onConnected?.invoke()
            return
        }
        client.startConnection(object : BillingClientStateListener {
            override fun onBillingSetupFinished(billingResult: BillingResult) {
                if (billingResult.responseCode == BillingClient.BillingResponseCode.OK) {
                    scope.launch {
                        queryProducts()
                        onConnected?.invoke()
                    }
                }
            }

            override fun onBillingServiceDisconnected() {
                // 필요 시 다음 요청 때 재연결
            }
        })
    }

    suspend fun queryProducts() {
        if (!client.isReady) return
        val productList = listOf("coin_110", "coin_330", "coin_1100").map { id ->
            QueryProductDetailsParams.Product.newBuilder()
                .setProductId(id)
                .setProductType(BillingClient.ProductType.INAPP)
                .build()
        }
        val params = QueryProductDetailsParams.newBuilder().setProductList(productList).build()
        val result = client.queryProductDetails(params)
        if (result.billingResult.responseCode == BillingClient.BillingResponseCode.OK) {
            val list = result.productDetailsList ?: emptyList()
            productDetailsMap = list.associateBy { it.productId }
        }
    }

    fun getPriceText(coins: Int): String {
        val details = productDetailsMap["coin_$coins"]
        val formatted = details?.oneTimePurchaseOfferDetails?.formattedPrice
        return when (coins) {
            110 -> formatted ?: "₩1,100"
            330 -> formatted ?: "₩3,300"
            1100 -> if (formatted != null) "$formatted · 보너스 100 포함" else "₩9,900 · 보너스 100 포함"
            else -> formatted ?: ""
        }
    }

    /**
     * 결제 시작.
     */
    fun launchBilling(
        activity: Activity,
        coins: Int,
        userId: String?,
        callback: (BillingOutcome) -> Unit,
    ) {
        activeCallback = callback
        val productId = "coin_$coins"
        val details = productDetailsMap[productId]

        if (details == null) {
            // Play 상품을 못 받은 경우
            if (BuildConfig.DEBUG) {
                // 디버그 빌드 전용: Play 상품 못 받는 환경에서 개발 서버에 바로 요청
                scope.launch {
                    val outcome = purchaseDev(coins)
                    callback(outcome)
                    activeCallback = null
                }
                return
            } else {
                callback(BillingOutcome.StoreUnavailable)
                activeCallback = null
                return
            }
        }

        val flowParams = BillingFlowParams.newBuilder()
            .setProductDetailsParamsList(
                listOf(
                    BillingFlowParams.ProductDetailsParams.newBuilder()
                        .setProductDetails(details)
                        .build()
                )
            )
            .apply {
                if (!userId.isNullOrBlank()) {
                    setObfuscatedAccountId(userId)
                }
            }
            .build()

        val result = client.launchBillingFlow(activity, flowParams)
        if (result.responseCode != BillingClient.BillingResponseCode.OK) {
            callback(BillingOutcome.Failed("launch_failed", result.debugMessage.ifEmpty { "결제를 시작하지 못했어요." }))
            activeCallback = null
        }
    }

    override fun onPurchasesUpdated(billingResult: BillingResult, purchases: List<Purchase>?) {
        val callback = activeCallback
        when (billingResult.responseCode) {
            BillingClient.BillingResponseCode.OK -> {
                if (purchases.isNullOrEmpty()) {
                    callback?.invoke(BillingOutcome.Pending)
                    activeCallback = null
                    return
                }
                scope.launch {
                    for (purchase in purchases) {
                        handlePurchase(purchase, isInteractive = true, callback = callback)
                    }
                    activeCallback = null
                }
            }
            BillingClient.BillingResponseCode.USER_CANCELED -> {
                callback?.invoke(BillingOutcome.Cancelled)
                activeCallback = null
            }
            else -> {
                callback?.invoke(BillingOutcome.Failed("billing_error", billingResult.debugMessage))
                activeCallback = null
            }
        }
    }

    private suspend fun handlePurchase(
        purchase: Purchase,
        isInteractive: Boolean,
        callback: ((BillingOutcome) -> Unit)? = null,
    ) {
        if (purchase.purchaseState == Purchase.PurchaseState.PENDING) {
            callback?.invoke(BillingOutcome.Pending)
            return
        }

        if (purchase.purchaseState == Purchase.PurchaseState.PURCHASED) {
            val productId = purchase.products.firstOrNull() ?: ""
            val body = PurchaseIn(
                platform = "android",
                productId = productId,
                purchaseToken = purchase.purchaseToken,
                orderId = purchase.orderId,
            )

            try {
                val out = api.send<PurchaseIn, PurchaseOut>("POST", "/v1/coins/purchases", body)
                onCoinsUpdated(out.coins)
                if (!out.consumed) {
                    client.consumePurchase(
                        ConsumeParams.newBuilder()
                            .setPurchaseToken(purchase.purchaseToken)
                            .build()
                    )
                }
                callback?.invoke(BillingOutcome.Success(coins = out.coins, added = out.added))
            } catch (e: ApiError) {
                when (e.code) {
                    "purchase_pending" -> {
                        callback?.invoke(BillingOutcome.Pending)
                    }
                    "purchase_unverified" -> {
                        // 503: 구매는 남겨 두고 다음 앱 시작 때 다시 보냄 (consume 호출 안 함)
                        showToast("결제를 확인하지 못했어요. 코인은 지급되지 않았어요. 잠시 후 다시 확인할게요.")
                        callback?.invoke(BillingOutcome.Failed(e.code, e.message))
                    }
                    "purchase_invalid", "unknown_product", "transaction_used" -> {
                        showToast(e.message)
                        callback?.invoke(BillingOutcome.Failed(e.code, e.message))
                    }
                    else -> {
                        if (isInteractive) {
                            showToast(e.message)
                        }
                        callback?.invoke(BillingOutcome.Failed(e.code, e.message))
                    }
                }
            } catch (e: Exception) {
                val msg = e.message ?: "결제를 처리하지 못했어요."
                if (isInteractive) {
                    showToast(msg)
                }
                callback?.invoke(BillingOutcome.Failed("network_error", msg))
            }
        }
    }

    /**
     * 앱 시작(로그인·동의 후) 시 소비되지 않은 구매를 찾아 서버에 다시 전송.
     */
    fun checkUnconsumedPurchases() {
        scope.launch(Dispatchers.IO) {
            if (!client.isReady) {
                startConnection {
                    checkUnconsumedPurchases()
                }
                return@launch
            }

            val queryParams = QueryPurchasesParams.newBuilder()
                .setProductType(BillingClient.ProductType.INAPP)
                .build()
            val purchasesResult = client.queryPurchasesAsync(queryParams)
            if (purchasesResult.billingResult.responseCode == BillingClient.BillingResponseCode.OK) {
                for (purchase in purchasesResult.purchasesList) {
                    if (purchase.purchaseState == Purchase.PurchaseState.PURCHASED) {
                        handlePurchase(purchase, isInteractive = false)
                    }
                }
            }
        }
    }

    /**
     * 디버그 빌드 전용 (BuildConfig.DEBUG 일 때만, 릴리스에서는 호출 불가):
     * Play 상품을 못 받는 환경에서 개발 서버(TRUST_PURCHASES)에 직접 요청하여 코인 지급.
     */
    suspend fun purchaseDev(coins: Int): BillingOutcome {
        if (!BuildConfig.DEBUG) return BillingOutcome.StoreUnavailable
        val body = PurchaseIn(
            platform = "android",
            productId = "coin_$coins",
            orderId = "dev-${UUID.randomUUID()}",
        )
        return try {
            val out = api.send<PurchaseIn, PurchaseOut>("POST", "/v1/coins/purchases", body)
            onCoinsUpdated(out.coins)
            BillingOutcome.Success(coins = out.coins, added = out.added)
        } catch (e: ApiError) {
            showToast(e.message)
            BillingOutcome.Failed(e.code, e.message)
        } catch (e: Exception) {
            val msg = e.message ?: "개발 결제 요청에 실패했어요."
            showToast(msg)
            BillingOutcome.Failed("dev_error", msg)
        }
    }
}
