@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:zuno/core/payments/razorpay_checkout_native.dart';

/// What a business owner reads when a payment does not go through.
///
/// Worth its own test because Android and iOS report the same failure in two different shapes,
/// and the Android one is a JSON envelope. Showing that raw would put
/// `{"error":{"code":"BAD_REQUEST_ERROR",…}}` in front of someone trying to pay their crew.
void main() {
  group('RazorpayCheckout.reasonFor', () {
    test('backing out of the sheet reads as an ordinary cancellation', () {
      final reason = RazorpayCheckout.reasonFor(
        PaymentFailureResponse(
          Razorpay.PAYMENT_CANCELLED,
          'Payment processing cancelled by user',
          null,
        ),
      );

      expect(reason, 'Payment cancelled. Nothing has been sent to the crew.');
    });

    test('a network failure says the money did not move', () {
      final reason = RazorpayCheckout.reasonFor(
        PaymentFailureResponse(Razorpay.NETWORK_ERROR, 'no internet', null),
      );

      expect(reason, contains('Check your connection'));
      expect(reason, contains('nothing has been paid'));
    });

    test("Android's JSON envelope is unwrapped to the gateway's own sentence", () {
      final reason = RazorpayCheckout.reasonFor(
        PaymentFailureResponse(
          Razorpay.UNKNOWN_ERROR,
          '{"error":{"code":"BAD_REQUEST_ERROR","description":"Your card has expired",'
              '"source":"customer","step":"payment_authentication"}}',
          null,
        ),
      );

      expect(reason, 'Your card has expired. Nothing has been sent to the crew.');
      expect(reason, isNot(contains('BAD_REQUEST_ERROR')));
    });

    test("iOS's bare sentence is kept as it is", () {
      final reason = RazorpayCheckout.reasonFor(
        PaymentFailureResponse(
          Razorpay.UNKNOWN_ERROR,
          'Payment failed. Please try a different method.',
          null,
        ),
      );

      expect(
        reason,
        'Payment failed. Please try a different method. Nothing has been sent to the crew.',
      );
    });

    test('an envelope with no description falls back rather than showing JSON', () {
      final reason = RazorpayCheckout.reasonFor(
        PaymentFailureResponse(
          Razorpay.UNKNOWN_ERROR,
          '{"error":{"code":"GATEWAY_ERROR"}}',
          null,
        ),
      );

      expect(reason, 'The payment did not go through. Nothing has been sent to the crew.');
      expect(reason, isNot(contains('{')));
    });

    test('a malformed envelope never leaks braces to the business', () {
      final reason = RazorpayCheckout.reasonFor(
        PaymentFailureResponse(Razorpay.UNKNOWN_ERROR, '{not json at all', null),
      );

      expect(reason, isNot(contains('{')));
    });

    test('no message at all still explains that nobody was paid', () {
      final reason = RazorpayCheckout.reasonFor(
        PaymentFailureResponse(Razorpay.UNKNOWN_ERROR, null, null),
      );

      expect(reason, 'The payment did not go through. Nothing has been sent to the crew.');
    });
  });
}
