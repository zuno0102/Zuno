/// Razorpay Checkout, picked per platform at compile time.
///
/// Razorpay ships two SDKs and neither spans both worlds: `razorpay_flutter` is Android and
/// iOS only, and the JavaScript SDK needs `dart:js_interop`, which exists only on the web.
/// Importing either directly breaks the other's build, so callers come through here and the
/// compiler picks. Both sides expose the same `RazorpayCheckout.open`.
library;

export 'package:zuno/core/payments/razorpay_result.dart';
export 'package:zuno/core/payments/razorpay_checkout_native.dart'
    if (dart.library.js_interop) 'package:zuno/core/payments/razorpay_checkout_web.dart';
