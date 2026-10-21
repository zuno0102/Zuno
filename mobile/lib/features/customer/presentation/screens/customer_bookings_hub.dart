import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/features/booking/presentation/providers/booking_message_providers.dart';
import 'package:zuno/features/booking/presentation/providers/customer_bookings_notifier.dart';
import 'package:zuno/features/customer/presentation/screens/customer_bookings_tab.dart';
import 'package:zuno/features/customer/presentation/screens/customer_chat_tab.dart';

/// The customer's orders and the conversations about them, under one bottom tab.
///
/// Every chat belongs to an order, so they sit side by side here — "Bookings" and "Messages" — rather
/// than as two bottom tabs. Each top tab carries its own count, so it is still plain which side has
/// something new.
class CustomerBookingsHub extends ConsumerStatefulWidget {
  const CustomerBookingsHub({super.key, this.initialTab = bookingsTab});

  static const bookingsTab = 0;
  static const messagesTab = 1;

  /// Which top tab to open on.
  final int initialTab;

  @override
  ConsumerState<CustomerBookingsHub> createState() =>
      _CustomerBookingsHubState();
}

class _CustomerBookingsHubState extends ConsumerState<CustomerBookingsHub>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: 2,
    vsync: this,
    initialIndex: widget.initialTab,
  );

  @override
  void didUpdateWidget(CustomerBookingsHub oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Asked to open on another tab — a notification pointing at the messages, say.
    if (oldWidget.initialTab != widget.initialTab) {
      _tabs.animateTo(widget.initialTab);
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final waiting = ref.watch(customerBookingsNeedingMeCountProvider);
    final unread = ref.watch(unreadChatCountProvider);

    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.surface,
          child: TabBar(
            controller: _tabs,
            tabs: [
              Tab(
                key: const Key('hubBookingsTab'),
                child: _Labelled(text: 'Bookings', count: waiting),
              ),
              Tab(
                key: const Key('hubMessagesTab'),
                child: _Labelled(text: 'Messages', count: unread),
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              const CustomerBookingsTab(),
              // An empty chat list points back to the orders, now one swipe away.
              CustomerChatTab(
                onGoToBookings: () =>
                    _tabs.animateTo(CustomerBookingsHub.bookingsTab),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A tab label with its count beside it, shown only when there is something.
class _Labelled extends StatelessWidget {
  const _Labelled({required this.text, required this.count});

  final String text;
  final int count;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(text),
      if (count > 0) ...[
        const SizedBox(width: 6),
        Badge(label: Text(count > 99 ? '99+' : '$count')),
      ],
    ],
  );
}
