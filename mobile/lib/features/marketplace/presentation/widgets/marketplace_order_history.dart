import 'package:flutter/material.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/features/marketplace/domain/entities/marketplace_order.dart';
import 'package:zuno/shared/widgets/detail_row.dart';

/// An order's history, oldest first: each step, who took it and when. [forCustomer] words who did
/// it from the customer's side ("by you" is the customer); otherwise from the business's.
class MarketplaceOrderHistory extends StatelessWidget {
  const MarketplaceOrderHistory({
    required this.events,
    this.forCustomer = false,
    super.key,
  });

  final List<MarketplaceOrderEvent> events;
  final bool forCustomer;

  String _who(String actor) => switch (actor) {
    'Business' => forCustomer ? 'by the seller' : 'by you',
    'Customer' => forCustomer ? 'by you' : 'by the customer',
    _ => 'automatically',
  };

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('History', style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 8),
      for (final step in events)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: DetailRow.iconText(
            icon: Icons.circle,
            iconSize: 10,
            text: [
              step.statusName,
              _who(step.actor),
              '${formatDayMonth(step.at)}, ${formatTime(step.at)}',
              ?step.note,
            ].join(' · '),
          ),
        ),
    ],
  );
}
