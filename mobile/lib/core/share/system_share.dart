/// The device's own share sheet (WhatsApp, Instagram, Facebook, …), picked per platform at
/// compile time.
///
/// No share package: the web build calls the browser's Web Share API through `dart:js_interop`, and
/// the Android build asks `MainActivity` for Android's chooser over a method channel. Same pattern
/// as `core/payments/razorpay_checkout.dart`. Both sides expose the same `SystemShare.share`.
library;

export 'package:zuno/core/share/share_outcome.dart';
export 'package:zuno/core/share/system_share_native.dart'
    if (dart.library.js_interop) 'package:zuno/core/share/system_share_web.dart';
