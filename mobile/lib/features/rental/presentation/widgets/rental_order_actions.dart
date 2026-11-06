import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/features/rental/domain/entities/rental_customer.dart';
import 'package:zuno/features/rental/domain/entities/rental_payment.dart';
import 'package:zuno/features/rental/domain/entities/rental_stock.dart';
import 'package:zuno/features/rental/presentation/providers/rental_order_providers.dart';
import 'package:zuno/features/rental/presentation/providers/rental_providers.dart';
import 'package:zuno/shared/widgets/app_messages.dart';
import 'package:zuno/shared/widgets/confirm_dialog.dart';

/// Takes one step on a rent order — "Send out", "Mark returned", "Cancel order" — asking first when
/// the step says so, then refreshes every Rent list, stock figure and tile.
///
/// Returns the order as it now stands, or null if the business backed out or the step failed (the
/// failure is shown).
Future<RentalOrder?> runRentalOrderAction(
  BuildContext context,
  WidgetRef ref,
  RentalOrder order,
  RentalOrderAction action, {
  RentalAudience audience = RentalAudience.business,
}) async {
  String? refundMode;
  if (action.confirmFirst) {
    // Cancelling a paid order: what is kept and what comes back, worked out by the server now.
    final quote = action.toStatus == 'Cancelled'
        ? await _cancelQuote(ref, order, audience)
        : null;
    final money = quote == null ? null : rentalCancelMoneyLine(quote, audience);
    if (!context.mounted) return null;
    final title = '${action.label}?';
    final message =
        '${order.customerName} · ${order.quantity} × ${order.itemName}. '
        '${money == null ? '' : '$money '}'
        'This cannot be undone.';

    // The business cancelling a paid order says how the money goes back in the same step.
    if (quote != null && quote.refundModes.isNotEmpty) {
      refundMode = await showRentalCancelRefundDialog(
        context,
        title: title,
        message: message,
        confirmLabel: action.label,
        quote: quote,
      );
      if (refundMode == null || !context.mounted) return null;
    } else {
      final confirmed = await showConfirmDialog(
        context,
        title: title,
        message: message,
        confirmLabel: action.label,
        cancelLabel: 'Keep order',
        destructive: true,
      );
      if (!confirmed || !context.mounted) return null;
    }
  }

  // Before the await, as the app's messages need: the screen's colours and its messenger.
  final messenger = AppMessenger.of(context);
  final reload = rentalReloader(ref);
  try {
    final updated = await ref
        .read(rentalOrdersGatewayProvider(audience))
        .takeStep(order.id, action.toStatus, refundMode: refundMode);
    reload();
    messenger.showSuccess(
      rentalCancelledMoneyNote(updated, audience) ??
          '${updated.customerName}: ${updated.quantity} × ${updated.itemName} — '
              '${updated.statusName.toLowerCase()}.',
    );
    return updated;
  } catch (e) {
    messenger.showFailure(e.toString());
    return null;
  }
}

/// What cancelling [order] now costs and gives back, from the server; null when it cannot be had —
/// the cancel itself still works out the same sums, and asks for a refund method if one is needed.
Future<RentalCancelQuote?> _cancelQuote(
  WidgetRef ref,
  RentalOrder order,
  RentalAudience audience,
) async {
  try {
    return await ref
        .read(rentalOrdersGatewayProvider(audience))
        .cancelQuote(order.id);
  } catch (_) {
    return null;
  }
}

/// The confirm dialog's money sentence for [quote], as [audience] reads it.
String? rentalCancelMoneyLine(
  RentalCancelQuote quote,
  RentalAudience audience,
) {
  if (quote.paid <= 0) return null;
  if (audience == RentalAudience.business) {
    return 'The customer gets back all ${rupees(quote.paid)} they paid.';
  }
  if (quote.charge <= 0) {
    return 'No cancellation charge now: all ${rupees(quote.paid)} you paid comes back.';
  }
  final noun = quote.unit == RentalCancelUnit.hour ? 'hour' : 'day';
  // A per-day charge counts the days rented, not how early the cancel comes.
  if (quote.basis == RentalCancelChargeType.perRentalDay) {
    final units = quote.rentalUnits;
    return 'Cancelling keeps ${rupees(quote.charge)} '
        '(${rentalPercent(quote.percent)} for $units rental $noun${units == 1 ? '' : 's'}) '
        'as the cancellation charge. '
        '${rupees(quote.refund)} of the ${rupees(quote.paid)} you paid comes back.';
  }
  final when = quote.unitsBefore == 0
      ? (quote.unit == RentalCancelUnit.hour
            ? 'within the last hour'
            : 'on the start day')
      : '${quote.unitsBefore} $noun${quote.unitsBefore == 1 ? '' : 's'} before the start';
  return 'Cancelling now, $when, keeps ${rupees(quote.charge)} '
      '(${rentalPercent(quote.percent)}) as the cancellation charge. '
      '${rupees(quote.refund)} of the ${rupees(quote.paid)} you paid comes back.';
}

/// Straight after a cancel that leaves money owed back: how much, and where to find it again.
/// Null when nothing is owed, and the plain "cancelled" message shows instead.
String? rentalCancelledMoneyNote(RentalOrder order, RentalAudience audience) {
  if (order.status != 'Cancelled' || order.refundOwed <= 0) return null;
  final owed = rupees(order.refundOwed);
  if (audience == RentalAudience.business) {
    if (order.refundMode == RentalRefundMode.online) {
      return 'Order cancelled. Zuno sends $owed back to ${order.customerName} online.';
    }
    return 'Order cancelled. Give back $owed to ${order.customerName}: '
        'it waits under Status management and the Refund due filter.';
  }
  return order.cancellationCharge > 0
      ? 'Cancelled. $owed comes back to you; '
            '${rupees(order.cancellationCharge)} is kept as the cancellation charge.'
      : 'Cancelled. All $owed you paid comes back to you.';
}

/// The cancel question for an order the customer paid for, with the refund method in it: the
/// business picks Online or In hand, and Cancel stays off until it has. Returns the chosen method,
/// or null when the business keeps the order.
Future<String?> showRentalCancelRefundDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required RentalCancelQuote quote,
}) => showDialog<String>(
  context: context,
  builder: (_) => _CancelRefundDialog(
    title: title,
    message: message,
    confirmLabel: confirmLabel,
    quote: quote,
  ),
);

class _CancelRefundDialog extends StatefulWidget {
  const _CancelRefundDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.quote,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final RentalCancelQuote quote;

  @override
  State<_CancelRefundDialog> createState() => _CancelRefundDialogState();
}

class _CancelRefundDialogState extends State<_CancelRefundDialog> {
  String? _mode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.message),
            const SizedBox(height: 14),
            Text(
              'How will ${rupees(widget.quote.refund)} go back?',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            for (final mode in widget.quote.refundModes)
              ListTile(
                key: ValueKey('cancel-refund-${mode.code}'),
                contentPadding: EdgeInsets.zero,
                enabled: mode.disabledReason == null,
                selected: _mode == mode.code,
                leading: Icon(
                  _mode == mode.code
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                ),
                title: Text(mode.name),
                subtitle: Text(mode.disabledReason ?? mode.text),
                onTap: () => setState(() => _mode = mode.code),
              ),
            if (_mode == null)
              Text(
                'Choose one to cancel the order.',
                key: const ValueKey('cancel-refund-hint'),
                style: muted,
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Keep order'),
        ),
        FilledButton(
          key: const ValueKey('cancel-refund-confirm'),
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
          ),
          onPressed: _mode == null ? null : () => Navigator.pop(context, _mode),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
