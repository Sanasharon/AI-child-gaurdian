package com.example.ai_child_guardian

import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.ai_child_guardian/config"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getMapsApiKey") {
                try {
                    val appInfo = packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
                    val apiKey = appInfo.metaData?.getString("com.google.android.geo.API_KEY")
                    result.success(apiKey)
                } catch (e: Exception) {
                    result.error("UNAVAILABLE", "Could not read metadata", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
