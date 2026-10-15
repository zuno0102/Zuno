import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:zuno/core/payments/razorpay_result.dart';

@JS('Razorpay')
extension type _RazorpayJs._(JSObject _) implements JSObject {
  external factory _RazorpayJs(JSObject options);
  external void open();
  external void on(String event, JSFunction handler);
}

/// Opens Razorpay Checkout and waits for the business to pay.
///
/// Web-only by design: the `razorpay_flutter` package covers Android and iOS but not web, and
/// the browser is where this app runs. Checkout is Razorpay's own hosted UI, so card details
/// and UPI PINs are entered on their surface and never touch this app.
class RazorpayCheckout {
  const RazorpayCheckout._();

  /// Whether Razorpay's script actually loaded.
  ///
  /// Read off the global object rather than through an `external` getter: a missing global
  /// throws on access in some builds, and a blocked script is an ordinary thing to handle,
  /// not an error to crash on.
  static bool get isAvailable => globalContext.has('Razorpay');

  /// Shows the payment window for [orderId] and resolves once payment succeeds.
  ///
  /// Throws [RazorpayCancelled] if the business backs out or the payment fails — never a
  /// success, because a caller that mistook one for the other would mark workers as paid.
  static Future<RazorpayResult> open({
    required String keyId,
    required String orderId,
    required double amount,
    required String description,
    String? businessName,
    String? contactEmail,
  }) {
    if (!isAvailable) {
      return Future.error(
        const RazorpayCancelled(
          'The payment window could not be loaded. Check your connection and try again.',
        ),
      );
    }

    final completer = Completer<RazorpayResult>();

    void succeed(JSObject response) {
      if (completer.isCompleted) return;

      final paymentId = response.getProperty<JSAny?>('razorpay_payment_id'.toJS)?.dartify();
      final signature = response.getProperty<JSAny?>('razorpay_signature'.toJS)?.dartify();

      if (paymentId is! String || signature is! String) {
        completer.completeError(
          const RazorpayCancelled('Razorpay did not return a usable payment reference.'),
        );
        return;
      }

      completer.complete(
        RazorpayResult(paymentId: paymentId, orderId: orderId, signature: signature),
      );
    }

    void fail(String reason) {
      if (!completer.isCompleted) {
        completer.completeError(RazorpayCancelled(reason));
      }
    }

    final options = JSObject()
      ..setProperty('key'.toJS, keyId.toJS)
      // Razorpay works in paise. Rounded here rather than truncated so ₹0.005 never silently
      // becomes ₹0 — the server sends the same figure, and the two must agree exactly.
      ..setProperty('amount'.toJS, (amount * 100).round().toJS)
      ..setProperty('currency'.toJS, 'INR'.toJS)
      ..setProperty('order_id'.toJS, orderId.toJS)
      ..setProperty('name'.toJS, (businessName ?? 'Zuno').toJS)
      ..setProperty('description'.toJS, description.toJS)
      ..setProperty('handler'.toJS, ((JSObject r) => succeed(r)).toJS)
      ..setProperty(
        'modal'.toJS,
        (JSObject()
          ..setProperty(
            'ondismiss'.toJS,
            (() => fail('Payment window closed before the payment completed.')).toJS,
          )),
      );

    if (contactEmail != null) {
      options.setProperty(
        'prefill'.toJS,
        (JSObject()..setProperty('email'.toJS, contactEmail.toJS)),
      );
    }

    final razorpay = _RazorpayJs(options);

    // Razorpay reports a declined card or a failed UPI collect through this event rather than
    // the handler, so without it a refusal would hang the sheet forever.
    razorpay.on(
      'payment.failed',
      ((JSObject response) {
        final error = response.getProperty<JSAny?>('error'.toJS);
        final described = (error?.isA<JSObject>() ?? false)
            ? (error! as JSObject).getProperty<JSAny?>('description'.toJS)?.dartify()
            : null;
        fail(described is String ? described : 'The payment was declined.');
      }).toJS,
    );

    razorpay.open();

    return completer.future;
  }
}
