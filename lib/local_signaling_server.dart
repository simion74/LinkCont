/// Android/Windows-এ dart:io আছে, তাই আসল LocalSignalingServer
/// (local_signaling_server_io.dart) ব্যবহার হয়। ওয়েবে dart:io নেই, তাই
/// local_signaling_server_stub.dart ব্যবহার হয় — যাতে শুধু UI প্রিভিউয়ের
/// জন্য (GitHub Pages ইত্যাদি) web build compile করা যায়।
export 'local_signaling_server_stub.dart'
    if (dart.library.io) 'local_signaling_server_io.dart';
