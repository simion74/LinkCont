package com.example.remotescreen

import android.content.Intent
import android.provider.Settings
import android.text.TextUtils
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "remote_screen/accessibility"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                val svc = RemoteAccessibilityService.instance
                when (call.method) {
                    "isAccessibilityEnabled" -> result.success(isAccessibilityServiceEnabled())
                    "openAccessibilitySettings" -> {
                        startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                        result.success(null)
                    }
                    "tap" -> {
                        svc?.tap(call.argument<Double>("x")!!, call.argument<Double>("y")!!)
                        result.success(null)
                    }
                    "longPress" -> {
                        svc?.longPress(call.argument<Double>("x")!!, call.argument<Double>("y")!!)
                        result.success(null)
                    }
                    "swipe" -> {
                        svc?.swipe(
                            call.argument<Double>("x1")!!, call.argument<Double>("y1")!!,
                            call.argument<Double>("x2")!!, call.argument<Double>("y2")!!,
                            call.argument<Int>("durationMs")!!.toLong()
                        )
                        result.success(null)
                    }
                    "scroll" -> {
                        svc?.scroll(
                            call.argument<Double>("x")!!, call.argument<Double>("y")!!,
                            call.argument<Double>("deltaY")!!
                        )
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val expectedComponent = "$packageName/${RemoteAccessibilityService::class.java.name}"
        val enabledServices = Settings.Secure.getString(
            contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        val splitter = TextUtils.SimpleStringSplitter(':')
        splitter.setString(enabledServices)
        while (splitter.hasNext()) {
            if (splitter.next().equals(expectedComponent, ignoreCase = true)) return true
        }
        return false
    }
}
