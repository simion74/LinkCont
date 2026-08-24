# Remote Screen

মোবাইল ⇄ ট্যাব ⇄ Android TV ⇄ কম্পিউটার — একই অ্যাপ দিয়ে স্ক্রিন শেয়ার, ভয়েস, আর রিমোট কন্ট্রোল।

## প্রজেক্ট গঠন

- `lib/` — মূল Flutter/Dart কোড
- `android/` — সব Android টার্গেট (মোবাইল, ট্যাব, Android TV) — একটাই APK
- `windows/` — Windows ডেস্কটপ বিল্ড
- `ios/` — ফাইল রাখা আছে যাতে এরর না হয়, কিন্তু এখন বিল্ড/টেস্ট করা হচ্ছে না
- `.github/workflows/build.yml` — GitHub Actions: প্রতি push-এ APK + Windows exe অটো-বিল্ড হয়

## লোকাল বিল্ড

```bash
flutter pub get

# Android
flutter build apk --release
# আউটপুট: build/app/outputs/flutter-apk/app-release.apk

# Windows (Windows মেশিনে চালাতে হবে)
flutter config --enable-windows-desktop
flutter build windows --release
# আউটপুট: build/windows/x64/runner/Release/
```

## GitHub Actions (CI)

`main` ব্রাঞ্চে push করলেই `.github/workflows/build.yml` অটোমেটিক দুটো বিল্ড চালায়:
- **Android APK** — ubuntu-latest রানারে
- **Windows EXE** — windows-latest রানারে

বিল্ড শেষে GitHub-এর Actions ট্যাব থেকে "Artifacts" সেকশনে গিয়ে দুটোই ডাউনলোড করা যাবে।

`v1.0.0`-এর মতো একটা ট্যাগ push করলে (`git tag v1.0.0 && git push origin v1.0.0`),
দুটো বিল্ডই স্বয়ংক্রিয়ভাবে একটা GitHub Release-এ অ্যাটাচ হয়ে যাবে — তখন আর
Artifacts খুঁজতে হবে না, সরাসরি Release পেজ থেকে ডাউনলোড লিংক পাওয়া যাবে।

## কানেকশন মোড

দুইভাবে কানেক্ট করা যায় (Host আর Viewer দুই স্ক্রিনেই টগল আছে):

1. **Internet (ID)** — এখনো signaling সার্ভার বসানো হয়নি; `lib/main.dart`-এর
   `kSignalingUrl` কনস্ট্যান্টে আসল সার্ভার URL বসালেই কাজ করবে।
2. **Local Network (IP)** — একই WiFi/LAN-এ থাকা দুটো ডিভাইস, কোনো ইন্টারনেট
   signaling সার্ভার ছাড়াই সরাসরি IP দিয়ে কানেক্ট হয় (`lib/local_signaling_server.dart`)।
   এটা এখনই কাজ করে — অফিস/কর্পোরেট LAN-এ টেস্ট করা যাবে।

## ডিজাইন/UI প্রিভিউ (GitHub Pages)

শুধু UI/লেআউট দেখে সংশোধনের প্রয়োজন আছে কি না যাচাই করার জন্য — কোড push
করলেই একটা শেয়ারযোগ্য ব্রাউজার লিংকে দেখা যাবে।

**একবার চালু করতে হবে:** GitHub রিপোর **Settings → Pages → Source** থেকে
**"GitHub Actions"** বেছে নিন (একবারই করতে হবে)।

এরপর `main` ব্রাঞ্চে push করলেই `.github/workflows/deploy-web-preview.yml`
অটোমেটিক `flutter build web` চালিয়ে **`https://<আপনার-ইউজারনেম>.github.io/<রিপোর-নাম>/`**
লিংকে ডিপ্লয় করে দেবে। লিংকটা GitHub-এর **Settings → Pages** পেজেও, এবং
Actions ট্যাবের রান-এর "Summary"-তেও পাওয়া যাবে।

⚠️ **এটা শুধু দেখার জন্য (view-only), সরাসরি এডিটের জন্য না।** স্ক্রিন-শেয়ার/
রিমোট-কন্ট্রোল ফিচার এখানে কাজ করবে না (accessibility control Android-only,
LAN IP মোডও dart:io-নির্ভর — ওয়েবে নেই), শুধু Home/Host/Viewer স্ক্রিনের
লেআউট, ব্যাকগ্রাউন্ড, বাটন, ড্রয়ার — এগুলো দেখা যাবে, রেসপন্সিভনেস টেস্ট করা
যাবে (ব্রাউজার সাইজ বদলে মোবাইল/ট্যাব/টিভি লেআউট)।

**সরাসরি এডিট করতে করতে দেখতে চাইলে** (হট রিলোড সহ):
```bash
flutter config --enable-web
flutter run -d chrome
```



- ইন্টারনেট signaling সার্ভার (WebRTC + STUN/TURN + Firebase বা নিজস্ব ব্যাকএন্ড)
- Play Store-এর জন্য আসল release keystore (এখন debug key দিয়ে সাইন হচ্ছে)
- আসল app launcher icon (এখন `assets/image/desing_icon.webp`-এর একটা অংশ
  বসানো আছে placeholder হিসেবে)
- Android TV 320×180 banner ছবি (এখন `ic_launcher`-ই ব্যবহার হচ্ছে fallback হিসেবে)
