import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/features/rental/domain/entities/rental_customer.dart';
import 'package:zuno/features/rental/domain/entities/rental_stock.dart';
import 'package:zuno/features/rental/presentation/providers/rental_order_providers.dart';
import 'package:zuno/features/rental/presentation/widgets/rental_order_card.dart';

/// An order's record, oldest first: booked 300, sent out, 200 extra added, returned — each with the
/// time it happened. The extra pieces' own steps are woven in and marked, so the business sees the
/// whole story of what this customer had, and nothing is ever rewritten.
class RentalOrderTimeline extends ConsumerWidget {
  const RentalOrderTimeline({
    required this.orderId,
    this.audience = RentalAudience.business,
    super.key,
  });

  final String orderId;
  final RentalAudience audience;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return ref
        .watch(rentalOrderHistoryProvider(orderId, audience))
        .when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LinearProgressIndicator(),
          ),
          error: (error, _) => Text(
            'Could not load the history: $error',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
          data: (steps) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('History', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              if (steps.isEmpty)
                Text('No steps recorded yet.', style: theme.textTheme.bodySmall)
              else
                for (final (index, step) in steps.indexed)
                  _Step(step: step, isLast: index == steps.length - 1),
            ],
          ),
        );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.step, required this.isLast});

  final RentalOrderEvent step;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colour = AppColors.status(
      rentalStatusTone(step.tone),
      theme.brightness,
    );

    return IntrinsicHeight(
      key: ValueKey('history-${step.id}'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // A dot per step on a line down the side: the order reads as one story.
          SizedBox(
            width: 20,
            child: Column(
              children: [
                const SizedBox(height: 4),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: colour,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: theme.colorScheme.outlineVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${step.onAddOn ? 'Extra pieces · ' : ''}${step.title} · '
                    '${step.amount == null ? step.quantity : [rupees(step.amount!), ?step.paymentMethodName].join(' · ')}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${formatDayMonth(step.at)}, ${formatTime(step.at)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
