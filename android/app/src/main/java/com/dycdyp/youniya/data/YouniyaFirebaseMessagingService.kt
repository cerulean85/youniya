package com.dycdyp.youniya.data

import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat
import com.dycdyp.youniya.MainActivity
import com.dycdyp.youniya.R
import com.dycdyp.youniya.YouniyaApp
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class YouniyaFirebaseMessagingService : FirebaseMessagingService() {

    override fun onNewToken(token: String) {
        super.onNewToken(token)
        PushRegistration.saveToken(applicationContext, token)
        val api = ApiClient(TokenStore(applicationContext))
        if (api.isSignedIn && api.session?.needsConsent == false) {
            CoroutineScope(Dispatchers.IO).launch {
                PushRegistration.register(applicationContext, api, token)
            }
        }
    }

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        super.onMessageReceived(remoteMessage)

        val title = remoteMessage.notification?.title
            ?: remoteMessage.data["title"]
            ?: getString(R.string.app_name)
        val body = remoteMessage.notification?.body
            ?: remoteMessage.data["body"]
            ?: ""
        val targetJson = remoteMessage.data["target"]

        showNotification(title, body, remoteMessage.data["kind"] ?: "notice", targetJson)
    }

    private fun showNotification(title: String, body: String, kind: String, targetJson: String?) {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("kind", kind)
            if (targetJson != null) {
                putExtra("target", targetJson)
            }
        }

        val pendingIntent = PendingIntent.getActivity(
            this,
            System.currentTimeMillis().toInt(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, YouniyaApp.CHANNEL_NOTICES)
            .setSmallIcon(R.drawable.icon_star)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(System.currentTimeMillis().toInt(), notification)
    }
}
