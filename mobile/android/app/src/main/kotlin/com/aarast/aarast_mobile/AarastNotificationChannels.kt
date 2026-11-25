package com.aarast.aarast_mobile

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.graphics.Color
import android.os.Build

/**
 * RA-MO-360: one channel per kind of alert, so the phone's own settings
 * quiet «رسائل», «مهام وتذكيرات» or «المال» alone. The push gateway
 * names these ids (`push-notification.policy.ts`).
 *
 * The one old channel («رسائل ومهام اعّرست», `aarast_updates`) is carried
 * over once: what the person did to it (muting it, lowering it) is kept
 * on the new ones, then it is removed so it is not left in the settings.
 *
 * Made as the app's process starts ([AarastApplication]), not when its page
 * opens: a push that arrives after an update, before the app is opened, finds
 * its channel instead of falling to the system's «Miscellaneous».
 */
object AarastNotificationChannels {
    fun ensure(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        val oldChannelId = "aarast_updates"
        val importance = manager.getNotificationChannel(oldChannelId)?.importance
            ?: NotificationManager.IMPORTANCE_HIGH
        listOf(
            Triple("aarast_messages", "رسائل", "الرسائل الجديدة وطلبات الحجز والعروض"),
            Triple("aarast_tasks", "مهام وتذكيرات", "المهام وتذكيراتها وعدّ العرس التنازلي"),
            Triple("aarast_money", "المال", "مواعيد الدفعات وسداد القروض والميزانية"),
        ).forEach { (id, name, summary) ->
            // A channel's importance is the person's after it exists: the
            // call only adds one that is not there yet.
            val channel = NotificationChannel(id, name, importance).apply {
                description = summary
                lockscreenVisibility = Notification.VISIBILITY_PRIVATE
                enableVibration(true)
                enableLights(true)
                lightColor = Color.rgb(76, 113, 128)
                setShowBadge(true)
            }
            manager.createNotificationChannel(channel)
        }
        manager.deleteNotificationChannel(oldChannelId)
    }
}
