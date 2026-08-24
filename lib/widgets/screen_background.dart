import 'package:flutter/material.dart';

/// রেসপন্সিভ ব্যাকগ্রাউন্ড — একই উইজেট মোবাইল/ট্যাব এবং টিভি/কম্পিউটার দুই ধরনের
/// স্ক্রিনেই ব্যবহার করা যাবে, শুধু স্ক্রিনের সাইজ/অরিয়েন্টেশন দেখে সঠিক ছবিটা
/// (mobileAsset বা tvPcAsset) নিজে থেকেই বেছে নেয়।
///
/// ডিফল্টভাবে HomeScreen ছাড়া বাকি "ভেতরের" পেজগুলোর (Host/Viewer ইত্যাদি)
/// জন্য assets/image/screen_frem.webp (মোবাইল) এবং assets/image/pc_tv_frem.webp
/// (টিভি/কম্পিউটার) ব্যবহার হয়। HomeScreen নিজের mobileAsset হিসেবে
/// assets/image/bg_frem.webp পাস করে দেয় (নিচে main.dart দ্রষ্টব্য)।
///
/// ব্যবহার:
/// return Scaffold(
///   body: ScreenBackground(
///     child: ...আপনার আসল কন্টেন্ট...,
///   ),
/// );
class ScreenBackground extends StatelessWidget {
  final Widget child;
  final String mobileAsset;
  final String tvPcAsset;

  const ScreenBackground({
    super.key,
    required this.child,
    this.mobileAsset = 'assets/image/screen_frem.webp',
    this.tvPcAsset = 'assets/image/pc_tv_frem.webp',
  });

  /// মোবাইল/ট্যাব vs টিভি/কম্পিউটার — এখন MediaQuery দিয়ে (landscape +
  /// চওড়া shortestSide) অনুমান করা হচ্ছে। আসল Android TV-তে UiModeManager
  /// দিয়ে আরও নিখুঁতভাবে বের করা সম্ভব — সেটা পরে একটা MethodChannel দিয়ে
  /// যোগ করা যাবে, তখন এই ফাংশনটাই শুধু বদলালেই হবে, বাকি কোড অপরিবর্তিত থাকবে।
  static bool isTvOrPc(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.width > size.height && size.shortestSide > 600;
  }

  @override
  Widget build(BuildContext context) {
    final asset = isTvOrPc(context) ? tvPcAsset : mobileAsset;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(asset, fit: BoxFit.cover),
        child,
      ],
    );
  }
}
