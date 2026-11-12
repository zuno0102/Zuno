import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/router/push_screen.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/features/rental/domain/entities/rental_customer.dart';
import 'package:zuno/features/rental/domain/entities/rental_stock.dart';
import 'package:zuno/features/rental/presentation/screens/rental_order_chat_screen.dart';
import 'package:zuno/features/rental/presentation/screens/rental_order_detail_screen.dart';
import 'package:zuno/features/rental/presentation/widgets/rental_order_actions.dart';
import 'package:zuno/features/rental/presentation/widgets/rental_payment_card.dart';
import 'package:zuno/shared/widgets/call_icon_button.dart';
import 'package:zuno/shared/widgets/status_pill.dart';
import 'package:zuno/shared/widgets/status_with_actions.dart';

/// One rent order: customer and status, what and how many for when, the place the pieces went,
/// and a way to message the customer. Tapping it opens the order.
///
/// With [showActions] the order's next steps sit on the card as buttons — the Status management
/// list. [showItem] is off where the item is already the page, as in an item's Orders tab.
class RentalOrderCard extends ConsumerWidget {
  const RentalOrderCard({
    required this.order,
    this.audience = RentalAudience.business,
    this.showItem = true,
    this.showActions = false,
    super.key,
  });

  final RentalOrder order;

  /// Whose list this card is in: the business sees the customer's name, a customer the business's.
  final RentalAudience audience;
  final bool showItem;
  final bool showActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final counterpart = rentalCounterpartName(order, audience);

    return Card(
      key: ValueKey('rental-order-${order.id}'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => pushScreen(
          context,
          RentalOrderDetailScreen(order: order, audience: audience),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Laid out like the service side's order card (BusinessOrderCard), in the same text
              // sizes: what, who and when on the left; the status, with message and call under it,
              // on the right.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          showItem && order.itemName.isNotEmpty
                              ? '${order.quantityWithAddOns} × ${order.itemName}'
                              : '${order.quantityWithAddOns} pcs',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(counterpart, style: theme.textTheme.bodyMedium),
                        const SizedBox(height: 4),
                        Text(
                          '${formatDayMonth(order.startDate)} – '
                          '${formatDayMonth(order.endDate)}',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusWithActions(
                    status: StatusPill(
                      label: order.statusName,
                      tone: rentalStatusTone(order.statusTone),
                      compact: true,
                    ),
                    actions: [
                      IconButton(
                        tooltip: 'Message $counterpart',
                        iconSize: 22,
                        onPressed: () => pushScreen(
                          context,
                          RentalOrderChatScreen(
                            order: order,
                            audience: audience,
                          ),
                        ),
                        icon: Badge(
                          isLabelVisible: order.unreadMessages > 0,
                          label: Text('${order.unreadMessages}'),
                          child: const Icon(Icons.chat_bubble_outline_rounded),
                        ),
                      ),
                      if (audience == RentalAudience.business &&
                          (order.customerPhone?.isNotEmpty ?? false))
                        CallIconButton(
                          phoneNumber: order.customerPhone!,
                          tooltip: 'Call customer',
                          iconSize: 22,
                        ),
                    ],
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (order.addOns.isNotEmpty || order.isAddOn) ...[
                      const SizedBox(height: 2),
                      Text(
                        order.isAddOn
                            ? 'Extra pieces for an earlier order'
                            : '${order.quantity} first + '
                                  '${order.quantityWithAddOns - order.quantity} extra',
                        style: muted?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.place_outlined,
                          size: 15,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(child: Text(order.placeLine, style: muted)),
                      ],
                    ),
                    if (rentalMoneyLine(order, audience: audience)
                        case final money?) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.currency_rupee_rounded,
                            size: 15,
                            color: AppColors.status(
                              rentalStatusTone(order.paymentStatusTone ?? ''),
                              theme.brightness,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              money,
                              key: ValueKey('money-${order.id}'),
                              style: muted?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.status(
                                  rentalStatusTone(
                                    order.paymentStatusTone ?? '',
                                  ),
                                  theme.brightness,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    // Money still to give back: the to-do on a cancelled order, straight to its page.
                    if (showActions && order.needsRefund) ...[
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        key: ValueKey('give-back-${order.id}'),
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.colorScheme.error,
                          foregroundColor: theme.colorScheme.onError,
                        ),
                        onPressed: () => pushScreen(
                          context,
                          RentalOrderDetailScreen(
                            order: order,
                            audience: audience,
                          ),
                        ),
                        icon: const Icon(Icons.undo_rounded),
                        // A customer's cancel leaves the method to choose; once chosen, it is to be given.
                        label: Text(
                          order.refundMode == null
                              ? 'Choose how to refund ${rupees(order.refundOwed)}'
                              : 'Give back ${rupees(order.refundOwed)}',
                        ),
                      ),
                    ],
                    if (showActions && order.actions.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          for (final action in order.actions)
                            action.confirmFirst
                                ? OutlinedButton(
                                    onPressed: action.disabledReason != null
                                        ? null
                                        : () => runRentalOrderAction(
                                            context,
                                            ref,
                                            order,
                                            action,
                                            audience: audience,
                                          ),
                                    child: Text(action.label),
                                  )
                                : FilledButton.tonal(
                                    onPressed: action.disabledReason != null
                                        ? null
                                        : () => runRentalOrderAction(
                                            context,
                                            ref,
                                            order,
                                            action,
                                            audience: audience,
                                          ),
                                    child: Text(action.label),
                                  ),
                        ],
                      ),
                      for (final action in order.actions)
                        if (action.disabledReason case final reason?)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '${action.label}: $reason',
                              style: muted?.copyWith(
                                color: theme.colorScheme.error,
                              ),
                            ),
                          ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Whether the business has something to do on [order]: a next step, or money to give back.
bool rentalNeedsBusinessStep(RentalOrder order) =>
    order.actions.isNotEmpty || order.needsRefund;

/// The app's colour for a status table tone name; an unknown name reads as waiting.
StatusTone rentalStatusTone(String tone) =>
    StatusTone.values.asNameMap()[tone] ?? StatusTone.waiting;

/// The other side of [order]: the customer, for the business; the business, for a customer.
String rentalCounterpartName(RentalOrder order, RentalAudience audience) =>
    audience == RentalAudience.business
    ? order.customerName
    : (order.businessName?.isNotEmpty ?? false)
    ? order.businessName!
    : 'Business';
