package com.example.remotescreen

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.graphics.Path
import android.util.DisplayMetrics
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent

/**
 * ভিউয়ার থেকে আসা normalized (0.0–1.0) কো-অর্ডিনেটকে আসল স্ক্রিন পিক্সেলে রূপান্তর করে
 * dispatchGesture() দিয়ে ট্যাপ/লং-প্রেস/সোয়াইপ/স্ক্রল প্লে করে।
 * এটাই একমাত্র উপায় যেভাবে একটা অ্যাপ অন্য অ্যাপের ভেতরে টাচ ইনজেক্ট করতে পারে (root ছাড়া)।
 */
class RemoteAccessibilityService : AccessibilityService() {

    companion object {
        // MainActivity থেকে এখানে সরাসরি রেফারেন্স রাখা হচ্ছে যাতে MethodChannel থেকে কল করা যায়
        var instance: RemoteAccessibilityService? = null
    }

    private var screenW = 0
    private var screenH = 0

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        val wm = getSystemService(WINDOW_SERVICE) as WindowManager
        val metrics = DisplayMetrics()
        @Suppress("DEPRECATION")
        wm.defaultDisplay.getRealMetrics(metrics)
        screenW = metrics.widthPixels
        screenH = metrics.heightPixels
    }

    override fun onDestroy() {
        instance = null
        super.onDestroy()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {}
    override fun onInterrupt() {}

    private fun px(xPercent: Double, yPercent: Double): Pair<Float, Float> {
        val x = (xPercent * screenW).toFloat().coerceIn(0f, screenW.toFloat())
        val y = (yPercent * screenH).toFloat().coerceIn(0f, screenH.toFloat())
        return Pair(x, y)
    }

    fun tap(xPercent: Double, yPercent: Double) {
        val (x, y) = px(xPercent, yPercent)
        val path = Path().apply { moveTo(x, y) }
        val stroke = GestureDescription.StrokeDescription(path, 0, 50)
        dispatchGesture(GestureDescription.Builder().addStroke(stroke).build(), null, null)
    }

    fun longPress(xPercent: Double, yPercent: Double) {
        val (x, y) = px(xPercent, yPercent)
        val path = Path().apply { moveTo(x, y) }
        val stroke = GestureDescription.StrokeDescription(path, 0, 600)
        dispatchGesture(GestureDescription.Builder().addStroke(stroke).build(), null, null)
    }

    fun swipe(x1p: Double, y1p: Double, x2p: Double, y2p: Double, durationMs: Long) {
        val (x1, y1) = px(x1p, y1p)
        val (x2, y2) = px(x2p, y2p)
        val path = Path().apply { moveTo(x1, y1); lineTo(x2, y2) }
        val stroke = GestureDescription.StrokeDescription(path, 0, durationMs)
        dispatchGesture(GestureDescription.Builder().addStroke(stroke).build(), null, null)
    }

    /** ছোট ছোট swipe দিয়ে স্ক্রল সিমুলেট করা হয় (deltaY অনুযায়ী উপরে/নিচে) */
    fun scroll(xPercent: Double, yPercent: Double, deltaY: Double) {
        val (x, y) = px(xPercent, yPercent)
        val endY = (y - (deltaY * 3)).coerceIn(0f, screenH.toFloat())
        val path = Path().apply { moveTo(x, y); lineTo(x, endY) }
        val stroke = GestureDescription.StrokeDescription(path, 0, 80)
        dispatchGesture(GestureDescription.Builder().addStroke(stroke).build(), null, null)
    }
}
