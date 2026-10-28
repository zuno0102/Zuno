import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/payments/razorpay_checkout.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/features/vacancy/domain/entities/vacancy.dart';
import 'package:zuno/features/vacancy/presentation/providers/business_vacancies_notifier.dart';
import 'package:zuno/shared/widgets/app_messages.dart';
import 'package:zuno/shared/widgets/confirm_dialog.dart';

/// Pays the listing fee for [vacancy] and puts it live (or extends it).
///
/// The price comes from the server's fee plan, and the business sees it before anything is charged.
/// Checkout is Razorpay's own window; the result is proved by the server's signature check, never by
/// this app. Returns whether the vacancy is now paid for.
Future<bool> payVacancyFee(
  BuildContext context,
  WidgetRef ref,
  Vacancy vacancy,
) async {
  final notifier = ref.read(businessVacanciesProvider.notifier);
  final messenger = AppMessenger.of(context);

  try {
    final payment = await notifier.openPayment(vacancy.id);

    // A free plan settled on the server already.
    if (payment.vacancy case final paid?) {
      notifier.put(paid);
      messenger.showSuccess(
        'Your job is live for ${payment.listingDays} days.',
      );
      return true;
    }

    if (!context.mounted) return false;
    final agreed = await showConfirmDialog(
      context,
      title: 'Pay ${rupees(payment.amount)} to post?',
      message:
          '${vacancy.title} will be shown to workers for '
          '${payment.listingDays} days. The listing fee is not refunded, '
          'even if you stop hiring or delete the job.',
      confirmLabel: 'Pay ${rupees(payment.amount)}',
      cancelLabel: 'Not now',
    );
    if (!agreed) return false;

    String? paymentId;
    String? signature;

    // No order means collection is simulated (development only): there is no window to open, and
    // the server confirms without a signature only while simulation is still on.
    if (!payment.nothingToCollect) {
      final keyId = payment.razorpayKeyId;
      final orderId = payment.providerOrderId;
      if (keyId == null || orderId == null) {
        throw Exception('The payment could not be opened. Please try again.');
      }

      final result = await RazorpayCheckout.open(
        keyId: keyId,
        orderId: orderId,
        amount: payment.amount,
        description: 'Job listing: ${vacancy.title}',
        businessName: vacancy.businessName,
      );
      paymentId = result.paymentId;
      signature = result.signature;
    }

    await notifier.confirmPayment(
      vacancy.id,
      paymentId: paymentId,
      signature: signature,
    );
    messenger.showSuccess(
      vacancy.isStopped
          ? 'Paid. Tap Start hiring again when you are ready.'
          : 'Your job is live for ${payment.listingDays} days.',
    );
    return true;
  } on RazorpayCancelled catch (e) {
    messenger.showInfo(e.reason ?? 'Payment cancelled. Nothing was charged.');
    return false;
  } catch (e) {
    messenger.showFailure(e.toString());
    return false;
  }
}
