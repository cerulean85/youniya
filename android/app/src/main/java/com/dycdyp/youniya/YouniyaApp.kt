package com.dycdyp.youniya

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build

class YouniyaApp : Application() {
    override fun onCreate() {
        super.onCreate()
        createNotificationChannels()
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(NotificationManager::class.java) ?: return

            // 운영자 · 광장 알림 채널
            val noticeChannel = NotificationChannel(
                CHANNEL_NOTICES,
                "소식 및 안내",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "운영자 조치 및 공지사항 알림"
            }

            // 별 만들기 알림 채널
            val reminderChannel = NotificationChannel(
                CHANNEL_STAR_REMINDER,
                "별 만들기 알림",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "하루 한 번 별 만들기 알림"
            }

            nm.createNotificationChannels(listOf(noticeChannel, reminderChannel))
        }
    }

    companion object {
        const val CHANNEL_NOTICES = "youniya_notices"
        const val CHANNEL_STAR_REMINDER = "star_reminder"
    }
}

