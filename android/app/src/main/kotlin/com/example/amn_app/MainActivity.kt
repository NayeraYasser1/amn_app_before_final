package com.example.amn_app

import android.Manifest
import android.app.Activity
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.telephony.SmsManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger

class MainActivity : FlutterActivity() {
    private val channelName = "amn_app/android_calls"
    private val smsChannelName = "amn_app/sms"
    private val smsPermissionRequestCode = 7301

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        AndroidCallController.initialize(applicationContext)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "initializeBridge" -> {
                        AndroidCallController.requestSetup(this)
                        result.success(
                            mapOf(
                                "ok" to true,
                                "default_dialer" to AndroidCallController.isDefaultDialer(),
                                "permissions_granted" to AndroidCallController.hasRequiredPermissions(),
                            ),
                        )
                    }
                    "startNativeBridge" -> {
                        val port = call.argument<Int>("port") ?: 8765
                        val token = call.argument<String>("token") ?: ""
                        AndroidCallBridgeForegroundService.start(applicationContext, port, token)
                        result.success(AndroidCallBridgeServer.statusMap())
                    }
                    "stopNativeBridge" -> {
                        AndroidCallBridgeForegroundService.stop(applicationContext)
                        result.success(AndroidCallBridgeServer.statusMap())
                    }
                    "getBridgeRuntimeStatus" -> {
                        result.success(
                            AndroidCallBridgeServer.statusMap() + mapOf(
                                "default_dialer" to AndroidCallController.isDefaultDialer(),
                                "permissions_granted" to AndroidCallController.hasRequiredPermissions(),
                                "battery_optimization_ignored" to AndroidCallController.isIgnoringBatteryOptimizations(),
                            ),
                        )
                    }
                    "requestIgnoreBatteryOptimizations" -> {
                        AndroidCallController.requestIgnoreBatteryOptimizations(this)
                        result.success(mapOf("ok" to true))
                    }
                    "getCallStatus" -> result.success(CallControlState.statusMap())
                    "answerCall" -> result.success(CallControlState.answerCall())
                    "rejectCall" -> result.success(CallControlState.rejectCall())
                    "endCall" -> result.success(CallControlState.endCall())
                    "setMuted" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        result.success(CallControlState.setMuted(enabled))
                    }
                    "setSpeaker" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: true
                        result.success(CallControlState.setSpeaker(enabled))
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, smsChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasSmsPermission" -> result.success(hasSmsPermission())
                    "requestSmsPermission" -> {
                        if (!hasSmsPermission()) {
                            ActivityCompat.requestPermissions(
                                this,
                                arrayOf(Manifest.permission.SEND_SMS),
                                smsPermissionRequestCode,
                            )
                        }
                        result.success(hasSmsPermission())
                    }
                    "sendSms" -> handleSendSms(call, result)
                    else -> result.notImplemented()
                }
            }
    }

    /// Sends an SMS and only reports `ok:true` once the radio confirms every
    /// part was actually sent (Activity.RESULT_OK on each part's sentIntent).
    /// Airplane mode, no SIM and no-service surface here instead of being
    /// silently reported as success, so the Dart side can fall back.
    private fun handleSendSms(call: MethodCall, result: MethodChannel.Result) {
        val phone = call.argument<String>("phone") ?: ""
        val message = call.argument<String>("message") ?: ""
        if (phone.isBlank() || message.isBlank()) {
            result.success(mapOf("ok" to false, "error" to "bad_args"))
            return
        }
        if (!hasSmsPermission()) {
            result.success(mapOf("ok" to false, "error" to "permission"))
            return
        }
        try {
            val smsManager =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    getSystemService(SmsManager::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    SmsManager.getDefault()
                }
            val parts = smsManager.divideMessage(message)
            val partCount = parts.size.coerceAtLeast(1)
            val action = "com.example.amn_app.SMS_SENT." + System.nanoTime()
            val received = AtomicInteger(0)
            val anyFailure = AtomicBoolean(false)
            val replied = AtomicBoolean(false)
            val handler = Handler(Looper.getMainLooper())
            var receiver: BroadcastReceiver? = null

            fun finish(ok: Boolean, error: String?) {
                if (!replied.compareAndSet(false, true)) return
                handler.removeCallbacksAndMessages(null)
                receiver?.let { r ->
                    try {
                        unregisterReceiver(r)
                    } catch (_: Exception) {
                    }
                }
                val payload = HashMap<String, Any?>()
                payload["ok"] = ok
                if (error != null) payload["error"] = error
                result.success(payload)
            }

            receiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    if (resultCode != Activity.RESULT_OK) anyFailure.set(true)
                    if (received.incrementAndGet() >= partCount) {
                        finish(!anyFailure.get(), if (anyFailure.get()) "radio_failure" else null)
                    }
                }
            }

            ContextCompat.registerReceiver(
                this,
                receiver,
                IntentFilter(action),
                ContextCompat.RECEIVER_NOT_EXPORTED,
            )

            val piFlags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            val sentIntents = ArrayList<PendingIntent>(partCount)
            for (i in 0 until partCount) {
                val intent = Intent(action).setPackage(packageName)
                sentIntents.add(PendingIntent.getBroadcast(this, i, intent, piFlags))
            }

            smsManager.sendMultipartTextMessage(phone, null, parts, sentIntents, null)

            // The radio reports delivery asynchronously; if nothing comes back,
            // treat it as a failure rather than a false success.
            handler.postDelayed({ finish(false, "timeout") }, 25_000)
        } catch (e: Exception) {
            result.success(mapOf("ok" to false, "error" to (e.message ?: "send_failed")))
        }
    }

    private fun hasSmsPermission(): Boolean =
        ContextCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS) ==
            PackageManager.PERMISSION_GRANTED
}
