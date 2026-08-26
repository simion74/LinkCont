import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

/// ============================================================
/// নতুন কল-স্টাইল signaling প্রোটোকল (v2)
/// ============================================================
/// আগের ভার্সনে "Host" আর "Viewer" আলাদা স্ক্রিন থেকে আলাদা করে
/// রুম-কোড দিয়ে জয়েন করত, আর একই WiFi/LAN-এ সরাসরি IP দিয়েও কানেক্ট
/// করা যেত। এখন দুটোই বাদ — শুধু একটাই মোড:
///
///   ১. প্রতিটা ডিভাইস চালু হলেই তার স্থায়ী ID দিয়ে সার্ভারে "register" হয়।
///   ২. A, B-এর ID এন্টার করে "call-request" পাঠায় (মানে A, B-এর স্ক্রিন
///      দেখতে/কন্ট্রোল করতে চায়)।
///   ৩. B-এর ডিভাইসে একটা প্রম্পট আসে — allow করলে B "call-response"
///      (accepted: true) পাঠায়, তখন B হোস্ট (স্ক্রিন শেয়ার করবে) হয়ে যায়
///      আর A ভিউয়ার (দেখবে/কন্ট্রোল করবে) হয়ে যায়। কে হোস্ট/ভিউয়ার হবে
///      এটা আগে থেকে বেছে নিতে হয় না — কে অনুরোধ করল আর কে allow করল
///      তার উপর自動ভাবে ঠিক হয়ে যায়।
///   ৪. এরপর স্বাভাবিক SDP/ICE signal আদান-প্রদান হয়ে P2P কানেকশন হয়।
///
/// ⚠️ এই ফাইলটা শুধু ক্লায়েন্ট পাশ। আসল signaling সার্ভার (WebSocket)
/// এখনো বসানো হয়নি — নিচের প্রতিটা মেসেজ-টাইপ যেভাবে পাঠানো/প্রত্যাশিত,
/// সার্ভার বানানোর সময় ঠিক এই কনট্র্যাক্টটাই মানতে হবে। পুরো প্রোটোকল
/// স্পেসিফিকেশন রিপোর রুটে PROTOCOL.md ফাইলে লেখা আছে।

/// সার্ভার থেকে আসা প্রতিটা ইভেন্ট এই sealed-স্টাইল ক্লাস হায়ারার্কি দিয়ে
/// রিপ্রেজেন্ট করা হয় — একটা broadcast Stream-এ আসে, তাই একই সময়ে
/// একাধিক জায়গা (যেমন HomeScreen সবসময়, আর একটা সক্রিয় সেশন স্ক্রিন)
/// আলাদাভাবে শুনতে পারে, কেউ কারো callback মুছে ফেলে না।
sealed class SignalingEvent {
  const SignalingEvent();
}

/// সার্ভারের সাথে সফলভাবে register হয়েছে (নিজের ID acknowledge হয়েছে)
class RegisteredEvent extends SignalingEvent {
  const RegisteredEvent();
}

/// অন্য একটা ডিভাইস (fromId) আমার স্ক্রিন দেখতে/কন্ট্রোল করতে চায় —
/// UI-তে "Allow করবেন?" প্রম্পট দেখাতে হবে
class IncomingRequestEvent extends SignalingEvent {
  final String fromId;
  const IncomingRequestEvent(this.fromId);
}

/// আমি যাকে (fromId) রিকোয়েস্ট পাঠিয়েছিলাম, সে allow করেছে —
/// এখন আমি ভিউয়ার হিসেবে কানেক্ট হবো
class RequestAcceptedEvent extends SignalingEvent {
  final String fromId;
  const RequestAcceptedEvent(this.fromId);
}

/// আমি যাকে রিকোয়েস্ট পাঠিয়েছিলাম, সে reject করেছে
class RequestRejectedEvent extends SignalingEvent {
  final String fromId;
  const RequestRejectedEvent(this.fromId);
}

/// যে ID-তে রিকোয়েস্ট পাঠানো হয়েছিল, সেই ID সার্ভারে online/registered পাওয়া যায়নি
class PeerOfflineEvent extends SignalingEvent {
  final String targetId;
  const PeerOfflineEvent(this.targetId);
}

/// SDP/ICE signaling ডেটা — WebRTCService এটা ধরে P2P হ্যান্ডশেক করে
class SignalDataEvent extends SignalingEvent {
  final String fromId;
  final Map<String, dynamic> data;
  const SignalDataEvent(this.fromId, this.data);
}

