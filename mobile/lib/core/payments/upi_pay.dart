import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// What a UPI app said when it came back from a payment.
enum UpiPayStatus {
  /// The UPI app says the money went.
  success,

  /// The UPI app says it did not.
  failure,

  /// Sent but not settled yet, or the app said nothing clear — the person checks and confirms.
  unknown,

  /// No UPI app on the phone, or not on Android.
  unavailable,
}

class UpiPayResult {
  const UpiPayResult(this.status, {this.reference});

  final UpiPayStatus status;

  /// The UPI transaction reference the app gave, when it gave a usable one.
  final String? reference;
}

/// Pays by UPI through whatever UPI app the phone has (GPay, PhonePe, Paytm…), opened by
/// `MainActivity` (android/app/src/main/kotlin/…/MainActivity.kt) on a filled-in `upi://pay` link.
///
/// The result is the UPI app's own report on this phone, not a bank's: good enough to record a
/// payment the person just made, with its reference kept as the evidence, never proof on its own.
class UpiPay {
  const UpiPay._();

  /// Must match `UPI_CHANNEL` in MainActivity.kt.
  static const _channel = MethodChannel('com.zuno.zuno/upi');

  static Future<UpiPayResult> pay(String uri) async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const UpiPayResult(UpiPayStatus.unavailable);
    }

    try {
      final answer = await _channel.invokeMapMethod<String, Object?>('pay', {
        'uri': uri,
      });
      return parse(
        answer?['response'] as String?,
        cancelled: answer?['cancelled'] == true,
      );
    } on PlatformException catch (e) {
      return UpiPayResult(
        e.code == 'no_upi_app'
            ? UpiPayStatus.unavailable
            : UpiPayStatus.unknown,
      );
    } on MissingPluginException {
      return const UpiPayResult(UpiPayStatus.unavailable);
    }
  }

  /// Reads a UPI app's answer, e.g. `txnId=AXI123&responseCode=00&Status=SUCCESS&txnRef=ZR42`.
  /// Apps differ in case and in which keys they fill, so this is lenient; anything unclear is
  /// [UpiPayStatus.unknown] and the person confirms.
  static UpiPayResult parse(String? response, {bool cancelled = false}) {
    if (response == null || response.trim().isEmpty) {
      return UpiPayResult(
        cancelled ? UpiPayStatus.failure : UpiPayStatus.unknown,
      );
    }

    final fields = <String, String>{};
    for (final part in response.split('&')) {
      final at = part.indexOf('=');
      if (at <= 0) continue;
      fields[part.substring(0, at).trim().toLowerCase()] = Uri.decodeComponent(
        part.substring(at + 1).trim(),
      );
    }

    final status = switch ((fields['status'] ?? '').toUpperCase()) {
      'SUCCESS' => UpiPayStatus.success,
      'FAILURE' || 'FAILED' => UpiPayStatus.failure,
      _ => UpiPayStatus.unknown,
    };
    // The bank's approval number is the one a person can find in their statement.
    final reference = [
      fields['approvalrefno'],
      fields['txnid'],
      fields['txnref'],
    ].whereType<String>().where(_isReference).firstOrNull;

    return UpiPayResult(status, reference: reference);
  }

  /// Letters, digits and dashes, 4 to 50 — the Rent server's `RentalPaymentFields.ReferencePattern`.
  static bool _isReference(String value) =>
      RegExp(r'^[A-Za-z0-9-]{4,50}$').hasMatch(value);
}
