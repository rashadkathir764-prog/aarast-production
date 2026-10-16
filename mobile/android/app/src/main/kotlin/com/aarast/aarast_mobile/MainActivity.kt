package com.aarast.aarast_mobile

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createUpdatesNotificationChannel()
    }

    private fun createUpdatesNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        val channel = NotificationChannel(
            "aarast_updates",
            "رسائل ومهام اعّرست",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "إشعارات الرسائل الجديدة وتحديثات المهام"
            lockscreenVisibility = Notification.VISIBILITY_PRIVATE
            enableVibration(true)
            enableLights(true)
            lightColor = Color.rgb(76, 113, 128)
            setShowBadge(true)
        }
        manager.createNotificationChannel(channel)
    }
}
