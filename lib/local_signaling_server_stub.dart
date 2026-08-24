import 'signaling.dart';

/// ওয়েব প্ল্যাটফর্মে dart:io নেই, তাই এই স্টাব ব্যবহার হয় (শুধু ডিজাইন/UI
/// প্রিভিউয়ের জন্য — যেমন GitHub Pages)। Android/Windows বিল্ডে আসল
/// local_signaling_server_io.dart ব্যবহার হয় (dart:io দিয়ে, পুরোপুরি কাজ করে) —
/// কোনটা কখন ব্যবহার হবে তা local_signaling_server.dart-এর conditional
/// export ঠিক করে দেয়, main.dart-এ কিছু বদলাতে হয় না।
class LocalSignalingServer implements SignalingBase {
  static const int defaultPort = 8089;
  final int port;

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

  Future<List<String>> start() async {
    throw UnsupportedError(
        'Local Network (IP) mode এই web প্রিভিউতে কাজ করে না — শুধু Android/Windows বিল্ডে কাজ করবে।');
  }

  @override
  void sendSignal(String targetId, Map<String, dynamic> data) {}

  @override
  void dispose() {}
}