/// চলমান সেশনের অপর প্রান্ত ডিসকানেক্ট/hangup করেছে
class PeerLeftEvent extends SignalingEvent {
  final String peerId;
  const PeerLeftEvent(this.peerId);
}

class SignalingErrorEvent extends SignalingEvent {
  final String message;
  const SignalingErrorEvent(this.message);
}

/// পুরো অ্যাপ চলাকালীন এই ক্লাসের একটাই instance বেঁচে থাকে (HomeScreen
/// তৈরি করে, session স্ক্রিনগুলো ধার নেয়) — যাতে ইনকামিং রিকোয়েস্ট
/// সবসময়, যেকোনো স্ক্রিনে থাকা অবস্থাতেই ধরা যায়।
class SignalingClient {
  final String serverUrl;
  WebSocketChannel? _channel;
  String? _myId;

  final _controller = StreamController<SignalingEvent>.broadcast();
  Stream<SignalingEvent> get events => _controller.stream;

  bool get isConnected => _channel != null;

  SignalingClient(this.serverUrl);

  /// সার্ভারে কানেক্ট করে নিজের স্থায়ী ID দিয়ে register করে
  void connect(String myId) {
    _myId = myId;
    _channel = WebSocketChannel.connect(Uri.parse(serverUrl));
    _channel!.stream.listen(
      (raw) => _handleRaw(raw as String),
      onError: (e) => _controller.add(SignalingErrorEvent(e.toString())),
      onDone: () =>
          _controller.add(const SignalingErrorEvent('Disconnected')),
    );
    _send({'type': 'register', 'id': myId});
  }

  void _handleRaw(String raw) {
    final Map<String, dynamic> msg;
    try {
      msg = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return; // ভাঙা/অপ্রত্যাশিত মেসেজ চুপচাপ উপেক্ষা করা হচ্ছে
    }
    switch (msg['type']) {
      case 'registered':
        _controller.add(const RegisteredEvent());
        break;
      case 'incoming-request':
        _controller.add(IncomingRequestEvent(msg['fromId'] as String));
        break;
      case 'request-accepted':
        _controller.add(RequestAcceptedEvent(msg['fromId'] as String));
        break;
      case 'request-rejected':
        _controller.add(RequestRejectedEvent(msg['fromId'] as String));
        break;
      case 'peer-offline':
        _controller.add(PeerOfflineEvent(msg['targetId'] as String));
        break;
      case 'signal':
        _controller.add(SignalDataEvent(
          msg['from'] as String,
          Map<String, dynamic>.from(msg['data'] as Map),
        ));
        break;
      case 'peer-left':
        _controller.add(PeerLeftEvent(msg['peerId'] as String));
        break;
      case 'error':
        _controller.add(SignalingErrorEvent(msg['message'] as String));
        break;
    }
  }

  /// targetId-র স্ক্রিন দেখতে/কন্ট্রোল করতে চাই — অনুরোধ পাঠানো
  void requestCall(String targetId) {
    _send({'type': 'call-request', 'targetId': targetId});
  }

  /// আমাকে কেউ (fromId) রিকোয়েস্ট পাঠিয়েছিল — allow/reject জানানো
  void respondToRequest(String fromId, bool accepted) {
    _send({
      'type': 'call-response',
      'targetId': fromId,
      'accepted': accepted,
    });
  }

  void sendSignal(String targetId, Map<String, dynamic> data) {
    _send({'type': 'signal', 'targetId': targetId, 'data': data});
  }

  /// চলমান সেশন শেষ করা (দুই পাশ থেকেই কল করা যায়)
  void hangup(String targetId) {
    _send({'type': 'hangup', 'targetId': targetId});
  }

  void _send(Map<String, dynamic> obj) {
    _channel?.sink.add(jsonEncode(obj));
  }

  void dispose() {
    if (_myId != null) {
      // সার্ভারকে জানিয়ে দেওয়া হচ্ছে যাতে সে সাথে সাথে registry থেকে
      // এই ID সরিয়ে ফেলে (সার্ভার সংযোগ ছিন্ন হলে টাইমআউট দিয়েও ধরতে
      // পারে, কিন্তু explicit বার্তা পেলে দ্রুত হয়)
      _send({'type': 'unregister', 'id': _myId});
    }
    _channel?.sink.close();
    _controller.close();
  }
}
