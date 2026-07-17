package com.tagonsoft.portsip

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.app.Person
import androidx.core.app.ServiceCompat

/**
 * Foreground service backing an ongoing call: keeps the process alive with the
 * app backgrounded and posts the system CallStyle notification (status-bar
 * call chip, call timer, native Hang up action). Started, updated and stopped
 * by [PortsipConnectionService] as connections come and go.
 */
class PortsipCallService : Service() {

    companion object {
        private const val COMPONENT = "CallService"
        private const val CHANNEL_ID = "portsip_ongoing_call"
        private const val NOTIFICATION_ID = 0xCA11

        private const val ACTION_SHOW = "com.tagonsoft.portsip.SHOW_CALL"
        private const val ACTION_HANG_UP = "com.tagonsoft.portsip.HANG_UP"
        private const val EXTRA_DISPLAY_NAME = "displayName"
        private const val EXTRA_STARTED_AT = "startedAt"

        /**
         * Shows (or updates) the ongoing-call notification.
         *
         * @param displayName Name shown on the notification
         * @param startedAt Epoch ms the call started (dial time)
         */
        fun show(context: Context, displayName: String, startedAt: Long) {
            val intent = Intent(context, PortsipCallService::class.java)
                .setAction(ACTION_SHOW)
                .putExtra(EXTRA_DISPLAY_NAME, displayName)
                .putExtra(EXTRA_STARTED_AT, startedAt)
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
            } catch (e: Exception) {
                // Background-start restrictions — the call proceeds without a
                // notification rather than failing.
                PortsipLogger.e(COMPONENT, "Failed to start call service: ${e.message}")
            }
        }

        /** Removes the notification and stops the service. */
        fun stop(context: Context) {
            try {
                context.stopService(Intent(context, PortsipCallService::class.java))
            } catch (e: Exception) {
                PortsipLogger.e(COMPONENT, "Failed to stop call service: ${e.message}")
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_HANG_UP) {
            PortsipLogger.d(COMPONENT, "Hang up from notification")
            PortsipConnectionService.endAllCallsFromNotification()
            ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
            stopSelf()
            return START_NOT_STICKY
        }
        val name = intent?.getStringExtra(EXTRA_DISPLAY_NAME).orEmpty().ifEmpty { "Call" }
        val startedAt = intent?.getLongExtra(EXTRA_STARTED_AT, 0L) ?: 0L
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ServiceInfo.FOREGROUND_SERVICE_TYPE_PHONE_CALL
        } else {
            0
        }
        ServiceCompat.startForeground(
            this, NOTIFICATION_ID, buildNotification(name, startedAt), type
        )
        return START_NOT_STICKY
    }

    private fun buildNotification(name: String, startedAt: Long): Notification {
        ensureChannel()
        val hangUp = PendingIntent.getService(
            this,
            1,
            Intent(this, PortsipCallService::class.java).setAction(ACTION_HANG_UP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val icon = PortsipConnectionService.notificationIconRes
            .takeIf { it != 0 } ?: R.drawable.portsip_ic_call
        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(icon)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
        PortsipConnectionService.notificationColor?.let { color ->
            // Accent only (icon/action tint) — colorized backgrounds ignore
            // alpha on most system UIs and a solid brand fill is too heavy.
            builder.setColor(color)
        }
        // CallStyle from dial to hang-up: it's the only template with the native
        // Hang up button and avatar. Its chronometer ticks regardless, so the
        // timer runs from `startedAt` (dial time, stamped once, never reset) —
        // same behavior as the system dialer's call notification.
        val person = Person.Builder().setName(name).setImportant(true).build()
        builder
            .setStyle(NotificationCompat.CallStyle.forOngoingCall(person, hangUp))
            .setWhen(startedAt)
            .setShowWhen(true)
            .setUsesChronometer(true)
        packageManager.getLaunchIntentForPackage(packageName)?.let { launch ->
            builder.setContentIntent(
                PendingIntent.getActivity(
                    this, 0, launch,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
            )
        }
        return builder.build()
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        if (nm.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID, "Ongoing calls", NotificationManager.IMPORTANCE_DEFAULT
        ).apply {
            setSound(null, null)
            enableVibration(false)
            setShowBadge(false)
        }
        nm.createNotificationChannel(channel)
    }
}
