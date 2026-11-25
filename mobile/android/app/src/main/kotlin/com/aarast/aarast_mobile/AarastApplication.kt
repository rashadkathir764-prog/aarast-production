package com.aarast.aarast_mobile

import android.app.Application

/**
 * The app's process. It starts before any page, also for a push that wakes
 * a closed app, so the notification channels are made here.
 */
class AarastApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        AarastNotificationChannels.ensure(this)
    }
}
