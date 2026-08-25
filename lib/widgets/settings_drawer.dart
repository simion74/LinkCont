import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// সেটিংস আইকনে ট্যাপ করলে ডানপাশ থেকে খোলা "সেটিং সাইড কন্টেইনার"।
/// এখানকার প্রতিটা toggle/dropdown SharedPreferences-এ সেভ থাকে, তাই অ্যাপ বন্ধ
/// করে আবার খুললেও শেষ অবস্থাটাই থাকবে। আসল ফাংশনালিটি (যেমন ভয়েস আসলেই
/// পাঠানো, কোয়ালিটি অনুযায়ী বিটরেট বদলানো) সার্ভার/WebRTC-এর কাজের সময় এখান
/// থেকে ভ্যালু পড়ে ব্যবহার করা যাবে — কী গুলো নিচে সব public static রাখা হলো।
class SettingsDrawer extends StatefulWidget {
  final String? deviceId;
  final VoidCallback onCopyId;
  final Future<void> Function() onRegenerateId;

  const SettingsDrawer({
    super.key,
    required this.deviceId,
    required this.onCopyId,
    required this.onRegenerateId,
  });

  // ==== SharedPreferences keys — WebRTC/সার্ভার কোড থেকে পরে এগুলো পড়া হবে ====
  static const keyVoiceShare = 'setting_voice_share';
  static const keyRemoteControlAllowed = 'setting_remote_control_allowed';
  static const keyAskBeforeConnect = 'setting_ask_before_connect';
  static const keyKeepScreenOn = 'setting_keep_screen_on';
  static const keyVideoQuality = 'setting_video_quality'; // 'Low' | 'Medium' | 'High'

  @override
  State<SettingsDrawer> createState() => _SettingsDrawerState();
}

