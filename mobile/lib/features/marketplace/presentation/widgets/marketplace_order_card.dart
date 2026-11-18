import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/router/push_screen.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/features/marketplace/domain/entities/marketplace_order.dart';
import 'package:zuno/features/marketplace/presentation/providers/marketplace_order_providers.dart';
import 'package:zuno/features/marketplace/presentation/screens/marketplace_order_detail_screen.dart';
import 'package:zuno/features/marketplace/presentation/widgets/marketplace_ship_sheet.dart';
import 'package:zuno/shared/widgets/app_messages.dart';
import 'package:zuno/shared/widgets/call_icon_button.dart';
import 'package:zuno/shared/widgets/confirm_dialog.dart';
import 'package:zuno/shared/widgets/status_pill.dart';
import 'package:zuno/shared/widgets/status_with_actions.dart';

/// The app's colour for a status table tone name; an unknown name reads as waiting.
StatusTone marketplaceTone(String tone) =>
    StatusTone.values.asNameMap()[tone] ?? StatusTone.waiting;

/// After an order or request changes: the lists, counts and the order's own page read again.
void reloadMarketplaceOrders(WidgetRef ref) => ref
  ..invalidate(businessMarketplaceOrdersProvider)
  ..invalidate(businessMarketplaceOrderProvider)
  ..invalidate(businessB2BRequestsProvider);

/// "₹4,800 · Cash on delivery", "₹2,600 · Paid online", "₹2,600 · Refunded online".
String marketplaceOrderMoneyLine(MarketplaceOrder order) {
  final amount = rupees(order.amount);
  if (!order.isOnline) {
    return order.isPaid
        ? '$amount · Cash received'
        : '$amount · Cash on delivery';
  }
  if (order.refunded) return '$amount · Refunded online';
  if (order.refundDue) return '$amount · Refund on its way';
  return order.isPaid
      ? '$amount · Paid online'
      : '$amount · Waiting for online payment';
}

/// The line under a card that says what is happening — null when the status says it all.
String? marketplaceOrderNote(MarketplaceOrder order) {
  switch (order.status) {
    case 'AwaitingPayment':
      final payBy = order.payBy;
      return payBy == null
          ? 'Waiting for the customer to pay online.'
          : 'Waiting for the customer to pay online, until ${formatTime(payBy)}. Not paid by then, it is let go.';
    case 'Delivered':
      final closes = order.closesAt;
      return closes == null
          ? "Waiting for the customer's review."
          : "Waiting for the customer's review · closes on ${formatDayMonth(closes)}";
    case 'Cancelled':
      return switch (order.cancelledBy) {
        'Customer' =>
          'Cancelled by the customer, before shipping. The stock went back.',
        'System' => 'Not paid in time, so it was let go. The stock went back.',
        _ => 'Cancelled. The stock went back.',
      };
  }
  return null;
}

/// One product order: what and how many, the customer, money, and the next step as a button.
/// Tapping it opens the order.
class MarketplaceOrderCard extends ConsumerWidget {
  const MarketplaceOrderCard({
    required this.order,
    this.showActions = true,
    super.key,
  });

  final MarketplaceOrder order;
  final bool showActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final note = marketplaceOrderNote(order);

    return Card(
      key: ValueKey('marketplace-order-${order.id}'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => pushScreen(
          context,
          MarketplaceOrderDetailScreen(orderId: order.id),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Laid out like the Rent and Service order cards: what, who and when on the left;
              // the status, with a call button under it, on the right.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${order.quantity} × ${order.titleWithVariant}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          order.customerName,
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '#${order.number} · ${formatDayMonth(order.createdDate)}',
                          style: muted,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusWithActions(
                    status: StatusPill(
                      label: order.statusName,
                      tone: marketplaceTone(order.statusTone),
                      compact: true,
                    ),
                    actions: [
                      if (order.customerPhone.isNotEmpty)
                        CallIconButton(
                          phoneNumber: order.customerPhone,
                          tooltip: 'Call customer',
                          iconSize: 22,
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _Line(
                icon: Icons.currency_rupee_rounded,
                text: marketplaceOrderMoneyLine(order),
                key: ValueKey('marketplace-order-money-${order.id}'),
                color: order.refundDue
                    ? AppColors.status(StatusTone.danger, theme.brightness)
                    : null,
              ),
              if (order.courierLine case final courier?)
                _Line(icon: Icons.local_shipping_outlined, text: courier),
              if (order.ratingScore case final stars?)
                _Line(
                  icon: Icons.star_rounded,
                  text: order.ratingComment == null
                      ? '$stars of 5'
                      : '$stars of 5 · "${order.ratingComment}"',
                ),
              if (note != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    note,
                    key: ValueKey('marketplace-order-note-${order.id}'),
                    style: muted,
                  ),
                ),
              if (showActions && order.actions.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final action in order.actions)
                      FilledButton.tonal(
                        key: ValueKey(
                          'marketplace-order-action-${order.id}-${action.toStatus}',
                        ),
                        onPressed: () => runMarketplaceOrderAction(
                          context,
                          ref,
                          order,
                          action,
                        ),
                        child: Text(action.name),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text, this.color, super.key});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(
      color: color ?? theme.colorScheme.onSurfaceVariant,
      fontWeight: color == null ? null : FontWeight.w700,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: style?.color),
          const SizedBox(width: 4),
          Expanded(child: Text(text, style: style)),
        ],
      ),
    );
  }
}

/// Takes one of an order's steps. Mark shipped opens the ship sheet; a step that cannot be undone
/// asks first. Returns the order as it now is, or null when nothing changed.
Future<MarketplaceOrder?> runMarketplaceOrderAction(
  BuildContext context,
  WidgetRef ref,
  MarketplaceOrder order,
  MarketplaceOrderAction action,
) async {
  if (action.needsTracking) {
    return showMarketplaceShipSheet(context, order);
  }

  if (action.needsConfirm) {
    final confirmed = await showConfirmDialog(
      context,
      title: '${action.name}?',
      message:
          '${order.quantity} × ${order.titleWithVariant} for ${order.customerName}. '
          'This step cannot be undone.',
      confirmLabel: action.name,
    );
    if (!confirmed || !context.mounted) return null;
  }

  final messenger = AppMessenger.of(context);
  try {
    final changed = await ref
        .read(marketplaceOrderRepositoryProvider)
        .changeStatus(order.id, action.toStatus);
    reloadMarketplaceOrders(ref);
    messenger.showSuccess(
      'Order #${order.number}: ${changed.statusName.toLowerCase()}.',
    );
    return changed;
  } catch (e) {
    messenger.showFailure(e.toString());
    return null;
  }
}
