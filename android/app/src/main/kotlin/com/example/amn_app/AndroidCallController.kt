package com.example.amn_app

import android.Manifest
import android.app.Activity
import android.app.role.RoleManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.telecom.TelecomManager
import android.net.Uri
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat

object AndroidCallController {
    private const val REQUEST_PERMISSIONS = 1201
    private const val REQUEST_ROLE = 1202
    private lateinit var applicationContext: Context

    fun initialize(context: Context) {
        applicationContext = context.applicationContext
    }

    fun requestSetup(activity: Activity) {
        requestMissingPermissions(activity)
        requestDialerRole(activity)
    }

    fun hasRequiredPermissions(): Boolean {
        val answerGranted = ContextCompat.checkSelfPermission(
            applicationContext,
            Manifest.permission.ANSWER_PHONE_CALLS,
        ) == PackageManager.PERMISSION_GRANTED
        val readGranted = ContextCompat.checkSelfPermission(
            applicationContext,
            Manifest.permission.READ_PHONE_STATE,
        ) == PackageManager.PERMISSION_GRANTED
        val notificationsGranted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(
                applicationContext,
                Manifest.permission.POST_NOTIFICATIONS,
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
        return answerGranted && readGranted && notificationsGranted
    }

    fun requestMissingPermissions(activity: Activity) {
        val missing = mutableListOf<String>()
        if (ContextCompat.checkSelfPermission(activity, Manifest.permission.ANSWER_PHONE_CALLS) != PackageManager.PERMISSION_GRANTED) {
            missing.add(Manifest.permission.ANSWER_PHONE_CALLS)
        }
        if (ContextCompat.checkSelfPermission(activity, Manifest.permission.READ_PHONE_STATE) != PackageManager.PERMISSION_GRANTED) {
            missing.add(Manifest.permission.READ_PHONE_STATE)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(activity, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            missing.add(Manifest.permission.POST_NOTIFICATIONS)
        }
        if (missing.isNotEmpty()) {
            ActivityCompat.requestPermissions(activity, missing.toTypedArray(), REQUEST_PERMISSIONS)
        }
    }

    fun isDefaultDialer(): Boolean {
        if (!::applicationContext.isInitialized) {
            return false
        }
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roleManager = applicationContext.getSystemService(RoleManager::class.java)
            roleManager?.isRoleHeld(RoleManager.ROLE_DIALER) == true
        } else {
            val telecomManager = applicationContext.getSystemService(TelecomManager::class.java)
            telecomManager?.defaultDialerPackage == applicationContext.packageName
        }
    }

    fun requestDialerRole(activity: Activity) {
        if (isDefaultDialer()) {
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roleManager = activity.getSystemService(RoleManager::class.java)
            val intent = roleManager?.createRequestRoleIntent(RoleManager.ROLE_DIALER)
            if (intent != null) {
                activity.startActivityForResult(intent, REQUEST_ROLE)
            }
        } else {
            val intent = Intent(TelecomManager.ACTION_CHANGE_DEFAULT_DIALER)
            intent.putExtra(TelecomManager.EXTRA_CHANGE_DEFAULT_DIALER_PACKAGE_NAME, activity.packageName)
            activity.startActivityForResult(intent, REQUEST_ROLE)
        }
    }

    fun isIgnoringBatteryOptimizations(): Boolean {
        if (!::applicationContext.isInitialized) {
            return false
        }
        val powerManager = applicationContext.getSystemService(Context.POWER_SERVICE) as? PowerManager
        return powerManager?.isIgnoringBatteryOptimizations(applicationContext.packageName) == true
    }

    fun requestIgnoreBatteryOptimizations(activity: Activity) {
        if (isIgnoringBatteryOptimizations()) {
            return
        }
        val intent = Intent(
            Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
            Uri.parse("package:${activity.packageName}"),
        )
        activity.startActivity(intent)
    }
}
