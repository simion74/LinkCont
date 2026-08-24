import 'package:flutter/services.dart';

/// Flutter থেকে নেটিভ Kotlin AccessibilityService-কে টাচ/ক্লিক/স্ক্রল কমান্ড পাঠায়।
/// শুধু host ডিভাইসে ব্যবহার হয় — এটাই আসল স্ক্রিনে জেসচার প্লে করে।
class RemoteControlChannel {
  static const _channel = MethodChannel('remote_screen/accessibility');

  /// ইউজারকে Settings > Accessibility-তে নিয়ে গিয়ে সার্ভিস চালু করতে বলা
  static Future<bool> isAccessibilityEnabled() async {
    return await _channel.invokeMethod('isAccessibilityEnabled');
  }

  static Future<void> openAccessibilitySettings() async {
    await _channel.invokeMethod('openAccessibilitySettings');
  }

  /// x, y স্ক্রিনের শতকরা (0.0–1.0) হিসেবে পাঠানো হয়, যাতে ভিউয়ারের স্ক্রিন-সাইজ
  /// আর হোস্টের স্ক্রিন-সাইজ ভিন্ন হলেও অনুপাত ঠিক থাকে।
  static Future<void> tap(double xPercent, double yPercent) {
    return _channel.invokeMethod('tap', {'x': xPercent, 'y': yPercent});
  }

  static Future<void> longPress(double xPercent, double yPercent) {
    return _channel.invokeMethod('longPress', {'x': xPercent, 'y': yPercent});
  }

  static Future<void> swipe(
    double x1, double y1, double x2, double y2, int durationMs,
  ) {
    return _channel.invokeMethod('swipe', {
      'x1': x1, 'y1': y1, 'x2': x2, 'y2': y2, 'durationMs': durationMs,
    });
  }

  static Future<void> scroll(double xPercent, double yPercent, double deltaY) {
    return _channel.invokeMethod('scroll', {
      'x': xPercent, 'y': yPercent, 'deltaY': deltaY,
    });
  }
}
