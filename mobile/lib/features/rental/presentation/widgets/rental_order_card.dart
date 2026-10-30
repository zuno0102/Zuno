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
import 'package:zuno/shared/widgets/status_pill.dart';

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
          padding: const EdgeInsets.fromLTRB(14, 10, 4, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      counterpart,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  StatusPill(
                    label: order.statusName,
                    tone: rentalStatusTone(order.statusTone),
                    compact: true,
                  ),
                  IconButton(
                    tooltip: 'Message $counterpart',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => pushScreen(
                      context,
                      RentalOrderChatScreen(order: order, audience: audience),
                    ),
                    icon: Badge(
                      isLabelVisible: order.unreadMessages > 0,
                      label: Text('${order.unreadMessages}'),
                      child: const Icon(Icons.chat_bubble_outline_rounded),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      [
                        if (showItem && order.itemName.isNotEmpty)
                          '${order.quantityWithAddOns} × ${order.itemName}'
                        else
                          '${order.quantityWithAddOns} pcs',
                        '${formatDayMonth(order.startDate)} – '
                            '${formatDayMonth(order.endDate)}',
                      ].join(' · '),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
                    if (rentalMoneyLine(order) case final money?) ...[
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
