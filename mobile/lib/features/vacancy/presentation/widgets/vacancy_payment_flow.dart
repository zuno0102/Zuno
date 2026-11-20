import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/payments/razorpay_checkout.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/core/router/push_screen.dart';
import 'package:zuno/features/vacancy/domain/entities/vacancy.dart';
import 'package:zuno/features/vacancy/domain/entities/vacancy_options.dart';
import 'package:zuno/features/vacancy/presentation/providers/business_vacancies_notifier.dart';
import 'package:zuno/features/vacancy/presentation/providers/vacancy_providers.dart';
import 'package:zuno/shared/widgets/sheet_drag_handle.dart';
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
    // How long it stays up: the Super Admin's options (1, 2 or 6 months…). One option needs no question.
    final plans = (await ref.read(
      vacancyOptionsProvider(asWorker: false).future,
    )).feePlans;
    String? feePlanId;
    if (plans.length > 1) {
      if (!context.mounted) return false;
      final chosen = await _pickFeePlan(context, plans);
      if (chosen == null) return false;
      feePlanId = chosen.id;
    }

    final payment = await notifier.openPayment(
      vacancy.id,
      feePlanId: feePlanId,
    );

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

/// Asks how long the job should stay up, each option with its price; null when closed.
Future<VacancyFeePlan?> _pickFeePlan(
  BuildContext context,
  List<VacancyFeePlan> plans,
) => pushSheet<VacancyFeePlan>(context, _FeePlanSheet(plans: plans));

class _FeePlanSheet extends StatelessWidget {
  const _FeePlanSheet({required this.plans});

  final List<VacancyFeePlan> plans;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          key: const ValueKey('vacancy-fee-plans'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetDragHandle(onDismiss: () => Navigator.of(context).maybePop()),
            Text(
              'How long should it stay up?',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            for (final plan in plans)
              Card(
                margin: const EdgeInsets.only(top: 8),
                child: ListTile(
                  key: ValueKey('vacancy-fee-plan-${plan.id}'),
                  title: Text(
                    plan.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text('${plan.listingDays} days'),
                  trailing: Text(
                    rupees(plan.amount),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  onTap: () => Navigator.of(context).pop(plan),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
