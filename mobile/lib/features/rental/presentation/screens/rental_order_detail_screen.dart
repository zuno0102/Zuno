import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/router/push_screen.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/features/rental/domain/entities/rental_customer.dart';
import 'package:zuno/features/rental/domain/entities/rental_stock.dart';
import 'package:zuno/features/rental/presentation/providers/rental_order_providers.dart';
import 'package:zuno/features/rental/presentation/screens/rental_order_chat_screen.dart';
import 'package:zuno/features/rental/presentation/widgets/rental_order_actions.dart';
import 'package:zuno/features/rental/presentation/widgets/rental_order_card.dart';
import 'package:zuno/features/rental/presentation/widgets/rental_order_form_sheet.dart';
import 'package:zuno/features/rental/presentation/widgets/rental_order_timeline.dart';
import 'package:zuno/features/rental/presentation/widgets/rental_payment_card.dart';
import 'package:zuno/shared/widgets/status_pill.dart';

/// One rent order: what, how many, when, where, who — and its next steps as buttons, from the
/// server's transition table, with a way to message the other side. The same page for the business
/// and the customer; [audience] picks the routes and which steps show.
class RentalOrderDetailScreen extends ConsumerWidget {
  const RentalOrderDetailScreen({
    required this.order,
    this.audience = RentalAudience.business,
    super.key,
  });

  /// What the list showed; replaced by the server's copy once it loads or a step is taken.
  final RentalOrder order;

  final RentalAudience audience;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final current =
        ref.watch(rentalOrderProvider(order.id, audience)).value ?? order;
    final isBusiness = audience == RentalAudience.business;
    final counterpart = rentalCounterpartName(current, audience);

    Widget row(IconData icon, String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(value, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(isBusiness ? 'Rent order' : 'My rental')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  current.itemName.isEmpty ? 'Rent order' : current.itemName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              StatusPill(
                label: current.statusName,
                tone: rentalStatusTone(current.statusTone),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // The total first: what this customer has on this order and every extra added to it.
          _TotalCard(order: current, audience: audience),
          const SizedBox(height: 12),
          // Then the money: what it costs, what is paid, what is still due.
          RentalPaymentCard(order: current, audience: audience),
          const SizedBox(height: 20),
          // Then the story of how it got there, step by step.
          RentalOrderTimeline(orderId: current.id, audience: audience),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),
          row(
            Icons.event_outlined,
            'Dates',
            '${formatDate(current.startDate)} – ${formatDate(current.endDate)}',
          ),
          row(Icons.place_outlined, 'Where it goes', current.placeLine),
          if (isBusiness) ...[
            row(Icons.person_outline, 'Customer', current.customerName),
            if (current.customerPhone case final phone? when phone.isNotEmpty)
              row(Icons.phone_outlined, 'Phone', phone),
            row(
              current.isFromApp
                  ? Icons.phone_iphone
                  : Icons.storefront_outlined,
              'Order from',
              current.isFromApp ? 'The app' : 'Offline order',
            ),
          ] else
            row(Icons.storefront_outlined, 'Rented from', counterpart),
          // What the customer told the business when booking.
          for (final answer in current.answers)
            row(Icons.help_outline_rounded, answer.prompt, answer.answer),
          const SizedBox(height: 16),
          // With extras on the order, say whose pieces the buttons move.
          if (isBusiness &&
              current.addOns.isNotEmpty &&
              current.actions.isNotEmpty) ...[
            Text(
              'These buttons are for the first ${current.quantity}. '
              'Tap an extra above to send it out or mark it returned.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (current.actions.isEmpty)
            Text(
              isBusiness
                  ? 'Nothing left to do on this order.'
                  : 'The business will send it out on the start date. '
                        'Message them with any question.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            for (final action in current.actions)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    action.confirmFirst
                        ? OutlinedButton(
                            onPressed: action.disabledReason != null
                                ? null
                                : () => runRentalOrderAction(
                                    context,
                                    ref,
                                    current,
                                    action,
                                    audience: audience,
                                  ),
                            child: Text(action.label),
                          )
                        : FilledButton(
                            onPressed: action.disabledReason != null
                                ? null
                                : () => runRentalOrderAction(
                                    context,
                                    ref,
                                    current,
                                    action,
                                    audience: audience,
                                  ),
                            child: Text(action.label),
                          ),
                    // "Mark returned" waits for the money: say so right under it.
                    if (action.disabledReason case final reason?)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          reason,
                          key: ValueKey('action-reason-${action.toStatus}'),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          if (current.canAddPieces) ...[
            OutlinedButton.icon(
              onPressed: () => showAddPiecesSheet(context, current),
              icon: const Icon(Icons.add),
              label: const Text('Add more pieces'),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: () => pushScreen(
              context,
              RentalOrderChatScreen(
                order: current,
                audience: audience,
                canOpenOrder: false,
              ),
            ),
            icon: Badge(
              isLabelVisible: current.unreadMessages > 0,
              label: Text('${current.unreadMessages}'),
              child: const Icon(Icons.chat_bubble_outline_rounded),
            ),
            label: Text('Message $counterpart'),
          ),
        ],
      ),
    );
  }
}

/// The order's total at a glance: "500 pieces" big, then where they come from — the first order and
/// each extra, with its status. An extra opens its own page, where it is sent out and returned.
class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.order, required this.audience});

  final RentalOrder order;
  final RentalAudience audience;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    Widget line({
      required String label,
      required int quantity,
      required String statusName,
      required String statusTone,
      VoidCallback? onTap,
      Key? key,
    }) => InkWell(
      key: key,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
            Text(
              '$quantity',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 10),
            StatusPill(
              label: statusName,
              tone: rentalStatusTone(statusTone),
              compact: true,
            ),
            if (onTap != null)
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(order.isAddOn ? 'EXTRA PIECES' : 'TOTAL', style: muted),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${order.quantityWithAddOns}',
                  key: const ValueKey('order-total'),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 6),
                Text('pieces', style: theme.textTheme.bodyMedium),
              ],
            ),
            if (order.isAddOn)
              Text(
                'Added to an earlier order from ${order.customerName}. '
                'It is sent out and returned on its own.',
                style: muted,
              ),
            if (order.addOns.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '${order.quantity} + '
                '${order.addOns.map((a) => a.quantity).join(' + ')} = '
                '${order.quantityWithAddOns}',
                key: const ValueKey('order-sum'),
                style: muted,
              ),
              const Divider(height: 18),
              line(
                label: 'First order',
                quantity: order.quantity,
                statusName: order.statusName,
                statusTone: order.statusTone,
              ),
              for (final addOn in order.addOns)
                line(
                  key: ValueKey('add-on-${addOn.id}'),
                  label: 'Extra',
                  quantity: addOn.quantity,
                  statusName: addOn.statusName,
                  statusTone: addOn.statusTone,
                  // Its own page: the extra pieces have their own send-out and return.
                  onTap: () => pushScreen(
                    context,
                    RentalOrderDetailScreen(
                      audience: audience,
                      order: RentalOrder(
                        id: addOn.id,
                        rentalItemId: order.rentalItemId,
                        itemName: order.itemName,
                        customerName: order.customerName,
                        customerPhone: order.customerPhone,
                        quantity: addOn.quantity,
                        startDate: order.startDate,
                        endDate: order.endDate,
                        deliveryAddress: order.deliveryAddress,
                        districtName: order.districtName,
                        status: '',
                        statusName: addOn.statusName,
                        statusTone: addOn.statusTone,
                        isOut: false,
                        parentOrderId: order.id,
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
