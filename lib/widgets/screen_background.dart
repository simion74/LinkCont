import 'package:flutter/material.dart';

/// রেসপন্সিভ ব্যাকগ্রাউন্ড — একই উইজেট মোবাইল/ট্যাব এবং টিভি/কম্পিউটার দুই ধরনের
/// স্ক্রিনেই ব্যবহার করা যাবে, শুধু স্ক্রিনের সাইজ/অরিয়েন্টেশন দেখে সঠিক ছবিটা
/// (mobileAsset বা tvPcAsset) নিজে থেকেই বেছে নেয়।
///
/// ⚠️ আগে ডিফল্ট mobileAsset ছিল assets/image/screen_frem.webp — সেই ফাইলটা
/// ডিলিট হয়ে গেছে (আর pubspec.yaml-এর assets তালিকাতেও নেই), তাই ডিফল্ট
/// bg_frem.webp-তে পরিবর্তন করা হলো (এটাই এখন একমাত্র মোবাইল ব্যাকগ্রাউন্ড
/// ছবি যেটা আসলে আছে) — নাহলে Host/Viewer স্ক্রিন যেগুলো mobileAsset
/// ওভাররাইড না করে ব্যবহার করে, সেগুলোতে asset-not-found এরর হতো।
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
    this.mobileAsset = 'assets/image/bg_frem.webp',
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
