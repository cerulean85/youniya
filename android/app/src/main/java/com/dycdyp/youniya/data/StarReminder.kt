package com.dycdyp.youniya.data

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import java.time.LocalTime
import java.time.format.DateTimeFormatter
import java.util.Calendar
import java.util.Locale

/**
 * 87 별 만들기 알림 (iOS StarReminder):
 * quiet local notification at the chosen time, only on days without a new star.
 * Uses Android system AlarmManager without adding external libraries.
 */
object StarReminder {
    const val TITLE = "오늘 밤하늘"
    const val BODY = "오늘 마음에 남은 장면이 있다면, 별로 띄워 볼까요?"

    /** "오후 9:30" */
    fun timeText(minutes: Int): String {
        val hour = (minutes / 60) % 24
        val minute = minutes % 60
        val time = LocalTime.of(hour, minute)
        val formatter = DateTimeFormatter.ofPattern("a h:mm", Locale.KOREAN)
        return time.format(formatter)
    }

    fun reschedule(context: Context, on: Boolean, minutes: Int, wroteToday: Boolean) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val intent = Intent(context, ReminderReceiver::class.java).apply {
            action = "com.dycdyp.youniya.ACTION_STAR_REMINDER"
        }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val pending = PendingIntent.getBroadcast(context, 8701, intent, flags)

        if (!on) {
            am.cancel(pending)
            return
        }

        val cal = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, minutes / 60)
            set(Calendar.MINUTE, minutes % 60)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            if (before(Calendar.getInstance()) || wroteToday) {
                add(Calendar.DAY_OF_YEAR, 1)
            }
        }

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, cal.timeInMillis, pending)
            } else {
                am.setExact(AlarmManager.RTC_WAKEUP, cal.timeInMillis, pending)
            }
        } catch (_: SecurityException) {
            // Android 12+ exact alarm permission fallback
            am.set(AlarmManager.RTC_WAKEUP, cal.timeInMillis, pending)
        }
    }
}

class ReminderReceiver : android.content.BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        // Broadcast receiver for star reminder alarm
    }
}
