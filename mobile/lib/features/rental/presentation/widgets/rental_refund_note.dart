import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/features/rental/domain/entities/rental_customer.dart';
import 'package:zuno/features/rental/domain/entities/rental_payment.dart';
import 'package:zuno/features/rental/domain/entities/rental_stock.dart';
import 'package:zuno/features/rental/presentation/providers/rental_providers.dart';
import 'package:zuno/shared/widgets/app_messages.dart';
import 'package:zuno/shared/widgets/confirm_dialog.dart';

/// What happens to the money on a cancelled order: who cancelled and what was kept, then how the
/// rest goes back — online in 1 to 5 working days, or in hand from the business. The business
/// chooses the way here; the words each side reads come from the server's refund-mode table.
class RentalRefundNote extends ConsumerStatefulWidget {
  const RentalRefundNote({
    required this.order,
    this.audience = RentalAudience.business,
    super.key,
  });

  final RentalOrder order;
  final RentalAudience audience;

  @override
  ConsumerState<RentalRefundNote> createState() => _RentalRefundNoteState();
}

class _RentalRefundNoteState extends ConsumerState<RentalRefundNote> {
  bool _saving = false;

  RentalOrder get _order => widget.order;

  bool get _isBusiness => widget.audience == RentalAudience.business;

  Future<void> _choose(RentalRefundModeChoice mode) async {
    if (_saving || mode.code == _order.refundMode) return;
    // Money is involved, so the business says yes to what happens before it is set.
    final ask = rentalRefundModeQuestion(_order, mode);
    final confirmed = await showConfirmDialog(
      context,
      title: ask.title,
      message: ask.message,
      confirmLabel: ask.confirmLabel,
      cancelLabel: 'Not now',
    );
    if (!confirmed || !mounted) return;
    final messenger = AppMessenger.of(context);
    final reload = rentalReloader(ref);
    setState(() => _saving = true);
    try {
      await ref
          .read(rentalRepositoryProvider)
          .setRefundMode(_order.id, mode.code);
      reload();
      messenger.showSuccess('Refund goes back ${mode.name.toLowerCase()}.');
    } catch (e) {
      messenger.showFailure(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// "You cancelled: ₹100 kept as the cancellation charge." — null when there is nothing to say.
  String? get _whoCancelled {
    final paidAny = _order.paid > 0 || _order.payments.isNotEmpty;
    if (!paidAny) return null;
    if (_order.cancelledBy == 'Business') {
      return _isBusiness
          ? 'You cancelled, so the customer gets back all they paid.'
          : 'The business cancelled, so all you paid comes back to you.';
    }
    if (_order.cancelledByCustomer && _order.cancellationCharge > 0) {
      final kept = rupees(_order.cancellationCharge);
      return _isBusiness
          ? 'The customer cancelled: you keep $kept as the cancellation charge.'
          : 'You cancelled: $kept is kept as the cancellation charge.';
    }
    if (_order.cancelledByCustomer) {
      return _isBusiness
          ? 'The customer cancelled with no charge.'
          : 'You cancelled with no charge.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final who = _whoCancelled;
    final owed = _order.refundOwed > 0;
    final chosen = _order.refundModeText;

    if (who == null && !owed && chosen == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      key: const ValueKey('rental-refund-note'),
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (who != null)
            Text(
              who,
              key: const ValueKey('refund-who-cancelled'),
              style: muted,
            ),
          if (chosen != null) ...[
            const SizedBox(height: 8),
            Container(
              key: const ValueKey('refund-mode-text'),
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _order.refundMode == RentalRefundMode.online
                        ? Icons.account_balance_rounded
                        : Icons.storefront_rounded,
                    size: 18,
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text:
                                'Refund ${_order.refundModeName?.toLowerCase() ?? ''}. ',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          TextSpan(text: chosen),
                        ],
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (owed && !_isBusiness) ...[
            const SizedBox(height: 8),
            Text(
              'The business will choose how your ${rupees(_order.refundOwed)} '
              'comes back: online or in hand.',
              key: const ValueKey('refund-mode-pending'),
              style: muted,
            ),
          ],
          if (_isBusiness &&
              _order.canChooseRefundMode &&
              _order.refundModes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              chosen == null
                  ? 'How will ${rupees(_order.refundOwed)} go back?'
                  : 'Change how it goes back',
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final mode in _order.refundModes)
                  ChoiceChip(
                    key: ValueKey('refund-mode-${mode.code}'),
                    label: Text(mode.name),
                    selected: mode.code == _order.refundMode,
                    onSelected: _saving || mode.disabledReason != null
                        ? null
                        : (_) => _choose(mode),
                  ),
              ],
            ),
            for (final mode in _order.refundModes)
              if (mode.disabledReason case final reason?)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    reason,
                    key: ValueKey('refund-mode-${mode.code}-reason'),
                    style: muted,
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

/// The question asked before a refund method is set: what happens to the money, and to whom.
/// "Refund ₹11,400 online?" / "Give ₹950.40 back in hand?" / "Change the refund to in hand?".
({String title, String message, String confirmLabel}) rentalRefundModeQuestion(
  RentalOrder order,
  RentalRefundModeChoice mode,
) {
  final amount = rupees(order.refundOwed);
  final online = mode.code == RentalRefundMode.online;
  final changing = order.refundMode != null;
  return (
    title: changing
        ? 'Change the refund to ${mode.name.toLowerCase()}?'
        : online
        ? 'Refund $amount online?'
        : 'Give $amount back in hand?',
    message:
        '$amount to ${order.customerName}. ${mode.text} '
        '${order.customerName} is told how it comes back. '
        'You can change this until money goes back.',
    confirmLabel: online ? 'Refund online' : 'Give in hand',
  );
}
