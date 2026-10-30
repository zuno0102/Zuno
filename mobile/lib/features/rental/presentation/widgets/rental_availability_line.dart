import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/features/rental/domain/entities/rental_customer.dart';
import 'package:zuno/features/rental/domain/entities/rental_stock.dart';
import 'package:zuno/features/rental/presentation/providers/rental_order_providers.dart';

/// "300 available for 1 Nov – 3 Nov" under a booking's quantity, red with "Only 300 available"
/// once the quantity asks for more. Shown while the booking is being filled in, before saving.
///
/// The form disables saving with [isOverLimit] — the server checks again on save, in case someone
/// booked the last pieces meanwhile.
class RentalAvailabilityLine extends ConsumerWidget {
  const RentalAvailabilityLine({
    required this.itemId,
    required this.start,
    required this.end,
    required this.quantity,
    this.audience = RentalAudience.business,
    super.key,
  });

  /// Whose booking it is — a customer may only ask about items shown to customers.
  final RentalAudience audience;

  final String itemId;
  final DateTime start;
  final DateTime end;
  final int quantity;

  /// Whether [quantity] is more than the dates leave — false until the answer is in.
  static bool isOverLimit(
    WidgetRef ref, {
    required String itemId,
    required DateTime start,
    required DateTime end,
    required int quantity,
    RentalAudience audience = RentalAudience.business,
  }) {
    final available = ref
        .watch(rentalAvailabilityProvider(itemId, start, end, audience))
        .value
        ?.available;
    return available != null && quantity > available;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dates = formatDayMonth(start) == formatDayMonth(end)
        ? formatDayMonth(start)
        : '${formatDayMonth(start)} – ${formatDayMonth(end)}';

    return ref
        .watch(rentalAvailabilityProvider(itemId, start, end, audience))
        .when(
          loading: () => Text(
            'Checking what is free for $dates…',
            style: theme.textTheme.bodySmall,
          ),
          error: (error, _) => Text(
            'Could not check what is free: $error',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
          data: (availability) {
            final over = quantity > availability.available;
            final colour = AppColors.status(
              over ? StatusTone.danger : StatusTone.success,
              theme.brightness,
            );
            return Row(
              key: const ValueKey('availability-line'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  over
                      ? Icons.error_outline_rounded
                      : Icons.check_circle_outline,
                  size: 18,
                  color: colour,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _message(availability, dates, over),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colour,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          },
        );
  }

  String _message(RentalAvailability availability, String dates, bool over) {
    if (availability.total > 0 &&
        availability.available == 0 &&
        availability.held == 0) {
      return 'This item is switched off, so it cannot be booked.';
    }
    return over
        ? 'Only ${availability.available} available for $dates — '
              'you asked for $quantity.'
        : '${availability.available} available for $dates.';
  }
}
