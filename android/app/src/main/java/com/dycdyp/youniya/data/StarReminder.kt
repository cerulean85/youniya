package com.dycdyp.youniya.data

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.BroadcastReceiver
import android.content.Intent
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.dycdyp.youniya.MainActivity
import com.dycdyp.youniya.R
import com.dycdyp.youniya.YouniyaApp
import java.time.LocalDate
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

    private const val PREFS = "youniya_reminder"
    private const val REQUEST = 8701
    private const val ACTION = "com.dycdyp.youniya.ACTION_STAR_REMINDER"
    const val DEFAULT_MINUTES = 21 * 60 + 30

    private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    private fun today() = LocalDate.now().toString()

    fun minutes(context: Context) = prefs(context).getInt("minutes", DEFAULT_MINUTES)

    /** Saves the choice and schedules the next reminder (or cancels it). */
    fun save(context: Context, on: Boolean, minutes: Int) {
        prefs(context).edit().putBoolean("on", on).putInt("minutes", minutes).apply()
        reschedule(context)
    }

    /** Whether a star was written today, from the star list (as on iOS): today's reminder is
     *  skipped after one, and comes back if it is deleted or another account signs in. */
    fun setWroteToday(context: Context, wrote: Boolean) {
        val was = prefs(context).getString("wrote_on", null) == today()
        if (was == wrote) return
        prefs(context).edit().apply { if (wrote) putString("wrote_on", today()) else remove("wrote_on") }.apply()
        reschedule(context)
    }

    /** The next fire time from the saved choice; after boot, after firing, after a change. */
    fun reschedule(context: Context) {
        val p = prefs(context)
        val am = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val intent = Intent(context, ReminderReceiver::class.java).setAction(ACTION)
        val pending = PendingIntent.getBroadcast(
            context, REQUEST, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        if (!p.getBoolean("on", false)) {
            am.cancel(pending)
            return
        }
        val minutes = p.getInt("minutes", DEFAULT_MINUTES)
        val wroteToday = p.getString("wrote_on", null) == today()
        val cal = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, minutes / 60)
            set(Calendar.MINUTE, minutes % 60)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            if (wroteToday || timeInMillis <= System.currentTimeMillis()) add(Calendar.DAY_OF_YEAR, 1)
        }
        // Exact alarms need SCHEDULE_EXACT_ALARM on Android 12+, which Play keeps for alarm and
        // calendar apps; plain set() can drift by an hour. A 15-minute window needs no permission.
        am.setWindow(AlarmManager.RTC_WAKEUP, cal.timeInMillis, 15 * 60 * 1000L, pending)
    }

    /** Fired: tell only on a day without a star, then schedule tomorrow's. */
    internal fun fire(context: Context) {
        val p = prefs(context)
        if (p.getBoolean("on", false) && p.getString("wrote_on", null) != today() &&
            NotificationManagerCompat.from(context).areNotificationsEnabled()
        ) {
            val open = PendingIntent.getActivity(
                context, REQUEST,
                Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            val n = NotificationCompat.Builder(context, YouniyaApp.CHANNEL_STAR_REMINDER)
                .setSmallIcon(R.drawable.icon_star)
                .setContentTitle(TITLE)
                .setContentText(BODY)
                .setContentIntent(open)
                .setAutoCancel(true)
                .build()
            try {
                NotificationManagerCompat.from(context).notify(REQUEST, n)
            } catch (_: SecurityException) {
            }
        }
        // Past today's time now, so this lands on tomorrow.
        reschedule(context)
    }
}

/** 87 별 만들기 알림 and, after a restart or an app update, putting the next one back. */
class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_TIME_CHANGED, Intent.ACTION_TIMEZONE_CHANGED -> StarReminder.reschedule(context)
            else -> StarReminder.fire(context)
        }
    }
}
