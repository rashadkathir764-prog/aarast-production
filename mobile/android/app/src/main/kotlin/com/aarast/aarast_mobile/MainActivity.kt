package com.aarast.aarast_mobile

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createUpdatesNotificationChannel()
    }

    // D112 (Q-8): while a money screen is in front and the account's lock is
    // on, the app asks for a secure window: no screenshot, no recording, and
    // no picture of it in the recent-apps list. Asked from
    // `lib/core/security/screen_protection.dart`.
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "aarast/screen_protection",
        ).setMethodCallHandler { call, result ->
            if (call.method != "setSecure") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            if (call.arguments == true) {
                window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
            } else {
                window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
            }
            result.success(null)
        }
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
