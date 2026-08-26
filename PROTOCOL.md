# LinkCont Signaling Protocol (v2 — call/accept model)

এই ফাইলটা signaling সার্ভার বানানোর সময় রেফারেন্স হিসেবে ব্যবহার করুন।
ক্লায়েন্ট (Flutter অ্যাপ) এই মেসেজ-ফরম্যাট অনুযায়ী তৈরি — সার্ভারকে ঠিক
এটাই মানতে হবে।

- ট্রান্সপোর্ট: প্লেইন WebSocket (`wss://...`), প্রতিটা মেসেজ একটা JSON
  object, `type` ফিল্ড দিয়ে identify হয়।
- সার্ভারের কাজ শুধু: (ক) কে কোন ID দিয়ে কানেক্টেড আছে তার রেজিস্ট্রি
  রাখা, (খ) call-request/response রিলে করা, (গ) SDP/ICE signal রিলে
  করা। আসল ভিডিও/কন্ট্রোল ডেটা সার্ভারের মধ্য দিয়ে যায় না (WebRTC P2P)।
- প্রতিটা ডিভাইস একবারে একটাই WebSocket কানেকশন রাখে, যেটা অ্যাপ
  foreground-এ থাকা অবস্থায় খোলা থাকে (এই ভার্সনে অ্যাপ বন্ধ থাকা অবস্থায়
  push notification নেই — ভবিষ্যতে FCM যোগ হলে সার্ভার থেকে একই
  `incoming-request` তথ্য push দিয়েও পাঠানো যাবে)।

## ক্লায়েন্ট → সার্ভার

| type | ফিল্ড | অর্থ |
|---|---|---|
| `register` | `id` | কানেক্ট হওয়ার সাথে সাথেই পাঠায় — এই WebSocket-কে ওই `id`-এর সাথে ম্যাপ করে রাখতে হবে |
| `unregister` | `id` | অ্যাপ বন্ধ/dispose হওয়ার সময় পাঠায় — সার্ভার তখনই রেজিস্ট্রি থেকে সরিয়ে দিতে পারে (নাহলে WebSocket ডিসকানেক্ট হলেও সরাতে হবে) |
| `call-request` | `targetId` | আমি `targetId`-র স্ক্রিন দেখতে/কন্ট্রোল করতে চাই |
| `call-response` | `targetId`, `accepted` (bool) | `targetId`-র পাঠানো রিকোয়েস্টের জবাব |
| `signal` | `targetId`, `data` | SDP/ICE payload — অপরিবর্তিত `targetId`-কে ফরওয়ার্ড করতে হবে |
| `hangup` | `targetId` | চলমান সেশন শেষ করা হচ্ছে |

## সার্ভার → ক্লায়েন্ট

| type | ফিল্ড | কখন পাঠাতে হবে |
|---|---|---|
| `registered` | — | `register` সফল হলে (ঐচ্ছিক, ক্লায়েন্ট এখনো ব্যবহার করে না) |
| `incoming-request` | `fromId` | কেউ (`fromId`) এই ডিভাইসকে `call-request` পাঠালে |
| `request-accepted` | `fromId` | `fromId` যাকে রিকোয়েস্ট পাঠিয়েছিল, সে accept করলে — requester-কে পাঠাতে হবে |
| `request-rejected` | `fromId` | ওই একই কেস কিন্তু reject করলে |
| `peer-offline` | `targetId` | `call-request`-এর `targetId` রেজিস্ট্রিতে না পাওয়া গেলে (requester-কে জানাতে হবে) |
| `signal` | `from`, `data` | কেউ আমাকে `signal` পাঠালে, sender-এর id সহ ফরওয়ার্ড |
| `peer-left` | `peerId` | চলমান সেশনের অপরপক্ষ `hangup` পাঠালে বা তার WebSocket ডিসকানেক্ট হয়ে গেলে |
| `error` | `message` | যেকোনো এরর অবস্থায় |

## টিপিক্যাল ফ্লো

```
A (requester)                 Server                  B (accepter → host)
     |--- register(A) -------->|
     |                          |<------- register(B) ---|
     |--- call-request(B) ---->|
     |                          |--- incoming-request(A) ->|
     |                          |                          | (ইউজার Allow চাপল)
     |                          |<---- call-response(B accepted:true) --|
     |<-- request-accepted(B) --|
     |                          |
     |   (এখন B হোস্ট, A ভিউয়ার — দুই পাশই স্বাধীনভাবে WebRTCService শুরু করে)
     |                          |
     |                          |<---- signal(B→A, offer sdp) ----------|
     |<---- signal(from B) -----|
     |--- signal(A→B, answer sdp) ->|
     |                          |---- signal(from A) ------------------>|
     |          ... ICE candidates একইভাবে উভয় দিকে যায় ...
     |                          |
     |--- hangup(B) ----------->|
     |                          |---- peer-left(A) --------------------->|
```

## ভবিষ্যতে যোগ করার মতো জিনিস (এখন দরকার নেই)

- **FCM push**: অ্যাপ বন্ধ/background থাকলেও `incoming-request` পেতে হলে,
  সার্ভারকে প্রতিটা registered `id`-র সাথে একটা FCM device token-ও রাখতে
  হবে, আর WebSocket-এ কেউ কানেক্টেড না থাকলে সেই টোকেনে push পাঠাতে হবে
  (payload একই `incoming-request` তথ্য বহন করবে, অ্যাপ খুলে সরাসরি সেই
  ডায়ালগ দেখাবে)।
- **Rate limiting / abuse প্রতিরোধ**: যেকোনো ID র‍্যান্ডম গেস করে বারবার
  `call-request` পাঠানো ঠেকাতে, প্রতি ID-তে সীমিত সংখ্যক রিকোয়েস্ট/মিনিট।
- **TURN সার্ভার**: symmetric NAT-এর পেছনে থাকা ডিভাইসের জন্য STUN
  যথেষ্ট না হলে, `webrtc_service.dart`-এর `iceServers` লিস্টে নিজস্ব TURN
  সার্ভার যোগ করতে হবে (এটা signaling সার্ভারের অংশ না, আলাদা ব্যাপার)।
