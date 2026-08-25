import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'linkcont_logo.dart';

/// টপ-বার-এর মেনু (হ্যামবার্গার) আইকনে ট্যাপ করলে বাঁ পাশ থেকে খোলা ড্রয়ার।
/// অ্যাপ কীভাবে কাজ করে সেটার শর্ট গাইড, শেয়ার এবং সাধারণ তথ্য এখানে রাখা হলো।
class AppMenuDrawer extends StatelessWidget {
  const AppMenuDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.transparent,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              // আগে ছিল প্রায়-কালো নেভি (#061428 → #04101F) — এতে লোগোর
              // নীল অংশ ব্যাকগ্রাউন্ডে মিশে অদৃশ্য হয়ে যাচ্ছিল। এখন brand
              // এর নিজের রং (গাঢ় নীল → গাঢ় টিল) দিয়ে গ্র্যাডিয়েন্ট, যেটা
              // কালো না অথচ যথেষ্ট গাঢ় থাকে সাদা লেখা পড়তে — এবং লোগোর
              // নিচে আলাদা হালকা "চিপ" থাকায় লোগো সবসময় স্পষ্ট বোঝা যায়।
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF102A52).withOpacity(0.97),
                  const Color(0xFF0B3B33).withOpacity(0.98),
                ],
              ),
              border: Border(
                right: BorderSide(
                    color: Colors.white.withOpacity(0.10), width: 1),
              ),
            ),
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                    child: Row(
                      children: [
                        // লোগোর পেছনে হালকা সাদা গ্লো-চিপ — যেকোনো ব্যাকগ্রাউন্ড
                        // রঙেই (হালকা/গাঢ়) লোগোর নীল-সবুজ রং স্পষ্ট দেখা যাবে
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.94),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF12DAA2)
                                    .withOpacity(0.35),
                                blurRadius: 14,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Image.asset('assets/image/icon.webp',
                              height: 32, width: 32, fit: BoxFit.contain),
                        ),
                        const SizedBox(width: 12),
                        const LinkContLogo(fontSize: 20),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white12, height: 1),
                  const SizedBox(height: 8),
                  ListTile(
                    leading:
                        const Icon(Icons.home_outlined, color: Colors.white70),
                    title: const Text('Home',
                        style: TextStyle(color: Colors.white)),
                    onTap: () => Navigator.pop(context),
                  ),
                  ListTile(
                    leading: const Icon(Icons.help_outline,
                        color: Colors.white70),
                    title: const Text('How It Works',
                        style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(context);
                      _showHowItWorks(context);
                    },
                  ),
                  ListTile(
                    leading:
                        const Icon(Icons.ios_share, color: Colors.white70),
                    title: const Text('Share This App',
                        style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(context);
                      Share.share(
                          'Check out LinkCont — share your screen, voice, and control devices remotely!');
                    },
                  ),
                  ListTile(
                    leading:
                        const Icon(Icons.info_outline, color: Colors.white70),
                    title: const Text('About',
                        style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(context);
                      showAboutDialog(
                        context: context,
                        applicationName: 'LinkCont',
                        applicationVersion: '1.0.0',
                        applicationIcon: Image.asset(
                            'assets/image/icon.webp',
                            height: 40,
                            width: 40),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showHowItWorks(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0B2036),
        title: const Text('How It Works',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          '1. Share your unique ID with the other device.\n'
          '2. On the other device, tap "Screen View" and enter that ID.\n'
          '3. Tap "Share Screen (Host)" to start sharing your screen and voice.\n'
          '4. Grant the Accessibility permission on the host device to allow '
          'remote control.',
          style: TextStyle(color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Got it')),
        ],
      ),
    );
  }
}
