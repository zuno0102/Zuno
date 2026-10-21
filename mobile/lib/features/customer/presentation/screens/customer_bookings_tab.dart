import 'package:flutter/material.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/features/booking/domain/entities/booking.dart';
import 'package:zuno/features/booking/presentation/providers/customer_bookings_notifier.dart';
import 'package:zuno/features/booking/presentation/widgets/booking_status_chip.dart';
import 'package:zuno/features/customer/presentation/screens/customer_booking_detail_screen.dart';
import 'package:zuno/shared/widgets/call_icon_button.dart';
import 'package:zuno/shared/widgets/error_banner.dart';

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
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          booking.variantName ?? booking.serviceName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            if (booking.variantName != null)
              Text(
                booking.serviceName,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            Text(booking.businessName),
            const SizedBox(height: 4),
            Text(
              '${formatDate(booking.scheduledDate)} · ${formatTime(booking.scheduledDate)}',
            ),
          ],
        ),
        isThreeLine: true,
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BookingStatusChip(order: booking),
            if (booking.canBeCalled && booking.businessPhone != null)
              CallIconButton(
                phoneNumber: booking.businessPhone!,
                tooltip: 'Call business',
              ),
          ],
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CustomerBookingDetailScreen(booking: booking),
          ),
        ),
      ),
    );
  }
}
