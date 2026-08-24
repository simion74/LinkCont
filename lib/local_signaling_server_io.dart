import 'dart:convert';
import 'dart:io';
import 'signaling.dart';

/// একই WiFi/LAN নেটওয়ার্কে (বাসা/অফিস রাউটার) থাকা দুটো ডিভাইসকে ইন্টারনেট
/// signaling সার্ভার ছাড়াই সরাসরি IP দিয়ে কানেক্ট করানোর জন্য।
///
/// Host ডিভাইসটাই একটা ছোট WebSocket সার্ভার চালায় (dart:io দিয়ে — কোনো
/// এক্সট্রা প্যাকেজ লাগে না, Android আর Windows দুই জায়গাতেই কাজ করে)।
/// Viewer ডিভাইস স্বাভাবিক SignalingClient দিয়েই ws://<host-ip>:<port> এ
/// কানেক্ট করে — viewer পাশে কোনো নতুন কোড লাগে না, শুধু URL-টা কেন্দ্রীয়
/// সার্ভারের বদলে host-এর IP হয় (main.dart-এর ViewerScreen দ্রষ্টব্য)।
///
/// প্রোটোকল signaling.dart-এর SignalingClient-এর সাথে সামঞ্জস্যপূর্ণ
/// (join-room / signal), যাতে WebRTCService-এর কোনো কোড না বদলেই দুই মোডেই
/// (ইন্টারনেট আইডি বা লোকাল আইপি) অভিন্নভাবে কাজ করে।
///
/// সীমাবদ্ধতা: একসাথে একজন viewer-ই সাপোর্ট করা হচ্ছে (direct 1:1 কানেকশনের
/// জন্য এটাই স্বাভাবিক — AnyDesk/TeamViewer-এর LAN মোডও এভাবেই কাজ করে)।
class LocalSignalingServer implements SignalingBase {
  static const int defaultPort = 8089;

  final int port;
  HttpServer? _server;
  WebSocket? _viewerSocket;

  @override
  Function(String roomCode)? onRoomCreated;
  @override
  Function(String viewerId)? onViewerJoined;
  @override
  Function(String fromId, Map<String, dynamic> data)? onSignal;
  @override
  Function(String message)? onError;
  @override
  Function()? onHostLeft;

  LocalSignalingServer({this.port = defaultPort});

  /// সার্ভার চালু করে, এবং এই ডিভাইসের LAN IPv4 ঠিকানাগুলো রিটার্ন করে
  /// (একাধিক নেটওয়ার্ক ইন্টারফেস — যেমন WiFi + ইথারনেট — থাকলে সবগুলো;
  /// ব্যবহারকারী তার নেটওয়ার্কের জন্য সঠিকটা বেছে নেবে)।
  Future<List<String>> start() async {
    _server = await HttpServer.bind(InternetAddress.anyIPv4, port);

    _server!.listen((request) async {
      if (WebSocketTransformer.isUpgradeRequest(request)) {
        final socket = await WebSocketTransformer.upgrade(request);
        // একসাথে একজন viewer-ই সাপোর্ট করা হচ্ছে — নতুন কেউ কানেক্ট করলে
        // আগেরটা বন্ধ হয়ে যায়
        _viewerSocket?.close();
        _viewerSocket = socket;
        socket.listen(
          (raw) => _handleMessage(raw as String),
          onDone: () => onHostLeft?.call(),
          onError: (_) => onError?.call('Connection error'),
        );
      } else {
        request.response.statusCode = HttpStatus.forbidden;
        await request.response.close();
      }
    }, onError: (_) => onError?.call('Local server error'));

    return _localIPv4Addresses();
  }

  void _handleMessage(String raw) {
    try {
      final msg = jsonDecode(raw) as Map<String, dynamic>;
      switch (msg['type']) {
        case 'join-room':
          // IP মোডে room code-এর কোনো মানে নেই — কানেকশনটাই যথেষ্ট
          onViewerJoined?.call('viewer');
          break;
        case 'signal':
          onSignal?.call('viewer', msg['data'] as Map<String, dynamic>);
          break;
      }
    } catch (_) {
      // malformed frame — চুপচাপ ইগনোর করা হচ্ছে, কানেকশন বন্ধ করার দরকার নেই
    }
  }

  @override
  void sendSignal(String targetId, Map<String, dynamic> data) {
    _viewerSocket
        ?.add(jsonEncode({'type': 'signal', 'from': 'host', 'data': data}));
  }

  Future<List<String>> _localIPv4Addresses() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      return interfaces
          .expand((i) => i.addresses)
          .map((a) => a.address)
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  void dispose() {
    _viewerSocket?.close();
    _server?.close(force: true);
  }
}
