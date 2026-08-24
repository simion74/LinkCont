import 'dart:convert';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'signaling.dart';

/// ভিডিও (স্ক্রিন শেয়ার) এবং রিমোট-কন্ট্রোল ইভেন্ট (DataChannel দিয়ে) দুটোই
/// একই RTCPeerConnection-এর মধ্য দিয়ে সরাসরি P2P যায় — signaling server শুধু
/// শুরুতে হ্যান্ডশেক করিয়ে দেয়, এরপর তার কোনো ভূমিকা থাকে না।
class WebRTCService {
  final SignalingBase signaling;
  final bool isHost;

  RTCPeerConnection? _pc;
  MediaStream? _localScreenStream;
  RTCDataChannel? _controlChannel;

  Function(MediaStream stream)? onRemoteStream; // viewer পাশে ভিডিও দেখানোর জন্য
  Function(Map<String, dynamic> event)? onControlEvent; // host পাশে টাচ/ক্লিক ইভেন্ট পাওয়ার জন্য

  final _config = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'}, // শুধু NAT traversal-এর জন্য, ডেটা এখান দিয়ে যায় না
      // প্রোডাকশনে নিজস্ব TURN সার্ভার যোগ করুন symmetric NAT-এর ক্ষেত্রে fallback হিসেবে
    ],
  };

  WebRTCService(this.signaling, {required this.isHost});

  Future<void> _createPeerConnection() async {
    _pc = await createPeerConnection(_config);

    _pc!.onIceCandidate = (candidate) {
      // ICE candidate signaling দিয়ে পাঠানো হচ্ছে (শুধু নেটওয়ার্ক ঠিকানা, ভিডিও ডেটা না)
      signaling.sendSignal(_remotePeerId ?? '', {
        'candidate': candidate.toMap(),
      });
    };

    _pc!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        onRemoteStream?.call(event.streams.first);
      }
    };

    _pc!.onDataChannel = (channel) {
      _controlChannel = channel;
      _bindControlChannel();
    };
  }

  String? _remotePeerId;

  // ---------- HOST পাশ: স্ক্রিন ক্যাপচার শুরু করে অফার পাঠায় ----------
  Future<void> startHosting(String viewerId) async {
    _remotePeerId = viewerId;
    await _createPeerConnection();

    // MediaProjection permission Android-এ আগেই নেওয়া থাকতে হবে (native প্রম্পট)
    _localScreenStream = await navigator.mediaDevices.getDisplayMedia({
      'video': true,
      'audio': false,
    });
    for (var track in _localScreenStream!.getTracks()) {
      _pc!.addTrack(track, _localScreenStream!);
    }

    // রিমোট কন্ট্রোল কমান্ড পাওয়ার জন্য DataChannel (host নিজে খোলে)
    _controlChannel = await _pc!.createDataChannel(
      'control',
      RTCDataChannelInit()..ordered = true,
    );
    _bindControlChannel();

    final offer = await _pc!.createOffer();
    await _pc!.setLocalDescription(offer);
    signaling.sendSignal(viewerId, {'sdp': offer.toMap()});
  }

  // ---------- VIEWER পাশ: অফার রিসিভ করে আনসার পাঠায় ----------
  Future<void> prepareViewer(String hostId) async {
    _remotePeerId = hostId;
    await _createPeerConnection();
  }

  Future<void> handleRemoteSignal(Map<String, dynamic> data) async {
    if (data.containsKey('sdp')) {
      final sdpMap = data['sdp'];
      final desc = RTCSessionDescription(sdpMap['sdp'], sdpMap['type']);
      await _pc!.setRemoteDescription(desc);

      if (!isHost && sdpMap['type'] == 'offer') {
        final answer = await _pc!.createAnswer();
        await _pc!.setLocalDescription(answer);
        signaling.sendSignal(_remotePeerId!, {'sdp': answer.toMap()});
      }
    } else if (data.containsKey('candidate')) {
      final c = data['candidate'];
      await _pc!.addCandidate(
        RTCIceCandidate(c['candidate'], c['sdpMid'], c['sdpMLineIndex']),
      );
    }
  }

  void _bindControlChannel() {
    _controlChannel?.onMessage = (message) {
      final event = jsonDecode(message.text) as Map<String, dynamic>;
      onControlEvent?.call(event); // host পাশে → AccessibilityService-কে ফরওয়ার্ড হবে
    };
  }

  /// viewer পাশ থেকে টাচ/ক্লিক/স্ক্রল ইভেন্ট পাঠানো — সরাসরি P2P DataChannel দিয়ে
  void sendControlEvent(Map<String, dynamic> event) {
    if (_controlChannel?.state == RTCDataChannelState.RTCDataChannelOpen) {
      _controlChannel!.send(RTCDataChannelMessage(jsonEncode(event)));
    }
  }

  Future<void> dispose() async {
    await _localScreenStream?.dispose();
    await _controlChannel?.close();
    await _pc?.close();
  }
}
