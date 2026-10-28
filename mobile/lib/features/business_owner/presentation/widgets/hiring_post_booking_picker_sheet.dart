import 'package:flutter/material.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/features/booking/domain/entities/booking.dart';
import 'package:zuno/features/booking/presentation/widgets/order_code.dart';

/// Picks the customer order a hiring post is being raised for.
///
/// Shows only orders that can still take crew, with how many people each is short — the number
/// the business is about to advertise for.
class HiringPostBookingPickerSheet extends StatelessWidget {
  const HiringPostBookingPickerSheet({
    required this.bookings,
    this.selectedId,
    super.key,
  });

  final List<Booking> bookings;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
            child: Text(
              'Hire for which order?',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  leading: const Icon(Icons.event_note_outlined),
                  title: const Text('Not linked'),
                  subtitle: const Text('Hiring for my own event'),
                  trailing: selectedId == null
                      ? Icon(Icons.check, color: theme.colorScheme.primary)
                      : null,
                  onTap: () => Navigator.of(context).pop((null,)),
                ),
                if (bookings.isEmpty)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: Text(
                      'No confirmed orders are waiting for crew. Confirm a booking first, or '
                      'leave this unlinked.',
                    ),
                  )
                else
                  for (final booking in bookings)
                    ListTile(
                      title: Row(
                        children: [
                          OrderCode(code: booking.reference, compact: true),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              booking.variantName ?? booking.serviceName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        '${booking.customerName} · '
                        '${formatDate(booking.scheduledDate.toLocal())}\n'
                        // A crew size of 0 means it has not been agreed yet, so there is no
                        // "how many more" to state — subtracting would print a negative.
                        '${booking.requiredWorkerCount < 1 ? 'Crew size to be agreed' : 'Needs ${booking.requiredWorkerCount - booking.activeWorkerCount} more of ${booking.requiredWorkerCount}'}',
                      ),
                      isThreeLine: true,
                      trailing: booking.id == selectedId
                          ? Icon(Icons.check, color: theme.colorScheme.primary)
                          : null,
                      onTap: () => Navigator.of(context).pop((booking,)),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
