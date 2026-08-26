# LinkCont

মোবাইল ⇄ ট্যাব ⇄ Android TV — একই অ্যাপ দিয়ে স্ক্রিন শেয়ার, ভয়েস, আর রিমোট কন্ট্রোল, শুধু Android ডিভাইসের মধ্যে।

## প্রজেক্ট গঠন

- `lib/` — মূল Flutter/Dart কোড
- `android/` — সব Android টার্গেট (মোবাইল, ট্যাব, Android TV) — একটাই APK
- `ios/` — ফাইল রাখা আছে যাতে এরর না হয়, কিন্তু বিল্ড/টেস্ট করা হচ্ছে না
- `.github/workflows/build.yml` — GitHub Actions: প্রতি push-এ APK অটো-বিল্ড হয়
- `PROTOCOL.md` — signaling সার্ভার বানানোর সময় যে মেসেজ-কনট্র্যাক্ট মানতে হবে তার স্পেসিফিকেশন

⚠️ Windows/ডেস্কটপ সাপোর্ট বাদ দেওয়া হয়েছে — শুধু Android (মোবাইল/ট্যাব/TV)।

## কানেকশন মডেল (call/accept — কোনো fixed Host/Viewer নেই)

আগে আলাদা "Share Screen (Host)" আর "Screen View" বাটন থেকে আগে থেকেই ভূমিকা
বেছে নিতে হতো। এখন একটাই ফ্লো:

1. প্রতিটা ডিভাইসের একটা স্থায়ী ৯-ডিজিট ID আছে (হোম স্ক্রিনে দেখা যায়, কপি/শেয়ার করা যায়)।
2. A, B-এর ID টাইপ করে **Connect** চাপে — এটা একটা "রিকোয়েস্ট" পাঠায়, B-কে এখনো
   হোস্ট মোডে থাকতে হয় না।
3. B-এর ফোনে একটা ডায়ালগ আসে: *"Device A wants to view and control your screen. Allow?"*
4. B **Allow** করলে — B স্বয়ংক্রিয়ভাবে হোস্ট (স্ক্রিন শেয়ার করে) হয়ে যায়,
   A স্বয়ংক্রিয়ভাবে ভিউয়ার (দেখে/কন্ট্রোল করে) হয়ে যায়। **Decline** করলে A-কে জানানো হয়।

কে হোস্ট আর কে ভিউয়ার হবে তা আগে থেকে ঠিক করার দরকার নেই — কে রিকোয়েস্ট
পাঠাল আর কে allow করল তার উপর ভিত্তি করে রোল স্বয়ংক্রিয়ভাবে ঠিক হয়।

শুধু ID (ইন্টারনেট) দিয়ে কানেক্ট হয় — LAN/IP মোড বাদ দেওয়া হয়েছে।

### ⚠️ signaling সার্ভার এখনো নেই

`lib/main.dart`-এর `kSignalingUrl` কনস্ট্যান্ট এখনো একটা placeholder। ক্লায়েন্ট
কোড (call-request/accept, SDP/ICE রিলে) পুরোপুরি রেডি — আসল WebSocket
signaling সার্ভার (Node.js/Python/যেকোনো কিছু) বানিয়ে `kSignalingUrl`-এ URL
বসালেই সব কাজ শুরু করবে। সার্ভার ঠিক কী মেসেজ-ফরম্যাট পাঠাবে/পাবে তার
সম্পূর্ণ স্পেসিফিকেশন **`PROTOCOL.md`**-এ আছে।

এই ভার্সনে দুই পক্ষেরই অ্যাপ foreground-এ (খোলা) থাকতে হবে ইনকামিং রিকোয়েস্ট
পেতে — অ্যাপ বন্ধ/background অবস্থায় push notification দিয়ে রিকোয়েস্ট পাওয়া
পরবর্তী ধাপ (Firebase Cloud Messaging লাগবে, `PROTOCOL.md`-এর শেষে নোট আছে)।

## লোকাল বিল্ড

```bash
flutter pub get
flutter build apk --release
# আউটপুট: build/app/outputs/flutter-apk/app-release.apk
```

## GitHub Actions (CI)

`main` ব্রাঞ্চে push করলেই `.github/workflows/build.yml` অটোমেটিক APK বিল্ড করে।
বিল্ড শেষে GitHub-এর Actions ট্যাব থেকে "Artifacts" সেকশনে গিয়ে ডাউনলোড করা যাবে।

`v1.0.0`-এর মতো একটা ট্যাগ push করলে (`git tag v1.0.0 && git push origin v1.0.0`),
APK স্বয়ংক্রিয়ভাবে একটা GitHub Release-এ অ্যাটাচ হয়ে যাবে।

## এখনো বাকি যা আছে

- **ইন্টারনেট signaling সার্ভার** (দেখুন `PROTOCOL.md`)
- Play Store-এর জন্য আসল release keystore (এখন একটা স্থির debug key দিয়ে সাইন হচ্ছে, যাতে প্রতিটা CI বিল্ড একই সিগনেচারে থাকে)
- আসল app launcher icon (এখন `assets/image/icon.webp`-ই ব্যবহার হচ্ছে)
- Android TV 320×180 banner ছবি (এখন `ic_launcher`-ই ব্যবহার হচ্ছে fallback হিসেবে)
