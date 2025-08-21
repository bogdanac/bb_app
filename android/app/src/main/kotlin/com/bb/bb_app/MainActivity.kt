package com.bb.bb_app

import android.content.ComponentName
import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "notification_listener"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isPermissionGranted" -> {
                    result.success(isNotificationListenerEnabled())
                }
                "requestPermission" -> {
                    requestNotificationListenerPermission()
                    result.success(null)
                }
                "getInstalledApps" -> {
                    val apps = getInstalledApps()
                    result.success(apps)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun isNotificationListenerEnabled(): Boolean {
        val cn = ComponentName(this, NotificationListener::class.java)
        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
        return flat != null && flat.contains(cn.flattenToString())
    }

    private fun requestNotificationListenerPermission() {
        val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
        startActivity(intent)
    }

    private fun getInstalledApps(): List<Map<String, String>> {
        val packageManager = packageManager
        val apps = mutableListOf<Map<String, String>>()
        
        try {
            val packages = packageManager.getInstalledApplications(0)
            for (packageInfo in packages) {
                try {
                    val appName = packageManager.getApplicationLabel(packageInfo).toString()
                    val packageName = packageInfo.packageName
                    
                    // Skip our own app, but include all other apps (including system apps that users might want to monitor)
                    if (packageName != this.packageName) {
                        // Only include apps that have a launcher intent (user-facing apps)
                        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
                        if (launchIntent != null) {
                            apps.add(mapOf(
                                "appName" to appName,
                                "packageName" to packageName
                            ))
                        }
                    }
                } catch (e: Exception) {
                    // Skip apps that can't be processed
                    android.util.Log.w("MainActivity", "Skipping app due to error: $e")
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error getting installed apps: $e")
        }
        
        android.util.Log.d("MainActivity", "Found ${apps.size} apps")
        return apps.sortedBy { it["appName"] }
    }
}
