import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'signaling.dart';
import 'webrtc_service.dart';
import 'remote_control_channel.dart';
import 'widgets/glass_button.dart';
import 'widgets/screen_background.dart';
import 'widgets/settings_drawer.dart';
import 'widgets/app_menu_drawer.dart';
import 'widgets/linkcont_logo.dart';
import 'local_signaling_server.dart';

/// Host/Viewer দুটো স্ক্রিনেই ব্যবহৃত — ইন্টারনেট আইডি দিয়ে (কেন্দ্রীয় signaling
/// সার্ভার) নাকি একই WiFi/LAN নেটওয়ার্কে সরাসরি IP দিয়ে কানেক্ট হবে
enum ConnectMode { internetId, localIp }

/// Persistent unique ID for this phone — generated once and stored in
/// SharedPreferences, so it stays the same across app restarts.
/// No verification/account needed — just a random number tied to this device.
Future<String> getOrCreateDeviceId() async {
  final prefs = await SharedPreferences.getInstance();
  String? id = prefs.getString('device_id');
  if (id == null) {
    id = (100000000 + Random().nextInt(900000000)).toString(); // 9 digits
    await prefs.setString('device_id', id);
  }
  return id;
}

// Put your own signaling server address here (the Node.js server.js you deploy)
const String kSignalingUrl = 'wss://YOUR-SIGNALING-SERVER.example.com';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // পুরো অ্যাপ ডিফল্টভাবে পোর্ট্রেট — Home/Host screen-এর ব্যাকগ্রাউন্ড/UI
  // পোর্ট্রেটের জন্য বানানো। শুধু ViewerScreen (যেখানে অন্য ডিভাইসের স্ক্রিন
  // দেখা যায়) প্রয়োজনে নিজে থেকে ল্যান্ডস্কেপ অনুমতি দেবে — নিচে দেখুন।
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LinkCont',
      debugShowCheckedModeBanner: false, // hide the red "DEBUG" ribbon
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _deviceId;
  // মেনু/সেটিংস আইকন থেকে Scaffold-এর drawer/endDrawer খুলতে এই key ব্যবহার হয়
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    getOrCreateDeviceId().then((id) => setState(() => _deviceId = id));
  }

  void _copyId() {
    if (_deviceId == null) return;
    Clipboard.setData(ClipboardData(text: _deviceId!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ID copied')),
    );
  }

  void _shareId() {
    if (_deviceId == null) return;
    Share.share('My LinkCont ID: $_deviceId');
  }

  // সেটিংস ড্রয়ার থেকে "Generate New ID" চাপলে কল হয় — পুরনো ID মুছে নতুন
  // একটা বানিয়ে সেভ করে, home screen-এর কার্ডেও সাথে সাথে আপডেট হয়ে যায়
  Future<void> _regenerateId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('device_id');
    final newId = await getOrCreateDeviceId();
    setState(() => _deviceId = newId);
  }

  // ==== Move the button block up/down by changing these two flex numbers ====
  // Increasing topGapFlex pushes buttons down, decreasing pushes them up.
  // Increasing bottomGapFlex pushes buttons up (more empty space at the bottom).
  static const int topGapFlex = 3;
  static const int bottomGapFlex = 1;

  void _showHowItWorksDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0B2036),
        title:
            const Text('How It Works', style: TextStyle(color: Colors.white)),
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

  @override
  Widget build(BuildContext context) {
    // বড় ল্যান্ডস্কেপ স্ক্রিন (টিভি/কম্পিউটার) হলে প্রিমিয়াম ওয়েবসাইট-স্টাইল
    // লে-আউট, নাহলে আগের মোবাইল/ট্যাব লে-আউট — ScreenBackground যেভাবে
    // ব্যাকগ্রাউন্ড ছবি বেছে নেয় সেই একই শর্ত ব্যবহার করা হচ্ছে যাতে দুটো
    // সবসময় সিঙ্কে থাকে।
    final bool isWide = ScreenBackground.isTvOrPc(context);
    return Scaffold(
      key: _scaffoldKey,
      // বাঁ পাশে হ্যামবার্গার মেনু, ডানপাশে সেটিংস — দুটোই আলাদা Drawer
      drawer: const AppMenuDrawer(),
      endDrawer: SettingsDrawer(
        deviceId: _deviceId,
        onCopyId: _copyId,
        onRegenerateId: _regenerateId,
      ),
      body: ScreenBackground(
        // HomeScreen মোবাইল/ট্যাবে bg_frem.webp দেখাবে, বড় ল্যান্ডস্কেপ
        // স্ক্রিনে (টিভি/কম্পিউটার) স্বয়ংক্রিয়ভাবে pc_tv_frem.webp দেখাবে
        mobileAsset: 'assets/image/bg_frem.webp',
        child: SafeArea(
          child: isWide ? _buildWideLayout(context) : _buildCompactLayout(context),
        ),
      ),
    );
  }

  // ================= মোবাইল/ট্যাব (পোর্ট্রেট-স্টাইল) লে-আউট =================
  Widget _buildCompactLayout(BuildContext context) {
    return Padding(
      // === Control the home screen buttons' side padding here ===
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        children: [
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TopIconButton(
                icon: Icons.menu,
                onTap: () => _scaffoldKey.currentState?.openDrawer(),
              ),
              TopIconButton(
                icon: Icons.settings,
                onTap: () => _scaffoldKey.currentState?.openEndDrawer(),
              ),
            ],
          ),
          // ===== লোগো ছবি + ব্র্যান্ড ওয়ার্ডমার্ক + ইলাস্ট্রেশন =====
          // logo.webp (assets/image/icon.webp) সবসময় "LinkCont" লেখার
          // ঠিক আগে বসে — হোম স্ক্রিন, ড্রয়ার, সব জায়গায় একইভাবে।
          // computer_icon.webp: ল্যাপটপ+ফোন কনসেপ্ট আর্ট (রেডিমেড ছবি)।
          Expanded(
            flex: topGapFlex,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/image/icon.webp',
                      height: 34,
                      width: 34,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 8),
                    const LinkContLogo(fontSize: 34),
                  ],
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: Center(
                    child: Image.asset(
                      'assets/image/computer_icon.webp',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ===== ID card (previously the "Registration" button) =====
          // Tapping it doesn't navigate anywhere — only the copy icon
          // on the right copies the ID. A separate share icon sits
          // outside the card, to the right.
          Row(
            children: [
              Expanded(
                child: IdDisplayCard(
                  icon: Icons.badge_outlined,
                  label: _deviceId ?? 'Generating ID...',
                  glowColor: const Color(0xFF3ED67A),
                  onCopy: _copyId,
                  borderRadius: 12,
                  baseBorderWidth: 2.2, // static border — increase to thicken
                  glowBorderWidth: 5, // rotating glow — increase to thicken
                ),
              ),
              const SizedBox(width: 10),
              GlassCircleIconButton(
                icon: Icons.share_outlined,
                glowColor: const Color(0xFF3ED67A),
                onTap: _shareId,
              ),
            ],
          ),

          const SizedBox(height: 16),
          GlassGlowButton(
            icon: Icons.screen_share_outlined,
            label: 'Share Screen (Host)',
            glowColor: const Color(0xFF4FC3F7),
            borderRadius: 12,
            onTap: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const HostScreen())),
          ),
          const SizedBox(height: 16),
          GlassGlowButton(
            icon: Icons.visibility_outlined,
            label: 'Screen View',
            glowColor: const Color(0xFF4FC3F7),
            borderRadius: 12,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ViewerScreen())),
          ),
          const Spacer(flex: bottomGapFlex),
        ],
      ),
    );
  }

  // ============ টিভি/কম্পিউটার (প্রশস্ত স্ক্রিন) — প্রিমিয়াম ওয়েবসাইট-স্টাইল লে-আউট ============
  // উপরে: লোগো + "LinkCont" + ট্যাগলাইন, তারপর একটা হরাইজন্টাল মেনু-বার
  // (উদাহারন.jpeg রেফারেন্স অনুযায়ী)। নিচে: হিরো সেকশন — বাঁয়ে টেক্সট + ID
  // কার্ড + অ্যাকশন বাটন, ডানে ইলাস্ট্রেশন — যেন প্রিমিয়াম প্রোডাক্ট ওয়েবসাইটের
  // মতো দেখায়, মোবাইল লে-আউট শুধু বড় স্ক্রিনে টেনে বড় করা না।
  Widget _buildWideLayout(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ----- হেডার: লোগো + ওয়ার্ডমার্ক (বাঁয়ে), মেনু-বার (ডানে) -----
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset(
                'assets/image/icon.webp',
                height: 44,
                width: 44,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 12),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const LinkContLogo(fontSize: 26),
                  Text(
                    'REMOTE ACCESS PLATFORM',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.55),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2.2,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              _NavBarItem(
                icon: Icons.home_outlined,
                label: 'Home',
                onTap: () {},
              ),
              _NavBarItem(
                icon: Icons.help_outline,
                label: 'How It Works',
                onTap: _showHowItWorksDialog,
              ),
              _NavBarItem(
                icon: Icons.ios_share,
                label: 'Share App',
                onTap: () => Share.share(
                    'Check out LinkCont — share your screen, voice, and control devices remotely!'),
              ),
              const SizedBox(width: 4),
              TopIconButton(
                icon: Icons.menu,
                onTap: () => _scaffoldKey.currentState?.openDrawer(),
              ),
              TopIconButton(
                icon: Icons.settings,
                onTap: () => _scaffoldKey.currentState?.openEndDrawer(),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: Colors.white.withOpacity(0.10)),
          const SizedBox(height: 8),

          // ----- হিরো সেকশন: বাঁয়ে কন্টেন্ট, ডানে ইলাস্ট্রেশন -----
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 5,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Share your screen.\nControl any device, anywhere.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 34,
                              height: 1.2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Connect instantly with your unique ID, or stay on '
                            'the same WiFi/LAN for a direct local connection — '
                            'fast, simple, and secure.',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.72),
                              fontSize: 15,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 30),
                          Row(
                            children: [
                              Expanded(
                                child: IdDisplayCard(
                                  icon: Icons.badge_outlined,
                                  label: _deviceId ?? 'Generating ID...',
                                  glowColor: const Color(0xFF3ED67A),
                                  onCopy: _copyId,
                                  borderRadius: 12,
                                  baseBorderWidth: 2.2,
                                  glowBorderWidth: 5,
                                ),
                              ),
                              const SizedBox(width: 10),
                              GlassCircleIconButton(
                                icon: Icons.share_outlined,
                                glowColor: const Color(0xFF3ED67A),
                                onTap: _shareId,
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: GlassGlowButton(
                                  icon: Icons.screen_share_outlined,
                                  label: 'Share Screen (Host)',
                                  glowColor: const Color(0xFF4FC3F7),
                                  borderRadius: 12,
                                  onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => const HostScreen())),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: GlassGlowButton(
                                  icon: Icons.visibility_outlined,
                                  label: 'Screen View',
                                  glowColor: const Color(0xFF4FC3F7),
                                  borderRadius: 12,
                                  onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const ViewerScreen())),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 56),
                    Expanded(
                      flex: 4,
                      child: Image.asset(
                        'assets/image/computer_icon.webp',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// টিভি/কম্পিউটার হেডারের হরাইজন্টাল মেনু-বার আইটেম — হালকা আইকন + লেখা,
/// হোভার/ট্যাপে subtle হাইলাইট (ওয়েবসাইট নেভিগেশনের মতো)।
class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white.withOpacity(0.85), size: 18),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ================= HOST SCREEN =================
class HostScreen extends StatefulWidget {
  const HostScreen({super.key});
  @override
  State<HostScreen> createState() => _HostScreenState();
}

class _HostScreenState extends State<HostScreen> {
  late SignalingBase _signaling;
  WebRTCService? _rtc;
  String? _roomCode;
  String _status = 'Generating ID...';
  bool _accessibilityOn = false;

  // ডিফল্টভাবে ইন্টারনেট (আইডি) মোডে হোস্ট করে; ইউজার চাইলে টগল করে লোকাল
  // নেটওয়ার্ক (IP) মোডে যেতে পারবে — কর্পোরেট/অফিস LAN-এ ইন্টারনেট signaling
  // সার্ভার ছাড়াই সরাসরি IP দিয়ে কানেক্ট করানোর জন্য
  ConnectMode _mode = ConnectMode.internetId;
  List<String> _localAddresses = [];

  @override
  void initState() {
    super.initState();
    _checkAccessibility();
    _startInternetMode();
  }

  // দুই মোডের signaling object-ই একই callback দিয়ে wire হয় — WebRTCService,
  // accessibility control ফরওয়ার্ডিং সব অপরিবর্তিত থাকে, শুধু transport বদলায়
  void _wireSignaling(SignalingBase s) {
    s.onRoomCreated = (code) {
      if (_mode != ConnectMode.internetId) return;
      setState(() {
        _roomCode = code;
        _status = 'Waiting — share this ID with the other party';
      });
    };
    s.onViewerJoined = (viewerId) async {
      setState(() => _status = 'Viewer joined, starting stream...');
      final rtc = WebRTCService(s, isHost: true);
      rtc.onControlEvent = _handleIncomingControl;
      _rtc = rtc;
      await rtc.startHosting(viewerId);
      setState(() => _status = 'Sharing ✓');
    };
    s.onSignal = (fromId, data) => _rtc?.handleRemoteSignal(data);
    s.onError = (message) => setState(() => _status = 'Error: $message');
  }

  Future<void> _startInternetMode() async {
    final client = SignalingClient(kSignalingUrl);
    _signaling = client;
    _wireSignaling(client);
    client.connect();

    // Using this phone's persistent unique ID instead of a random code —
    // the ID stays the same even after reopening the app, no verification needed.
    final id = await getOrCreateDeviceId();
    client.createRoom(id);
  }

  Future<void> _startLocalMode() async {
    setState(() => _status = 'Starting local server...');
    final server = LocalSignalingServer();
    _signaling = server;
    _wireSignaling(server);
    try {
      final addresses = await server.start();
      setState(() {
        _localAddresses = addresses;
        _roomCode = addresses.isNotEmpty
            ? '${addresses.first}:${LocalSignalingServer.defaultPort}'
            : null;
        _status = addresses.isEmpty
            ? 'No local network found — connect to WiFi/LAN first'
            : 'Waiting — enter this IP on the other device (same WiFi/LAN)';
      });
    } catch (e) {
      setState(() => _status = 'Could not start local server: $e');
    }
  }

  Future<void> _switchMode(ConnectMode mode) async {
    if (mode == _mode) return;
    _rtc?.dispose();
    _signaling.dispose();
    _rtc = null;
    setState(() {
      _mode = mode;
      _roomCode = null;
      _localAddresses = [];
      _status = 'Generating ID...';
    });
    if (mode == ConnectMode.internetId) {
      await _startInternetMode();
    } else {
      await _startLocalMode();
    }
  }

  Future<void> _checkAccessibility() async {
    // web প্রিভিউ বা অন্য প্ল্যাটফর্মে এই নেটিভ চ্যানেলের ইমপ্লিমেন্টেশন
    // না থাকলেও (শুধু ডিজাইন দেখার জন্য), অ্যাপ যেন ভেঙে না পড়ে
    try {
      final on = await RemoteControlChannel.isAccessibilityEnabled();
      if (mounted) setState(() => _accessibilityOn = on);
    } catch (_) {
      // Android ছাড়া অন্য কোথাও এই ফিচার এমনিতেই প্রযোজ্য না
    }
  }

  // Touch/click/scroll events coming from the viewer → forwarded to the
  // native AccessibilityService
  void _handleIncomingControl(Map<String, dynamic> e) {
    if (!_accessibilityOn) return; // control is ignored without permission
    switch (e['type']) {
      case 'tap':
        RemoteControlChannel.tap(e['x'], e['y']);
        break;
      case 'longPress':
        RemoteControlChannel.longPress(e['x'], e['y']);
        break;
      case 'swipe':
        RemoteControlChannel.swipe(
            e['x1'], e['y1'], e['x2'], e['y2'], e['durationMs']);
        break;
      case 'scroll':
        RemoteControlChannel.scroll(e['x'], e['y'], e['deltaY']);
        break;
    }
  }

  @override
  void dispose() {
    _rtc?.dispose();
    _signaling.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ScreenBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    TopIconButton(
                        icon: Icons.arrow_back,
                        onTap: () => Navigator.pop(context)),
                    const SizedBox(width: 8),
                    const Text('Hosting',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                child: SegmentedButton<ConnectMode>(
                  segments: const [
                    ButtonSegment(
                        value: ConnectMode.internetId,
                        icon: Icon(Icons.public),
                        label: Text('Internet (ID)')),
                    ButtonSegment(
                        value: ConnectMode.localIp,
                        icon: Icon(Icons.wifi),
                        label: Text('Local Network (IP)')),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (s) => _switchMode(s.first),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_status,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 16)),
                    const SizedBox(height: 12),
                    if (_roomCode != null)
                      Card(
                        child: ListTile(
                          title: Text(
                            _roomCode!,
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                    letterSpacing: 2,
                                    fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(_mode == ConnectMode.internetId
                              ? 'Your Device ID'
                              : 'Local IP:Port — must be on the same WiFi/LAN'),
                          trailing: IconButton(
                            icon: const Icon(Icons.copy),
                            tooltip: 'Copy',
                            onPressed: () {
                              Clipboard.setData(
                                  ClipboardData(text: _roomCode!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(_mode ==
                                            ConnectMode.internetId
                                        ? 'ID copied'
                                        : 'IP:Port copied')),
                              );
                            },
                          ),
                        ),
                      ),
                    // একাধিক নেটওয়ার্ক ইন্টারফেস (WiFi + Ethernet) থাকলে বাকি
                    // ঠিকানাগুলোও ছোট করে দেখানো হচ্ছে — উপরে ভুল ইন্টারফেস
                    // দেখালে ইউজার এখান থেকে সঠিকটা বেছে নিতে পারবেন
                    if (_mode == ConnectMode.localIp &&
                        _localAddresses.length > 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 4),
                        child: Text(
                          'Other network interfaces: '
                          '${_localAddresses.skip(1).join(", ")}',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 12),
                        ),
                      ),
                    const SizedBox(height: 8),
                    if (!_accessibilityOn)
                      // Glass blur container — no solid background color,
                      // just a frosted/blurred glass panel like the rest of
                      // the app's UI.
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withOpacity(0.16),
                                  Colors.white.withOpacity(0.04),
                                ],
                              ),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.25),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withOpacity(0.14),
                                  ),
                                  child: const Icon(Icons.warning_amber,
                                      color: Colors.white, size: 26),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Grant Accessibility permission to enable remote control',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Otherwise the other party can only view, not control',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color:
                                          Colors.white.withOpacity(0.75),
                                      fontSize: 13),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed: () async {
                                      await RemoteControlChannel
                                          .openAccessibilitySettings();
                                      await _checkAccessibility();
                                    },
                                    icon: const Icon(Icons.settings, size: 18),
                                    label: const Text('Settings'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================= VIEWER SCREEN =================
class ViewerScreen extends StatefulWidget {
  const ViewerScreen({super.key});
  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  final _codeController = TextEditingController();
  final _ipController = TextEditingController();
  SignalingBase? _signaling;
  WebRTCService? _rtc;
  final _renderer = RTCVideoRenderer();
  bool _joined = false;

  // ডিফল্টভাবে ইন্টারনেট (আইডি) মোডে জয়েন করে; ইউজার টগল করে লোকাল নেটওয়ার্ক
  // (IP) মোডে গেলে host-এর IP:Port সরাসরি বসিয়ে কানেক্ট করতে পারবে
  ConnectMode _mode = ConnectMode.internetId;

  // host-এর ভিডিও landscape (PC/TV) নাকি portrait (মোবাইল) — এটা ট্র্যাক করে
  // রাখা হয়, যাতে বারবার একই orientation সেট না করতে হয়
  bool _remoteIsLandscape = false;

  @override
  void initState() {
    super.initState();
    _renderer.initialize();
    // host-এর ভিডিওর সাইজ প্রথমবার জানা গেলে বা বদলালে এটা কল হয় —
    // এখান থেকেই বোঝা যায় host portrait (মোবাইল) নাকি landscape (PC/TV) স্ট্রিম পাঠাচ্ছে
    _renderer.onResize = _handleRemoteResize;
  }

  // host landscape (PC/TV) স্ক্রিন পাঠালে ভিউয়ার ফোনকেও landscape-এ ঘোরার
  // অনুমতি দেওয়া হয় (তখন device rotation sensor অনুযায়ী ফোন নিজে থেকে
  // landscape দেখাবে); host portrait (মোবাইল) হলে ফোন portrait-এই লক থাকে।
  // এতে ভিডিওটা যতটা সম্ভব বড় ও সঠিক অনুপাতে দেখা যায়, ছোট letterbox হয়ে থাকে না।
  void _handleRemoteResize() {
    final w = _renderer.videoWidth;
    final h = _renderer.videoHeight;
    if (w <= 0 || h <= 0) return;
    final isLandscape = w > h;
    if (isLandscape == _remoteIsLandscape) return;
    _remoteIsLandscape = isLandscape;
    SystemChrome.setPreferredOrientations(
      isLandscape
          ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
          : [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown],
    );
  }

  void _wireViewerSignaling(SignalingBase s) {
    s.onSignal = (fromId, data) async {
      if (_rtc == null) {
        final rtc = WebRTCService(s, isHost: false);
        rtc.onRemoteStream = (stream) {
          _renderer.srcObject = stream;
          setState(() {});
        };
        _rtc = rtc;
      }
      await _rtc!.prepareViewer(fromId);
      await _rtc!.handleRemoteSignal(data);
    };
  }

  void _join() {
    if (_mode == ConnectMode.internetId) {
      final code = _codeController.text.trim();
      if (code.isEmpty) return;
      final client = SignalingClient(kSignalingUrl);
      _signaling = client;
      _wireViewerSignaling(client);
      client.connect();
      client.joinRoom(code);
    } else {
      final ip = _ipController.text.trim();
      if (ip.isEmpty) return;
      // শুধু IP দিলে ডিফল্ট পোর্ট যোগ হয়; "ip:port" আকারে দিলে সেটাই ব্যবহার হয়
      final target =
          ip.contains(':') ? ip : '$ip:${LocalSignalingServer.defaultPort}';
      final client = SignalingClient('ws://$target');
      _signaling = client;
      _wireViewerSignaling(client);
      client.connect();
      client.joinRoom('direct'); // লোকাল মোডে room code-এর কোনো মানে নেই
    }
    setState(() => _joined = true);
  }

  // Convert trackpad pan/tap events into normalized (0-1) coordinates and send them
  void _sendTap(double xPercent, double yPercent) {
    _rtc?.sendControlEvent({'type': 'tap', 'x': xPercent, 'y': yPercent});
  }

  void _sendScroll(double xPercent, double yPercent, double deltaY) {
    _rtc?.sendControlEvent(
        {'type': 'scroll', 'x': xPercent, 'y': yPercent, 'deltaY': deltaY});
  }

  @override
  void dispose() {
    // এই স্ক্রিন ছাড়ার সময় অ্যাপ-ওয়াইড ডিফল্ট (পোর্ট্রেট)-এ ফিরিয়ে আনা হচ্ছে,
    // যাতে ল্যান্ডস্কেপ স্ট্রিম দেখে বের হওয়ার পরেও বাকি অ্যাপ পোর্ট্রেটেই থাকে
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _renderer.dispose();
    _rtc?.dispose();
    _signaling?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_joined) {
      return Scaffold(
        body: ScreenBackground(
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      TopIconButton(
                          icon: Icons.arrow_back,
                          onTap: () => Navigator.pop(context)),
                      const SizedBox(width: 8),
                      const Text('Screen View',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      // Internet (ID) vs Local Network (IP) — কোন মোডে জয়েন
                      // করবে সেটা এখান থেকে বেছে নেওয়া যায়
                      SegmentedButton<ConnectMode>(
                        segments: const [
                          ButtonSegment(
                            value: ConnectMode.internetId,
                            icon: Icon(Icons.public),
                            label: Text('ID (Internet)'),
                          ),
                          ButtonSegment(
                            value: ConnectMode.localIp,
                            icon: Icon(Icons.wifi),
                            label: Text('IP (Local Network)'),
                          ),
                        ],
                        selected: {_mode},
                        onSelectionChanged: (s) =>
                            setState(() => _mode = s.first),
                      ),
                      const SizedBox(height: 20),
                      if (_mode == ConnectMode.internetId)
                        TextField(
                          controller: _codeController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Enter 9-digit ID',
                            labelStyle: TextStyle(color: Colors.white70),
                            enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.white54)),
                          ),
                          keyboardType: TextInputType.number,
                        )
                      else
                        TextField(
                          controller: _ipController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Enter host IP (e.g. 192.168.0.12)',
                            labelStyle: TextStyle(color: Colors.white70),
                            helperText:
                                'Same WiFi/LAN — no internet needed. Add :port only if different from default.',
                            helperStyle: TextStyle(color: Colors.white54),
                            helperMaxLines: 2,
                            enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.white54)),
                          ),
                          keyboardType: TextInputType.url,
                        ),
                      const SizedBox(height: 20),
                      GlassGlowButton(
                        icon: Icons.login,
                        label: 'Connect',
                        glowColor: const Color(0xFF05F411),
                        onTap: _join,
                      ),
                    ],
                  ),
                ),
                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Live View')),
      body: Stack(
        children: [
          Positioned.fill(
            child: RTCVideoView(_renderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain),
          ),
          // Tapping on the video sends that relative (%) position as a tap
          // to the host's screen
          Positioned.fill(
            child: LayoutBuilder(builder: (context, constraints) {
              return GestureDetector(
                onTapUp: (d) => _sendTap(
                  d.localPosition.dx / constraints.maxWidth,
                  d.localPosition.dy / constraints.maxHeight,
                ),
                onPanUpdate: (d) => _sendScroll(
                  d.localPosition.dx / constraints.maxWidth,
                  d.localPosition.dy / constraints.maxHeight,
                  d.delta.dy,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
