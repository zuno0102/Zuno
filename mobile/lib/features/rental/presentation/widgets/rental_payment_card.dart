import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/payments/razorpay_checkout.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/features/rental/domain/entities/rental_customer.dart';
import 'package:zuno/features/rental/domain/entities/rental_item.dart';
import 'package:zuno/features/rental/domain/entities/rental_payment.dart';
import 'package:zuno/features/rental/domain/entities/rental_stock.dart';
import 'package:zuno/features/rental/presentation/providers/rental_order_providers.dart';
import 'package:zuno/features/rental/presentation/providers/rental_payment_providers.dart';
import 'package:zuno/features/rental/presentation/providers/rental_providers.dart';
import 'package:zuno/features/rental/presentation/widgets/rental_collect_sheet.dart';
import 'package:zuno/features/rental/presentation/widgets/rental_order_card.dart';
import 'package:zuno/features/rental/presentation/widgets/rental_refund_note.dart';
import 'package:zuno/shared/widgets/app_messages.dart';
import 'package:zuno/shared/widgets/status_pill.dart';

/// The money on an order, at a glance: what it costs, the advance, what is paid and what is still
/// due — with every payment listed, and the next money step as a button: collect it (business), give
/// it back (business, cancelled order), or pay it online (customer).
class RentalPaymentCard extends ConsumerWidget {
  const RentalPaymentCard({
    required this.order,
    this.audience = RentalAudience.business,
    super.key,
  });

  final RentalOrder order;
  final RentalAudience audience;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Orders from before prices were kept have nothing to show.
    if (!order.isPriced && order.payments.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final isBusiness = audience == RentalAudience.business;

    Widget line(String label, String value, {bool strong = false, Key? key}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
              Text(
                value,
                key: key,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
                  color: strong ? theme.colorScheme.primary : null,
                ),
              ),
            ],
          ),
        );

    return Card(
      key: const ValueKey('rental-payment-card'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('PAYMENT', style: muted)),
                if (order.paymentStatusName case final name?)
                  StatusPill(
                    label: name,
                    tone: rentalStatusTone(order.paymentStatusTone ?? ''),
                    compact: true,
                  ),
              ],
            ),
            Text(
              rupees(order.amount),
              key: const ValueKey('payment-amount'),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(rentalRateLine(order), style: muted),
            const Divider(height: 20),
            if (order.advanceDue > 0)
              line(
                'Advance',
                '${rupees(order.advanceDue)} · '
                    '${order.payments.any((p) => p.isAdvance) ? 'paid' : 'due'}',
              ),
            line(
              'Paid',
              rupees(order.paid),
              key: const ValueKey('payment-paid'),
            ),
            if (order.status != 'Cancelled')
              line(
                'Balance',
                rupees(order.balance),
                strong: order.balance > 0,
                key: const ValueKey('payment-balance'),
              ),
            if (order.cancellationCharge > 0)
              line(
                'Cancellation charge',
                rupees(order.cancellationCharge),
                key: const ValueKey('payment-cancel-charge'),
              ),
            if (order.refundOwed > 0)
              line(
                isBusiness ? 'To give back' : 'Refund due to you',
                rupees(order.refundOwed),
                strong: true,
                key: const ValueKey('payment-refund-owed'),
              ),
            if (order.payments.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final p in order.payments)
                Padding(
                  key: ValueKey('payment-${p.id}'),
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Icon(
                        p.isRefund
                            ? Icons.undo_rounded
                            : Icons.check_circle_outline_rounded,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          [
                            _kindName(p.kind),
                            p.methodName,
                            if (p.reference case final reference?)
                              'ref $reference',
                            formatDayMonth(p.at),
                          ].join(' · '),
                          style: muted,
                        ),
                      ),
                      Text(
                        '${p.isRefund ? '−' : ''}${rupees(p.amount)}',
                        style: muted?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
            ],
            if (!isBusiness && order.isAwaitingAdvance) ...[
              const SizedBox(height: 10),
              Text(
                'Pay the advance of ${rupees(order.payNowAmount)}'
                '${order.holdUntil == null ? '' : ' by ${formatTime(order.holdUntil!)}'}'
                ' to confirm. Unpaid by then, the pieces are let go.',
                key: const ValueKey('advance-hold-note'),
                style: muted?.copyWith(color: theme.colorScheme.error),
              ),
            ],
            if (order.status == 'Cancelled')
              RentalRefundNote(order: order, audience: audience),
            if (isBusiness && order.canCollect) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const ValueKey('collect-payment'),
                onPressed: () => showRentalCollectSheet(context, order),
                icon: const Icon(Icons.qr_code_2_rounded),
                label: Text(
                  order.isAwaitingAdvance
                      ? 'Collect advance ${rupees(order.payNowAmount)}'
                      : 'Collect ${rupees(order.balance)}',
                ),
              ),
            ],
            if (isBusiness && order.canRefund) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const ValueKey('record-refund'),
                onPressed: () =>
                    showRentalCollectSheet(context, order, refund: true),
                icon: const Icon(Icons.undo_rounded),
                label: Text('Record refund of ${rupees(order.refundOwed)}'),
              ),
            ],
            if (!isBusiness &&
                order.payNowAmount > 0 &&
                (order.isAwaitingAdvance || order.canPayOnline)) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const ValueKey('pay-online'),
                onPressed: () => payRentalOnline(context, ref, order),
                icon: const Icon(Icons.lock_outline_rounded),
                label: Text(
                  order.isAwaitingAdvance
                      ? 'Pay advance ${rupees(order.payNowAmount)}'
                      : 'Pay ${rupees(order.payNowAmount)} online',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _kindName(String kind) => switch (kind) {
    'Advance' => 'Advance',
    'Refund' => 'Refund',
    _ => 'Payment',
  };
}

