import 'dart:async';
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

// এখানে আপনার signaling সার্ভারের ঠিকানা বসবে (এখনো বসানো হয়নি —
// PROTOCOL.md দেখুন সার্ভারটা ঠিক কী মেসেজ-কনট্র্যাক্ট মানতে হবে তার জন্য)
const String kSignalingUrl = 'wss://YOUR-SIGNALING-SERVER.example.com';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // পুরো অ্যাপ পোর্ট্রেট — শুধু লাইভ-ভিউ স্ক্রিন (অন্য ডিভাইসের স্ক্রিন
  // দেখার সময়) প্রয়োজনে নিজে থেকে ল্যান্ডস্কেপ অনুমতি দেবে।
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
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const HomeScreen(),
    );
  }
}

// ================= HOME SCREEN =================
// এখন এটাই একমাত্র "হাব" স্ক্রিন — এখানেই signaling কানেকশন সারা অ্যাপ
// চলাকালীন (foreground-এ থাকা অবস্থায়) খোলা থাকে, যাতে অ্যাপের যেকোনো
// জায়গায় থাকলেও ইনকামিং কল-রিকোয়েস্ট ধরা যায়। HostScreen/ViewerScreen
// এখন শুধু এই একই SignalingClient ধার নিয়ে সাময়িকভাবে খোলে।
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _deviceId;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _targetIdController = TextEditingController();

  late final SignalingClient _signaling;
  StreamSubscription<SignalingEvent>? _sub;

  // আমি নিজে যাকে রিকোয়েস্ট পাঠিয়েছি, তার জবাবের অপেক্ষায় আছি কিনা
  bool _calling = false;
  String? _callingTargetId;

  @override
  void initState() {
    super.initState();
    _signaling = SignalingClient(kSignalingUrl);
    _sub = _signaling.events.listen(_handleEvent);
    getOrCreateDeviceId().then((id) {
      setState(() => _deviceId = id);
      _signaling.connect(id);
    });
  }

  void _handleEvent(SignalingEvent event) {
    if (!mounted) return;
    switch (event) {
      case IncomingRequestEvent(:final fromId):
        _showIncomingRequestDialog(fromId);
        break;

      case RequestAcceptedEvent(:final fromId):
        if (!_calling || _callingTargetId != fromId) return;
        setState(() {
          _calling = false;
          _callingTargetId = null;
        });
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ViewerScreen(signaling: _signaling, peerId: fromId),
          ),
        );
        break;

      case RequestRejectedEvent(:final fromId):
        if (_callingTargetId == fromId) {
          setState(() {
            _calling = false;
            _callingTargetId = null;
          });
          _snack('Request declined');
        }
        break;

      case PeerOfflineEvent(:final targetId):
        if (_callingTargetId == targetId) {
          setState(() {
            _calling = false;
            _callingTargetId = null;
          });
          _snack('This ID is not online right now');
        }
        break;

      case SignalingErrorEvent(:final message):
        _snack(message);
        break;

      default:
        // SignalDataEvent / PeerLeftEvent / RegisteredEvent — HomeScreen-এর
        // কিছু করার নেই, চলমান সেশন স্ক্রিন থাকলে সেটা নিজে শুনছে।
        break;
    }
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(text)));
  }

  // কেউ আমার স্ক্রিন দেখতে/কন্ট্রোল করতে চাইলে এই ডায়ালগ দেখানো হয়
  void _showIncomingRequestDialog(String fromId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0B2036),
        title: const Text('Incoming request',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'Device $fromId wants to view and control your screen.\n\n'
          'Allow?',
          style: const TextStyle(color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _signaling.respondToRequest(fromId, false);
              Navigator.pop(ctx);
            },
            child: const Text('Decline'),
          ),
          FilledButton(
            onPressed: () {
              _signaling.respondToRequest(fromId, true);
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      HostScreen(signaling: _signaling, peerId: fromId),
                ),
              );
            },
            child: const Text('Allow'),
          ),
        ],
      ),
    );
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

  Future<void> _regenerateId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('device_id');
    final newId = await getOrCreateDeviceId();
    setState(() => _deviceId = newId);
    // নতুন ID দিয়ে আবার register করতে হবে
    _signaling.connect(newId);
  }

  void _connect() {
    final target = _targetIdController.text.trim();
    if (target.isEmpty) return;
    if (_deviceId != null && target == _deviceId) {
      _snack('You cannot connect to your own ID');
      return;
    }
    setState(() {
      _calling = true;
      _callingTargetId = target;
    });
    _signaling.requestCall(target);
  }

  void _cancelCalling() {
    if (_callingTargetId != null) {
      _signaling.hangup(_callingTargetId!);
    }
    setState(() {
      _calling = false;
      _callingTargetId = null;
    });
  }

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
          '1. Share your unique ID with the other device (mobile, tablet, '
          'or Android TV).\n'
          '2. On the other device, enter that ID and tap Connect.\n'
          '3. You\'ll get a prompt asking to allow screen access — tap '
          'Allow to start sharing your screen, voice, and control.\n'
          '4. Grant the Accessibility permission when asked, so the other '
          'party can control your device (not just view it).',
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
  void dispose() {
    _sub?.cancel();
    _signaling.dispose();
    _targetIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isWide = ScreenBackground.isTvOrPc(context);
    return Scaffold(
      key: _scaffoldKey,
      drawer: const AppMenuDrawer(),
      endDrawer: SettingsDrawer(
        deviceId: _deviceId,
        onCopyId: _copyId,
        onRegenerateId: _regenerateId,
      ),
      body: ScreenBackground(
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
                    // computer_icon.webp সরিয়ে design_icon.webp বসানো হলো —
                    // এখন কম্পিউটার/PC কনসেপ্ট নেই, শুধু মোবাইল/ট্যাব/TV
                    child: Image.asset(
                      'assets/image/design_icon.webp',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ],
            ),
          ),

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

          const SizedBox(height: 16),
          // Host/Viewer আলাদা বাটন আর নেই — একটাই ইনপুট: অন্য ডিভাইসের ID
          // দিলে Connect চাপলেই সেই ডিভাইসের কাছে অনুরোধ যাবে
          TextField(
            controller: _targetIdController,
            style: const TextStyle(color: Colors.white),
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "Enter the other device's ID",
              labelStyle: TextStyle(color: Colors.white70),
              enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white54)),
            ),
          ),
          const SizedBox(height: 16),
          if (_calling)
            Row(
              children: [
                Expanded(
                  child: GlassGlowButton(
                    icon: Icons.hourglass_top,
                    label: 'Calling $_callingTargetId — waiting...',
                    glowColor: const Color(0xFFFFC107),
                    borderRadius: 12,
                    onTap: () {}, // অপেক্ষার সময় কোনো অ্যাকশন নেই
                  ),
                ),
                const SizedBox(width: 8),
                GlassCircleIconButton(
                  icon: Icons.close,
                  glowColor: const Color(0xFFFF5252),
                  onTap: _cancelCalling,
                ),
              ],
            )
          else
            GlassGlowButton(
              icon: Icons.login,
              label: 'Connect',
              glowColor: const Color(0xFF4FC3F7),
              borderRadius: 12,
              onTap: _connect,
            ),
          const Spacer(flex: bottomGapFlex),
        ],
      ),
    );
  }

  // ============ টিভি (প্রশস্ত স্ক্রিন) — প্রিমিয়াম লে-আউট ============
  Widget _buildWideLayout(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                    'Check out LinkCont — share your screen, voice, and control your Android devices remotely!'),
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
                            'Share your screen.\nControl any Android device, anywhere.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 34,
                              height: 1.2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Enter the other device\'s ID and connect instantly — '
                            'they\'ll get a prompt to allow access. Fast, simple, secure.',
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
                          TextField(
                            controller: _targetIdController,
                            style: const TextStyle(color: Colors.white),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: "Enter the other device's ID",
                              labelStyle: TextStyle(color: Colors.white70),
                              enabledBorder: UnderlineInputBorder(
                                  borderSide:
                                      BorderSide(color: Colors.white54)),
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (_calling)
                            Row(
                              children: [
                                Expanded(
                                  child: GlassGlowButton(
                                    icon: Icons.hourglass_top,
                                    label:
                                        'Calling $_callingTargetId — waiting...',
                                    glowColor: const Color(0xFFFFC107),
                                    borderRadius: 12,
                                    onTap: () {},
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GlassCircleIconButton(
                                  icon: Icons.close,
                                  glowColor: const Color(0xFFFF5252),
                                  onTap: _cancelCalling,
                                ),
                              ],
                            )
                          else
                            GlassGlowButton(
                              icon: Icons.login,
                              label: 'Connect',
                              glowColor: const Color(0xFF4FC3F7),
                              borderRadius: 12,
                              onTap: _connect,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 56),
                    Expanded(
                      flex: 4,
                      child: Image.asset(
                        'assets/image/design_icon.webp',
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

// ================= HOST SESSION SCREEN =================
// আগে এই স্ক্রিনটাই মোড বেছে "waiting for viewer" দেখাত। এখন এটা শুধু
// তখনই খোলে যখন ইতিমধ্যে একটা call-request accept হয়ে গেছে (HomeScreen
// থেকে peerId নিয়ে) — তাই সরাসরি হোস্টিং শুরু করে দেয়, কোনো মোড/অপেক্ষা নেই।
class HostScreen extends StatefulWidget {
  final SignalingClient signaling;
  final String peerId; // যে ডিভাইস আমার স্ক্রিন দেখবে/কন্ট্রোল করবে

  const HostScreen({super.key, required this.signaling, required this.peerId});

  @override
  State<HostScreen> createState() => _HostScreenState();
}

class _HostScreenState extends State<HostScreen> {
  WebRTCService? _rtc;
  StreamSubscription<SignalingEvent>? _sub;
  String _status = 'Starting...';
  bool _accessibilityOn = false;

  @override
  void initState() {
    super.initState();
    _checkAccessibility();
    _sub = widget.signaling.events.listen(_handleEvent);
    _startHosting();
  }

  Future<void> _startHosting() async {
    final rtc = WebRTCService(widget.signaling, isHost: true);
    rtc.onControlEvent = _handleIncomingControl;
    _rtc = rtc;
    try {
      await rtc.startHosting(widget.peerId);
      if (mounted) setState(() => _status = 'Sharing ✓');
    } catch (e) {
      if (mounted) setState(() => _status = 'Could not start sharing: $e');
    }
  }

  void _handleEvent(SignalingEvent event) {
    if (!mounted) return;
    switch (event) {
      case SignalDataEvent(:final fromId, :final data):
        if (fromId == widget.peerId) {
          _rtc?.handleRemoteSignal(data);
        }
        break;
      case PeerLeftEvent(:final peerId):
        if (peerId == widget.peerId) {
          _status = 'The other device disconnected';
          Navigator.of(context).maybePop();
        }
        break;
      default:
        break;
    }
  }

  Future<void> _checkAccessibility() async {
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

  void _endSession() {
    widget.signaling.hangup(widget.peerId);
    Navigator.of(context).maybePop();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _rtc?.dispose(); // শুধু এই সেশনের P2P কানেকশন বন্ধ হয়, signaling খোলাই থাকে
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
                        icon: Icons.call_end, onTap: _endSession),
                    const SizedBox(width: 8),
                    const Text('Sharing your screen',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600)),
                  ],
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
                    const SizedBox(height: 4),
                    Text('Connected to: ${widget.peerId}',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 13)),
                    const SizedBox(height: 12),
                    if (!_accessibilityOn)
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

// ================= VIEWER SESSION SCREEN =================
// আগের মতো ID/IP এন্ট্রি স্ক্রিন নেই — এটা শুধু তখনই খোলে যখন অপরপাশ
// ইতিমধ্যে অনুরোধ accept করে ফেলেছে, তাই সরাসরি ভিডিও-ভিউ দেখানো শুরু করে।
class ViewerScreen extends StatefulWidget {
  final SignalingClient signaling;
  final String peerId; // যার স্ক্রিন দেখছি/কন্ট্রোল করছি

  const ViewerScreen(
      {super.key, required this.signaling, required this.peerId});

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  WebRTCService? _rtc;
  StreamSubscription<SignalingEvent>? _sub;
  final _renderer = RTCVideoRenderer();
  bool _remoteIsLandscape = false;
  bool _connected = false;

  @override
  void initState() {
    super.initState();
    _renderer.initialize();
    _renderer.onResize = _handleRemoteResize;
    _sub = widget.signaling.events.listen(_handleEvent);
  }

  void _handleEvent(SignalingEvent event) async {
    if (!mounted) return;
    switch (event) {
      case SignalDataEvent(:final fromId, :final data):
        if (fromId != widget.peerId) return;
        if (_rtc == null) {
          final rtc = WebRTCService(widget.signaling, isHost: false);
          rtc.onRemoteStream = (stream) {
            _renderer.srcObject = stream;
            if (mounted) setState(() => _connected = true);
          };
          _rtc = rtc;
          await rtc.prepareViewer(fromId);
        }
        await _rtc!.handleRemoteSignal(data);
        break;
      case PeerLeftEvent(:final peerId):
        if (peerId == widget.peerId) {
          Navigator.of(context).maybePop();
        }
        break;
      default:
        break;
    }
  }

  // host landscape (TV) স্ক্রিন পাঠালে ভিউয়ার ফোনকেও landscape-এ ঘোরার
  // অনুমতি দেওয়া হয়; host portrait (মোবাইল) হলে ফোন portrait-এই লক থাকে।
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

  void _sendTap(double xPercent, double yPercent) {
    _rtc?.sendControlEvent({'type': 'tap', 'x': xPercent, 'y': yPercent});
  }

  void _sendScroll(double xPercent, double yPercent, double deltaY) {
    _rtc?.sendControlEvent(
        {'type': 'scroll', 'x': xPercent, 'y': yPercent, 'deltaY': deltaY});
  }

  void _endSession() {
    widget.signaling.hangup(widget.peerId);
    Navigator.of(context).maybePop();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _sub?.cancel();
    _renderer.dispose();
    _rtc?.dispose(); // শুধু এই সেশনের P2P কানেকশন বন্ধ হয়, signaling খোলাই থাকে
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_connected) {
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
                          icon: Icons.call_end, onTap: _endSession),
                      const SizedBox(width: 8),
                      const Text('Connecting...',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const Spacer(),
                const Center(
                  child: CircularProgressIndicator(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text('Waiting for video from ${widget.peerId}...',
                      style: const TextStyle(color: Colors.white70)),
                ),
                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live View'),
        actions: [
          IconButton(icon: const Icon(Icons.call_end), onPressed: _endSession),
        ],
      ),
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
