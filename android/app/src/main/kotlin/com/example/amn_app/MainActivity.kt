package com.example.amn_app

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "amn_app/android_calls"

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
    }
}
