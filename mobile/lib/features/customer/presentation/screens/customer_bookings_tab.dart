import 'package:flutter/material.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/features/booking/domain/entities/booking.dart';
import 'package:zuno/features/booking/presentation/providers/customer_bookings_notifier.dart';
import 'package:zuno/features/booking/presentation/widgets/booking_status_chip.dart';
import 'package:zuno/features/customer/presentation/screens/customer_booking_detail_screen.dart';
import 'package:zuno/shared/widgets/call_icon_button.dart';
import 'package:zuno/shared/widgets/error_banner.dart';
import 'package:zuno/shared/widgets/message_icon_button.dart';
import 'package:zuno/shared/widgets/status_with_actions.dart';
import 'package:zuno/core/router/push_screen.dart';

class CustomerBookingsTab extends ConsumerWidget {
  const CustomerBookingsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(customerBookingsProvider);

    return bookingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ErrorBanner(message: error.toString()),
        ),
      ),
      data: (bookings) {
        if (bookings.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'You have no bookings yet. Search for a service to get started.',
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => ref.refresh(customerBookingsProvider.future),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: bookings.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) =>
                _BookingCard(booking: bookings[index]),
          ),
        );
      },
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Laid out like the business's order card, so one order looks the same from both ends: the
    // text on the left, and on the right the status, a gap, then the call button. A plain row
    // rather than a ListTile, whose fixed height squeezed the button up against the status.
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => pushScreen(context, CustomerBookingDetailScreen(booking: booking)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.variantName ?? booking.serviceName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (booking.variantName != null)
                      Text(
                        booking.serviceName,
                        style: theme.textTheme.bodySmall,
                      ),
                    Text(
                      booking.businessName,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${formatDate(booking.scheduledDate)} · ${formatTime(booking.scheduledDate)}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusWithActions(
                status: BookingStatusChip(order: booking),
                actions: [
                  // Message and call the business once it has confirmed the order — the same two
                  // buttons the business has on its side. The business is who the customer deals
                  // with; workers are never contacted directly.
                  if (booking.canBeMessaged)
                    MessageIconButton(
                      bookingId: booking.id,
                      title: booking.variantName ?? booking.serviceName,
                      // The business, since this is the customer reading it.
                      counterpartName: booking.businessName,
                      tooltip: 'Message business',
                      iconSize: 22,
                    ),
                  if (booking.canBeCalled && booking.businessPhone != null)
                    CallIconButton(
                      phoneNumber: booking.businessPhone!,
                      tooltip: 'Call business',
                      iconSize: 22,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
