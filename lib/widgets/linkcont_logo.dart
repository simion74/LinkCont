import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ব্র্যান্ড ওয়ার্ডমার্ক — "Link" সাদা + "Cont" লোগোর মতোই সবুজ→সায়ান গ্র্যাডিয়েন্ট।
/// রঙ দুটো icon.webp লোগো থেকে সরাসরি স্যাম্পল করা (লাইম-গ্রিন → টিল/সায়ান)।
///
/// এটা ছবি না — সরাসরি কোড দিয়ে আঁকা টেক্সট, তাই যেকোনো সাইজে বসানো যাবে
/// (হোম স্ক্রিন, অ্যাপবার, স্প্ল্যাশ, ড্রয়ার — যেখানেই লাগবে) এবং সবসময়
/// পরিষ্কার/শার্প দেখাবে (ছবির মতো ব্লার/পিক্সেলেটেড হবে না)।
///
/// fontSize বদলালে letterSpacing নিজে থেকেই সাইজ অনুযায়ী স্কেল হয়
/// (-1px থেকে -2px রেঞ্জ, স্পেসিফিকেশন অনুযায়ী)।
class LinkContLogo extends StatelessWidget {
  final double fontSize;
  final FontWeight fontWeight;

  const LinkContLogo({
    super.key,
    this.fontSize = 34,
    this.fontWeight = FontWeight.w800, // Poppins ExtraBold
  });

  // লোগো (icon.webp)-এর সবুজ অংশ থেকে স্যাম্পল করা আসল রং দুটো
  static const Color _gradientStart = Color(0xFF8BF332); // লাইম-গ্রিন
  static const Color _gradientEnd = Color(0xFF12DAA2); // টিল/সায়ান

  @override
  Widget build(BuildContext context) {
    // fontSize বাড়লে/কমলে letterSpacing-ও সেই অনুপাতে বদলায় (-1px থেকে -2px)
    final double letterSpacing = -(fontSize * 0.045).clamp(1.0, 2.0);

    final baseStyle = GoogleFonts.poppins(
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: 1.0,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Link', style: baseStyle.copyWith(color: Colors.white)),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [_gradientStart, _gradientEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds),
          child: Text('Cont', style: baseStyle.copyWith(color: Colors.white)),
        ),
      ],
    );
  }
}