/// "300 × ₹10 × 2 days" — how the order's amount was reached.
String rentalRateLine(RentalOrder order) {
  final unit = switch (order.priceType) {
    RentalPriceType.daily => order.units == 1 ? 'day' : 'days',
    RentalPriceType.hourly => order.units == 1 ? 'hour' : 'hours',
    _ => null,
  };
  return [
    '${order.quantity} × ${rupees(order.unitPrice)}',
    if (unit != null) '${order.units} $unit',
  ].join(' × ');
}

/// The order card's money line: "₹500 paid · ₹1,500 due", "Paid ₹2,000", "Advance ₹200 due" — or
/// null for an order with nothing to say.
String? rentalMoneyLine(RentalOrder order, {RentalAudience? audience}) {
  if (order.paymentStatus == null) return null;
  return switch (order.paymentStatus) {
    'AdvanceDue' => 'Advance ${rupees(order.payNowAmount)} due',
    'Paid' => 'Paid ${rupees(order.paid)}',
    'RefundDue' when audience != null => _refundLine(order, audience),
    'RefundDue' => 'Refund due ${rupees(order.refundOwed)}',
    'ChargeKept' => 'Charge kept ${rupees(order.cancellationCharge)}',
    'Refunded' => 'Refunded',
    _ when order.paid <= 0 => '${rupees(order.balance)} due',
    _ => '${rupees(order.paid)} paid · ${rupees(order.balance)} due',
  };
}

/// "Give back ₹500 · you cancelled", "Refund ₹380 online · you cancelled" — what is owed back on a
/// cancelled order and who cancelled it, as [audience] reads it.
String _refundLine(RentalOrder order, RentalAudience audience) {
  final business = audience == RentalAudience.business;
  final amount = rupees(order.refundOwed);
  final online = order.refundMode == RentalRefundMode.online;
  final what = business
      ? (online ? 'Refund $amount goes back online' : 'Give back $amount')
      : (online ? 'Refund $amount online' : 'Refund due $amount');
  final who = switch (order.cancelledBy) {
    'Business' => business ? 'you cancelled' : 'business cancelled',
    'Customer' => business ? 'customer cancelled' : 'you cancelled',
    _ => null,
  };
  return who == null ? what : '$what · $who';
}

/// Pays online for [order]: the advance while it is awaited, otherwise what is due. The payment
/// window is the gateway's own; the server counts the payment only once its signature checks out.
/// Returns the order as it now stands, or null when it was not paid (the reason is shown).
Future<RentalOrder?> payRentalOnline(
  BuildContext context,
  WidgetRef ref,
  RentalOrder order,
) async {
  final messenger = AppMessenger.of(context);
  final repository = ref.read(rentalCustomerRepositoryProvider);
  final window = ref.read(rentalPaymentWindowProvider);

  try {
    final checkout = await repository.checkout(order.id);

    // Simulated collection (development only) has no window to open; the server accepts it only
    // while simulation is on. The payment id is unique per checkout, as a real one would be.
    final result = checkout.nothingToCollect
        ? RazorpayResult(
            paymentId: 'sim_${checkout.providerOrderId}',
            orderId: checkout.providerOrderId,
            signature: 'simulated',
          )
        : await window(checkout, order.businessName ?? 'Zuno Rent');

    final paid = await repository.pay(
      order.id,
      providerOrderId: checkout.providerOrderId,
      paymentId: result.paymentId,
      signature: result.signature,
    );
    reloadRentals(ref);

    if (checkout.nothingToCollect) {
      // Never a plain "Paid": no window opened and no money moved, so say so.
      messenger.showInfo(
        'Test mode: marked ${rupees(checkout.amount)} as paid. '
        'No payment app opened and no money was taken.',
      );
    } else if (paid.status == 'Cancelled') {
      // The hold ran out while paying and the pieces went to someone else: the money is recorded.
      messenger.showInfo(
        'Paid ${rupees(checkout.amount)}, but the pieces were booked by someone else meanwhile. '
        '${paid.businessName ?? 'The business'} will refund it.',
      );
    } else if (order.isAwaitingAdvance) {
      messenger.showSuccess(
        'Advance ${rupees(checkout.amount)} paid — booking confirmed. '
        '${rupees(paid.balance)} is paid before the return.',
      );
    } else {
      messenger.showSuccess('Paid ${rupees(checkout.amount)}.');
    }
    return paid;
  } on RazorpayCancelled catch (e) {
    reloadRentals(ref);
    // A UPI app can take the money and still come back as "closed"; the server asks Razorpay every
    // minute and confirms a paid booking by itself, so never promise "nothing was charged".
    messenger.showInfo(
      e.reason ??
          'Payment not finished. If money left your account, the booking is '
              'confirmed by itself within a few minutes.',
    );
    return null;
  } catch (e) {
    messenger.showFailure(e.toString());
    return null;
  }
}
