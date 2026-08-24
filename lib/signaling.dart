import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

/// WebRTCService শুধু এই ইন্টারফেসটাই চেনে — signaling ইন্টারনেটের কেন্দ্রীয়
/// সার্ভার (SignalingClient) দিয়ে হোক বা লোকাল নেটওয়ার্কের সরাসরি IP
/// (LocalSignalingServer, দেখুন local_signaling_server.dart) দিয়ে হোক,
/// WebRTCService-এর কোনো কোড না বদলেই দুটোই কাজ করে।
abstract class SignalingBase {
  Function(String roomCode)? onRoomCreated;
  Function(String viewerId)? onViewerJoined;
  Function(String fromId, Map<String, dynamic> data)? onSignal;
  Function(String message)? onError;
  Function()? onHostLeft;

  void sendSignal(String targetId, Map<String, dynamic> data);
  void dispose();
}

/// শুধু signaling (SDP/ICE হ্যান্ডশেক) হ্যান্ডল করে — ইন্টারনেটের কেন্দ্রীয়
/// signaling সার্ভারের সাথে (আইডি দিয়ে কানেক্ট করার সময়)।
/// আসল ভিডিও/কন্ট্রোল ডেটা এই ক্লাসের মধ্য দিয়ে যায় না — সেটা webrtc_service.dart-এ P2P চ্যানেলে যায়।
class SignalingClient implements SignalingBase {
  final String serverUrl; // যেমন: wss://your-signaling-server.example.com
  WebSocketChannel? _channel;

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

  SignalingClient(this.serverUrl);

  void connect() {
    _channel = WebSocketChannel.connect(Uri.parse(serverUrl));
    _channel!.stream.listen((raw) {
      final msg = jsonDecode(raw as String) as Map<String, dynamic>;
      switch (msg['type']) {
        case 'room-created':
          onRoomCreated?.call(msg['roomCode']);
          break;
        case 'viewer-joined':
          onViewerJoined?.call(msg['viewerId']);
          break;
        case 'signal':
          onSignal?.call(msg['from'], msg['data']);
          break;
        case 'error':
          onError?.call(msg['message']);
          break;
        case 'host-left':
          onHostLeft?.call();
          break;
      }
    });
  }

  void createRoom(String roomCode) {
    _send({'type': 'create-room', 'roomCode': roomCode});
  }

  void joinRoom(String roomCode) {
    _send({'type': 'join-room', 'roomCode': roomCode});
  }

  @override
  void sendSignal(String targetId, Map<String, dynamic> data) {
    _send({'type': 'signal', 'targetId': targetId, 'data': data});
  }

  void _send(Map<String, dynamic> obj) {
    _channel?.sink.add(jsonEncode(obj));
  }

  @override
  void dispose() {
    _channel?.sink.close();
  }
}
