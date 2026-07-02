package com.example.amn_app

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.telephony.SmsManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

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
                    "sendSms" -> {
                        val phone = call.argument<String>("phone") ?: ""
                        val message = call.argument<String>("message") ?: ""
                        when {
                            phone.isBlank() || message.isBlank() ->
                                result.success(mapOf("ok" to false, "error" to "bad_args"))
                            !hasSmsPermission() ->
                                result.success(mapOf("ok" to false, "error" to "permission"))
                            else ->
                                try {
                                    val smsManager =
                                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                            getSystemService(SmsManager::class.java)
                                        } else {
                                            @Suppress("DEPRECATION")
                                            SmsManager.getDefault()
                                        }
                                    val parts = smsManager.divideMessage(message)
                                    smsManager.sendMultipartTextMessage(phone, null, parts, null, null)
                                    result.success(mapOf("ok" to true))
                                } catch (e: Exception) {
                                    result.success(
                                        mapOf("ok" to false, "error" to (e.message ?: "send_failed")),
                                    )
                                }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun hasSmsPermission(): Boolean =
        ContextCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS) ==
            PackageManager.PERMISSION_GRANTED
}
