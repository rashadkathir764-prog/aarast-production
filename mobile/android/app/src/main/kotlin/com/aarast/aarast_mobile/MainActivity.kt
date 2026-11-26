package com.aarast.aarast_mobile

import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.view.WindowManager
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

// The notification channels are made as the process starts, before this
// page: AarastApplication.
class MainActivity : FlutterActivity() {
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
        // RA-MO-359: whether the phone has Google services, without which no
        // push registration can be made (a Huawei phone has none). Asked
        // from `lib/core/push/push_messaging_gateway.dart`.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "aarast/push_support",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "googleServicesAvailable" -> result.success(googleServicesAvailable())
                // From Android 13 (33) the app asks for notifications itself,
                // and before it asks the push plugin reports them «denied»:
                // the phone's version tells «never asked» from «turned off».
                "sdkInt" -> result.success(Build.VERSION.SDK_INT)
                // Turned off by the person, the notifications come back on
                // in the phone's settings only: this app's page there.
                "openNotificationSettings" -> result.success(openNotificationSettings())
                else -> result.notImplemented()
            }
        }
        // D116: the invitation card goes to WhatsApp as a picture, by the
        // standard share to the WhatsApp app; WhatsApp then asks for the
        // chat (the guest's, just opened with the text, is first). Nothing
        // here knows what reached the chat; the person says it.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "aarast/invitation_share",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "canShare" -> result.success(whatsAppPackage() != null)
                "shareImage" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    val mime = call.argument<String>("mime") ?: "image/png"
                    result.success(if (bytes == null) "error" else shareImage(bytes, mime))
                }
                else -> result.notImplemented()
            }
        }
    }

    /** Google Play services, installed and on. */
    private fun googleServicesAvailable(): Boolean =
        try {
            @Suppress("DEPRECATION")
            packageManager.getApplicationInfo("com.google.android.gms", 0).enabled
        } catch (_: PackageManager.NameNotFoundException) {
            false
        }

    /**
     * This app's notification settings (Android 8+), else its app page,
     * where «الإشعارات» is one tap away. False when neither opens.
     */
    private fun openNotificationSettings(): Boolean {
        val notifications = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
            putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
        }
        val appPage = Intent(
            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
            Uri.fromParts("package", packageName, null),
        )
        val intents =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) listOf(notifications, appPage) else listOf(appPage)
        for (intent in intents) {
            try {
                startActivity(intent)
                return true
            } catch (_: ActivityNotFoundException) {
                continue
            }
        }
        return false
    }

    /** WhatsApp, else WhatsApp Business; null when neither is installed. */
    private fun whatsAppPackage(): String? =
        listOf("com.whatsapp", "com.whatsapp.w4b").firstOrNull { pkg ->
            try {
                @Suppress("DEPRECATION")
                packageManager.getPackageInfo(pkg, 0)
                true
            } catch (_: PackageManager.NameNotFoundException) {
                false
            }
        }

    private fun shareImage(bytes: ByteArray, mime: String): String {
        val pkg = whatsAppPackage() ?: return "not_installed"
        return try {
            val folder = File(cacheDir, "invitation").apply { mkdirs() }
            folder.listFiles()?.forEach { it.delete() }
            val extension = if (mime == "image/jpeg") "jpg" else if (mime == "image/webp") "webp" else "png"
            val file = File(folder, "card-${System.currentTimeMillis()}.$extension")
            file.writeBytes(bytes)
            val uri = FileProvider.getUriForFile(this, "$packageName.invitation", file)
            val intent = Intent(Intent.ACTION_SEND).apply {
                type = mime
                putExtra(Intent.EXTRA_STREAM, uri)
                setPackage(pkg)
                clipData = ClipData.newRawUri("", uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(intent)
            "opened"
        } catch (_: ActivityNotFoundException) {
            "not_installed"
        } catch (_: Exception) {
            "error"
        }
    }
}
