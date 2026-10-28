import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/shared/widgets/app_messages.dart';
import 'package:zuno/features/booking/domain/entities/booking.dart';
import 'package:zuno/features/booking/presentation/providers/business_bookings_notifier.dart';
import 'package:zuno/features/booking/presentation/widgets/booking_threads_list.dart';
import 'package:zuno/features/booking/presentation/providers/booking_message_providers.dart';
import 'package:zuno/features/business_owner/presentation/screens/business_booking_detail_screen.dart';
import 'package:zuno/features/work_chat/presentation/providers/work_chat_providers.dart';
import 'package:zuno/features/work_chat/presentation/widgets/work_threads_list.dart';
import 'package:zuno/shared/widgets/empty_state.dart';
import 'package:zuno/core/router/push_screen.dart';
import 'package:zuno/features/business_owner/presentation/screens/business_order_filters.dart';

/// Every order with a conversation on it.
///
/// The same list the customer sees, read from the other end: the server decides who the counterpart
/// is, so nothing here knows which side it is on.
class BusinessMessagesTab extends ConsumerStatefulWidget {
  const BusinessMessagesTab({super.key});

  @override
  ConsumerState<BusinessMessagesTab> createState() =>
      _BusinessMessagesTabState();
}

/// Who the business is reading: its customers (one chat per order) or its workers (one chat per
/// worker). The business is the go-between, so it is the one side that talks to both.
enum _Audience { customers, workers }

class _BusinessMessagesTabState extends ConsumerState<BusinessMessagesTab> {
  _Audience _audience = _Audience.customers;

  @override
  Widget build(BuildContext context) {
    final customerUnread = ref.watch(unreadChatCountProvider);
    final workerUnread = ref.watch(unreadWorkChatCountProvider);

    // Spaced like the status chips a tab away — "Workers 2", not "Workers (2)". A zero is left
    // off entirely rather than shown dimmed the way an empty booking stage is: nothing unread is
    // the ordinary resting state here, so "Customers 0" would sit on the bar saying nothing.
    String label(String name, int unread) =>
        unread > 0 ? '$name $unread' : name;

    Widget audienceChip(String name, int unread, _Audience value) => ChoiceChip(
      label: Text(label(name, unread)),
      selected: _audience == value,
      showCheckmark: false,
      onSelected: (_) => setState(() => _audience = value),
    );

    // No conversations on either side: nothing to choose between, so the chips would only push the
    // empty state down. Shown the moment either side has a thread, the way Bookings shows its
    // filters only once there is something to filter.
    final hasAnyThread =
        (ref.watch(bookingThreadsProvider).value?.isNotEmpty ?? false) ||
        (ref.watch(workThreadsProvider).value?.isNotEmpty ?? false);

    return Column(
      children: [
        if (hasAnyThread)
          OrderFilterChipBar(
            key: const Key('businessMessagesAudience'),
            chips: [
              audienceChip('Customers', customerUnread, _Audience.customers),
              audienceChip('Workers', workerUnread, _Audience.workers),
            ],
          ),
        Expanded(
          child: _audience == _Audience.customers
              ? const _CustomerThreads()
              : const WorkThreadsList(
                  emptyState: EmptyState(
                    icon: Icons.engineering_outlined,
                    title: 'No messages with workers yet',
                    message:
                        'Message a worker from the crew on an order or a hiring post. '
                        'Once they have taken a job on, you can message and call them.',
                  ),
                ),
        ),
      ],
    );
  }
}

/// Conversations with customers, one per order.
class _CustomerThreads extends ConsumerWidget {
  const _CustomerThreads();

  /// Opens the order a conversation is about.
  ///
  /// The chat carries only the booking's id, and the order screen wants the whole booking, so it
  /// is read back out of the list the business already has loaded. A thread can outlive the order
  /// it belongs to — a cancelled one drops out of that list while its messages stay — so a miss
  /// says so plainly rather than pushing a screen with nothing on it.
  void _openOrder(BuildContext context, WidgetRef ref, String bookingId) {
    final orders =
        ref.read(businessBookingsProvider).value ?? const <Booking>[];
    final order = orders.where((o) => o.id == bookingId).firstOrNull;

    if (order == null) {
      context.showInfoMessage(
        'That order is no longer in your list, so it cannot be opened.',
      );
      return;
    }

    pushScreen(context, BusinessBookingDetailScreen(booking: order));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BookingThreadsList(
      onOpenOrder: (chatContext, bookingId) =>
          _openOrder(chatContext, ref, bookingId),
      emptyState: EmptyState(
        icon: Icons.chat_bubble_outline,
        title: 'No messages yet',
        message:
            'Open an order and send the customer a message. Anything you '
            'agree there stays with that order.',
        actionLabel: 'Go to an order',
        // A thread exists only once somebody has written, so an empty list has to point at the
        // place a conversation can be started rather than leave them here. One tab back, where
        // every order the business has taken on now carries a message button.
        //
        // Looked up from this context, which is inside the controller. Asking from
        // BusinessOrdersTab.build would be asking from above it, and `of` throws rather than
        // returning null.
        onAction: () => DefaultTabController.of(context).animateTo(0),
      ),
    );
  }
}
