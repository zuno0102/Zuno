import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:zuno/core/payments/razorpay_result.dart';

/// Razorpay Checkout on Android and iOS, through Razorpay's own native SDK.
///
/// The counterpart to the web implementation, which drives Razorpay's JavaScript SDK. Neither
/// covers both surfaces — `razorpay_flutter` has no web support and the JS SDK has no native
/// one — so the two live side by side and `razorpay_checkout.dart` picks per platform at
/// compile time. Both expose the same `open`, so the pay sheet never learns which it got.
///
/// Either way the business types their card number or UPI PIN on Razorpay's own screen.
/// Nothing sensitive passes through this app, and the only thing coming back worth trusting is
/// the signature, which the server re-computes against a secret it never shares.
class RazorpayCheckout {
  const RazorpayCheckout._();

  /// The SDK is compiled into the app, so it is always there to open.
  static bool get isAvailable => true;

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
    final razorpay = Razorpay();
    final completer = Completer<RazorpayResult>();

    // The SDK can report more than once for a single attempt — a resync replaying a response
    // the app missed while backgrounded, say — so every path checks first and the listeners
    // come down exactly once.
    void settle(void Function() complete) {
      if (completer.isCompleted) return;
      complete();
      razorpay.clear();
    }

    razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse r) {
      settle(() {
        final paymentId = r.paymentId;
        final signature = r.signature;

        // A success the server cannot verify is worth no more than a failure, so it is
        // reported as one here rather than sent on to be rejected with a confusing message.
        if (paymentId == null || signature == null) {
          completer.completeError(
            const RazorpayCancelled(
              'Razorpay did not return a usable payment reference. Nothing has been sent to '
              'the crew — try paying again.',
            ),
          );
          return;
        }

        completer.complete(
          RazorpayResult(
            paymentId: paymentId,
            // The order Razorpay echoes back, falling back to the one we opened with: on some
            // flows the native SDK omits it, and the server needs it to check the signature.
            orderId: r.orderId ?? orderId,
            signature: signature,
          ),
        );
      });
    });

    razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse r) {
      settle(() => completer.completeError(RazorpayCancelled(reasonFor(r))));
    });

    // Some wallets finish the payment in their own app and tell us nothing more. Without a
    // signature there is nothing the server can verify, so the run stays unpaid rather than
    // releasing wages against a payment nobody confirmed.
    razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse r) {
      settle(() {
        completer.completeError(
          const RazorpayCancelled(
            'That wallet finishes the payment outside Zuno, so it cannot be confirmed here. '
            'Pay by card or UPI instead.',
          ),
        );
      });
    });

    razorpay.open({
      'key': keyId,
      // Paise, as an integer — the same unit the server raised the order in. Rupees here would
      // charge a hundredth of the bill.
      'amount': (amount * 100).round(),
      'order_id': orderId,
      'currency': 'INR',
      'name': businessName ?? 'Zuno',
      'description': description,
      if (contactEmail != null && contactEmail.isNotEmpty)
        'prefill': {'email': contactEmail},
      'theme': {'color': '#4B3FB8'},
    });

    return completer.future;
  }

  /// Turns a native failure into something a business can act on.
  ///
  /// Closing the sheet arrives here too, as [Razorpay.PAYMENT_CANCELLED] — the native SDK has
  /// no separate dismissal callback the way Checkout on the web does. Backing out is an
  /// ordinary thing to do, so it gets ordinary wording rather than the SDK's error text.
  @visibleForTesting
  static String reasonFor(PaymentFailureResponse response) {
    if (response.code == Razorpay.PAYMENT_CANCELLED) {
      return 'Payment cancelled. Nothing has been sent to the crew.';
    }

    if (response.code == Razorpay.NETWORK_ERROR) {
      return 'Could not reach Razorpay. Check your connection and try again — nothing has '
          'been paid.';
    }

    final described = _describe(response.message);

    // Razorpay's own words wherever there are any: they name the real cause — an expired card,
    // a declined UPI request — far better than anything invented here.
    return described == null
        ? 'The payment did not go through. Nothing has been sent to the crew.'
        : '$described Nothing has been sent to the crew.';
  }

  /// Pulls the human sentence out of a failure message.
  ///
  /// Android hands back the gateway's whole JSON envelope as the message — showing that raw
  /// would put `{"error":{"code":"BAD_REQUEST_ERROR",…}}` in front of a business owner. iOS
  /// sends the sentence alone, so both shapes are handled.
  static String? _describe(String? message) {
    final text = message?.trim();
    if (text == null || text.isEmpty) return null;

    if (text.startsWith('{')) {
      try {
        final decoded = jsonDecode(text);
        if (decoded is Map<String, dynamic>) {
          final error = decoded['error'];
          final description = error is Map<String, dynamic>
              ? error['description']
              : decoded['description'];
          if (description is String && description.trim().isNotEmpty) {
            return _asSentence(description.trim());
          }
        }
      } on FormatException {
        // Not the envelope after all — fall through and show it as it came.
      }

      // A JSON blob with no description in it says nothing useful to a business owner.
      return null;
    }

    return _asSentence(text);
  }

  static String _asSentence(String text) =>
      text.endsWith('.') || text.endsWith('!') || text.endsWith('?')
          ? text
          : '$text.';
}
