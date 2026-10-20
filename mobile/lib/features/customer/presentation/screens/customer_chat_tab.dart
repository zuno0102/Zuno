import 'package:flutter/material.dart';
import 'package:zuno/features/booking/presentation/widgets/booking_threads_list.dart';
import 'package:zuno/shared/widgets/empty_state.dart';

/// The customer's conversations, one per booking.
///
/// The list itself is [BookingThreadsList], shared with the business, which reads a thread correctly
/// from either end. All this adds is the customer's way out of an empty list: a thread exists only
/// once somebody has written, so there is nothing to show until then and the way forward is the
/// booking it would belong to.
class CustomerChatTab extends StatelessWidget {
  const CustomerChatTab({required this.onGoToBookings, super.key});

  final VoidCallback onGoToBookings;

  @override
  Widget build(BuildContext context) {
    return BookingThreadsList(
      emptyState: EmptyState(
        icon: Icons.chat_bubble_outline,
        title: 'No messages yet',
        message:
            'Open a booking and send the business a message. Anything you '
            'agree there stays with that booking.',
        actionLabel: 'Go to my bookings',
        onAction: onGoToBookings,
      ),
    );
  }
}
