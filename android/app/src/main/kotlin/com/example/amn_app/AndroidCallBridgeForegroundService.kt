package com.example.amn_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class AndroidCallBridgeForegroundService : Service() {
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action ?: ACTION_START
        if (action == ACTION_STOP) {
            AndroidCallBridgeServer.stop()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(STOP_FOREGROUND_REMOVE)
            } else {
                @Suppress("DEPRECATION")
                stopForeground(true)
            }
            stopSelf()
            return START_NOT_STICKY
        }

        val port = intent?.getIntExtra(EXTRA_PORT, 8765) ?: 8765
        val token = intent?.getStringExtra(EXTRA_TOKEN) ?: ""

        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification(port))
        AndroidCallBridgeServer.start(port, token)
        return START_STICKY
    }

    override fun onDestroy() {
        AndroidCallBridgeServer.stop()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun buildNotification(port: Int): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("AMN Call Bridge")
            .setContentText("Android call bridge is active on port $port")
            .setSmallIcon(android.R.drawable.stat_sys_phone_call)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val manager = getSystemService(NotificationManager::class.java)
        val existing = manager?.getNotificationChannel(CHANNEL_ID)
        if (existing != null) {
            return
        }

        val channel = NotificationChannel(
            CHANNEL_ID,
            "AMN Call Bridge",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Keeps the Android call bridge alive for Raspberry Pi call control."
        }
        manager?.createNotificationChannel(channel)
    }

    companion object {
        private const val CHANNEL_ID = "amn_call_bridge"
        private const val NOTIFICATION_ID = 2206
        private const val EXTRA_PORT = "port"
        private const val EXTRA_TOKEN = "token"
        private const val ACTION_START = "com.example.amn_app.START_CALL_BRIDGE"
        private const val ACTION_STOP = "com.example.amn_app.STOP_CALL_BRIDGE"

        fun start(context: Context, port: Int, token: String) {
            val intent = Intent(context, AndroidCallBridgeForegroundService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_PORT, port)
                putExtra(EXTRA_TOKEN, token)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            AndroidCallBridgeServer.stop()
            context.stopService(Intent(context, AndroidCallBridgeForegroundService::class.java))
        }
    }
}