class _SettingsDrawerState extends State<SettingsDrawer> {
  bool _voiceShare = true;
  bool _remoteControlAllowed = true;
  bool _askBeforeConnect = true;
  bool _keepScreenOn = true;
  String _videoQuality = 'High';
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _voiceShare = prefs.getBool(SettingsDrawer.keyVoiceShare) ?? true;
      _remoteControlAllowed =
          prefs.getBool(SettingsDrawer.keyRemoteControlAllowed) ?? true;
      _askBeforeConnect =
          prefs.getBool(SettingsDrawer.keyAskBeforeConnect) ?? true;
      _keepScreenOn = prefs.getBool(SettingsDrawer.keyKeepScreenOn) ?? true;
      _videoQuality =
          prefs.getString(SettingsDrawer.keyVideoQuality) ?? 'High';
      _loaded = true;
    });
  }

  Future<void> _setBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _setString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<void> _confirmRegenerateId() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Generate New ID?'),
        content: const Text(
          'A new ID will replace your current one. Anyone with the old ID '
          'will no longer be able to connect to this device.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Generate')),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.onRegenerateId();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('New ID generated')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.transparent,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              // AppMenuDrawer-এর সাথে মিল রেখে একই ব্র্যান্ড গ্র্যাডিয়েন্ট
              // (গাঢ় নীল → গাঢ় টিল) — একদম কালো না, তাই প্যানেলটা প্রিমিয়াম
              // দেখায় এবং আইকন/লোগোও স্পষ্ট বোঝা যায়।
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF102A52).withOpacity(0.97),
                  const Color(0xFF0B3B33).withOpacity(0.98),
                ],
              ),
              border: Border(
                left: BorderSide(
                    color: Colors.white.withOpacity(0.10), width: 1),
              ),
            ),
            child: !_loaded
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white70))
                : SafeArea(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: [
                        _Header(
                          deviceId: widget.deviceId,
                          onCopyId: widget.onCopyId,
                        ),
                        const _SectionLabel('Sharing'),
                        SwitchListTile(
                          value: _voiceShare,
                          onChanged: (v) {
                            setState(() => _voiceShare = v);
                            _setBool(SettingsDrawer.keyVoiceShare, v);
                          },
                          activeColor: const Color(0xFF3ED67A),
                          secondary: const Icon(Icons.mic_outlined,
                              color: Colors.white70),
                          title: const Text('Share Voice with Screen',
                              style: TextStyle(color: Colors.white)),
                          subtitle: const Text(
                            'Send this device\'s audio while sharing',
                            style: TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ),
                        SwitchListTile(
                          value: _remoteControlAllowed,
                          onChanged: (v) {
                            setState(() => _remoteControlAllowed = v);
                            _setBool(
                                SettingsDrawer.keyRemoteControlAllowed, v);
                          },
                          activeColor: const Color(0xFF3ED67A),
                          secondary: const Icon(Icons.touch_app_outlined,
                              color: Colors.white70),
                          title: const Text('Allow Remote Control',
                              style: TextStyle(color: Colors.white)),
                          subtitle: const Text(
                            'Let the connected device control this screen',
                            style: TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ),
                        ListTile(
                          leading: const Icon(Icons.high_quality_outlined,
                              color: Colors.white70),
                          title: const Text('Video Quality',
                              style: TextStyle(color: Colors.white)),
                          subtitle: const Text(
                            'Higher quality uses more data/battery',
                            style: TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                          trailing: DropdownButton<String>(
                            value: _videoQuality,
                            dropdownColor: const Color(0xFF0B2036),
                            underline: const SizedBox.shrink(),
                            style: const TextStyle(color: Colors.white),
                            items: const ['Low', 'Medium', 'High']
                                .map((q) =>
                                    DropdownMenuItem(value: q, child: Text(q)))
                                .toList(),
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() => _videoQuality = v);
                              _setString(SettingsDrawer.keyVideoQuality, v);
                            },
                          ),
                        ),
                        const Divider(color: Colors.white12, height: 24),
                        const _SectionLabel('Security'),
                        SwitchListTile(
                          value: _askBeforeConnect,
                          onChanged: (v) {
                            setState(() => _askBeforeConnect = v);
                            _setBool(SettingsDrawer.keyAskBeforeConnect, v);
                          },
                          activeColor: const Color(0xFF3ED67A),
                          secondary: const Icon(Icons.verified_user_outlined,
                              color: Colors.white70),
                          title: const Text('Ask Before Each Connection',
                              style: TextStyle(color: Colors.white)),
                          subtitle: const Text(
                            'Show an approval prompt when someone connects',
                            style: TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ),
                        const Divider(color: Colors.white12, height: 24),
                        const _SectionLabel('Device'),
                        SwitchListTile(
                          value: _keepScreenOn,
                          onChanged: (v) {
                            setState(() => _keepScreenOn = v);
                            _setBool(SettingsDrawer.keyKeepScreenOn, v);
                          },
                          activeColor: const Color(0xFF3ED67A),
                          secondary: const Icon(Icons.lightbulb_outline,
                              color: Colors.white70),
                          title: const Text('Keep Screen Awake',
                              style: TextStyle(color: Colors.white)),
                          subtitle: const Text(
                            'Prevent sleep while sharing/receiving',
                            style: TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ),
                        ListTile(
                          leading: const Icon(Icons.refresh,
                              color: Colors.white70),
                          title: const Text('Generate New ID',
                              style: TextStyle(color: Colors.white)),
                          subtitle: const Text(
                            'Replaces your current connection ID',
                            style: TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                          onTap: _confirmRegenerateId,
                        ),
                        const Divider(color: Colors.white12, height: 24),
                        const _SectionLabel('About'),
                        const ListTile(
                          leading:
                              Icon(Icons.info_outline, color: Colors.white70),
                          title: Text('LinkCont',
                              style: TextStyle(color: Colors.white)),
                          subtitle: Text('Version 1.0.0',
                              style: TextStyle(
                                  color: Colors.white54, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String? deviceId;
  final VoidCallback onCopyId;
  const _Header({required this.deviceId, required this.onCopyId});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF3ED67A).withOpacity(0.15),
              border: Border.all(
                  color: const Color(0xFF3ED67A).withOpacity(0.6)),
            ),
            child: const Icon(Icons.settings_outlined,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Settings',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                GestureDetector(
                  onTap: onCopyId,
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          deviceId ?? '—',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.copy_rounded,
                          color: Colors.white38, size: 14),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: Colors.white.withOpacity(0.4),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
