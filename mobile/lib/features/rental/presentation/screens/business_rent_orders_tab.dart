import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/router/push_screen.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/features/rental/domain/entities/rental_customer.dart';
import 'package:zuno/features/rental/domain/entities/rental_stock.dart';
import 'package:zuno/features/rental/presentation/providers/rental_order_providers.dart';
import 'package:zuno/features/rental/presentation/providers/rental_providers.dart';
import 'package:zuno/features/rental/presentation/screens/rental_order_chat_screen.dart';
import 'package:zuno/features/rental/presentation/widgets/rental_order_card.dart';
import 'package:zuno/features/rental/presentation/widgets/rental_order_form_sheet.dart';
import 'package:zuno/shared/widgets/counted_tab_label.dart';
import 'package:zuno/shared/widgets/empty_state.dart';
import 'package:zuno/shared/widgets/error_banner.dart';
import 'package:zuno/shared/widgets/filter_chip_bar.dart';

/// Orders › Rent: the rent side of the business's orders, laid out like the service side —
/// **Bookings** (every rent order, by status), **Status management** (what needs a step next), and
/// **Messages** (conversations with customers about rent orders).
class BusinessRentOrdersTab extends StatelessWidget {
  const BusinessRentOrdersTab({super.key});

  @override
  Widget build(BuildContext context) =>
      const RentOrdersTabs(audience: RentalAudience.business);
}

/// The rent orders screen for either side: the business gets Bookings · Status management ·
/// Messages; a customer gets **Rentals** · **Messages** — the same lists, cards and chats.
class RentOrdersTabs extends ConsumerWidget {
  const RentOrdersTabs({required this.audience, super.key});

  final RentalAudience audience;

  bool get _isBusiness => audience == RentalAudience.business;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toAct =
        ref
            .watch(rentalOrdersProvider(null, audience))
            .value
            ?.where(rentalNeedsBusinessStep)
            .length ??
        0;
    final unread = ref.watch(rentalUnreadMessageCountProvider(audience));

    final tabs = <(Widget, Widget)>[
      if (_isBusiness) ...[
        (
          const CountedTabLabel(label: 'Bookings', count: 0),
          const _BookingsTab(),
        ),
        (
          CountedTabLabel(label: 'Status management', count: toAct),
          const _OrderList(
            status: null,
            audience: RentalAudience.business,
            onlyActionable: true,
            showActions: true,
            emptyIcon: Icons.task_alt_outlined,
            emptyTitle: 'Nothing to do right now',
            emptyMessage:
                'Booked orders to send out, rented items to bring back and money to '
                'give back show here.',
          ),
        ),
      ] else
        (
          const CountedTabLabel(label: 'Rentals', count: 0),
          const _OrderList(
            status: null,
            audience: RentalAudience.customer,
            emptyIcon: Icons.chair_outlined,
            emptyTitle: 'No rentals yet',
            emptyMessage:
                'Find chairs, tents, tools and more on the Rent home and book them '
                'for your dates.',
          ),
        ),
      (
        CountedTabLabel(label: 'Messages', count: unread),
        _MessagesTab(audience: audience),
      ),
    ];

    // The same bar, heights and text as the Service side's orders (ListTabBar).
    return DefaultTabController(
      length: tabs.length,
      child: Column(
        children: [
          ListTabBar(labels: [for (final t in tabs) t.$1]),
          Expanded(child: TabBarView(children: [for (final t in tabs) t.$2])),
        ],
      ),
    );
  }
}

/// Every rent order of the business's, narrowed by a status chip. The chips' names, colours and
/// counts come from the server's status table.
class _BookingsTab extends ConsumerStatefulWidget {
  const _BookingsTab();

  @override
  ConsumerState<_BookingsTab> createState() => _BookingsTabState();
}

class _BookingsTabState extends ConsumerState<_BookingsTab>
    with AutomaticKeepAliveClientMixin {
  /// Null for every status.
  String? _status;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final counts =
        ref.watch(rentalOrderCountsProvider).value ??
        const <RentalOrderStatusCount>[];
    // "Refund due" cuts across statuses, so it is not added in twice.
    final total = counts
        .where((c) => c.countsInAll)
        .fold<int>(0, (sum, c) => sum + c.count);

    return Scaffold(
      // Orders that come by phone, at the shop or by message; app orders arrive on their own.
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showRentalOrderFormSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Offline order'),
      ),
      body: Column(
        children: [
          // The Service side's chip row (FilterChipBar): "All 8 · Booked 3 · …".
          FilterChipBar(
            chips: [
              CountChip(
                label: 'All',
                count: total,
                selected: _status == null,
                onSelected: () => setState(() => _status = null),
              ),
              for (final c in counts)
                // Money owed back shows only while there is some, or while it is the chosen filter.
                if (!c.isRefundDue || c.count > 0 || _status == c.status)
                  CountChip(
                    key: ValueKey('rent-filter-${c.status}'),
                    label: c.name,
                    count: c.count,
                    selected: _status == c.status,
                    onSelected: () => setState(() => _status = c.status),
                  ),
            ],
          ),
          Expanded(
            child: _status == null
                ? const _OrderList(
                    status: null,
                    audience: RentalAudience.business,
                    emptyIcon: Icons.assignment_outlined,
                    emptyTitle: 'No rent orders yet',
                    emptyMessage:
                        'Tap "Offline order" for a customer who phoned or came in, or wait '
                        'for customers to book from the app.',
                  )
                : _status == RentalOrderStatusCount.refundDue
                ? _OrderList(
                    status: _status,
                    audience: RentalAudience.business,
                    emptyIcon: Icons.undo_rounded,
                    emptyTitle: 'Nothing to give back',
                    emptyMessage:
                        'Cancelled orders that still owe the customer money show here.',
                  )
                : _OrderList(
                    status: _status,
                    audience: RentalAudience.business,
                    emptyIcon: Icons.filter_list_off_outlined,
                    emptyTitle: 'No orders in this status',
                    emptyMessage:
                        'Orders will appear here when they reach this status.',
                  ),
          ),
        ],
      ),
    );
  }
}

class _OrderList extends ConsumerWidget {
  const _OrderList({
    required this.status,
    required this.audience,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptyMessage,
    this.onlyActionable = false,
    this.showActions = false,
  });

  final String? status;
  final RentalAudience audience;

  /// What an empty list says, in the Service side's EmptyState.
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyMessage;
  final bool onlyActionable;
  final bool showActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(rentalOrdersProvider(status, audience));

    return ordersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ErrorBanner(message: error.toString()),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => reloadRentals(ref),
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
      data: (all) {
        final orders = onlyActionable
            ? all.where(rentalNeedsBusinessStep).toList()
            : all;

        return RefreshIndicator(
          onRefresh: () async {
            reloadRentals(ref);
            await ref.read(rentalOrdersProvider(status, audience).future);
          },
          child: orders.isEmpty
              // Scrollable even when empty, so pull-to-refresh still works here.
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    EmptyState(
                      icon: emptyIcon,
                      title: emptyTitle,
                      message: emptyMessage,
                    ),
                  ],
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  // The Service side's spacing; room at the foot for "Offline order".
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                  itemCount: orders.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => RentalOrderCard(
                    order: orders[index],
                    audience: audience,
                    showActions: showActions,
                  ),
                ),
        );
      },
    );
  }
}

/// Conversations about rent orders, latest first, unread ones marked — with customers for the
/// business, with businesses for a customer.
class _MessagesTab extends ConsumerWidget {
  const _MessagesTab({required this.audience});

  final RentalAudience audience;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threadsAsync = ref.watch(rentalOrderThreadsProvider(audience));
    final theme = Theme.of(context);
    final isBusiness = audience == RentalAudience.business;

    return threadsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ErrorBanner(message: error.toString()),
        ),
      ),
      data: (threads) => RefreshIndicator(
        onRefresh: () =>
            ref.refresh(rentalOrderThreadsProvider(audience).future),
        child: threads.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  EmptyState(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'No messages yet',
                    message: isBusiness
                        ? 'When a customer writes about a rent order, the conversation '
                              'shows here.'
                        : 'Open a rental and message the business about it.',
                  ),
                ],
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: threads.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final t = threads[index];
                  final unread = t.unreadCount > 0;
                  // The other side's name: the customer for the business, the business for a customer.
                  final counterpart = isBusiness
                      ? t.customerName
                      : (t.businessName ?? 'Business');
                  final lastIsMine = isBusiness
                      ? !t.lastFromCustomer
                      : t.lastFromCustomer;
                  return ListTile(
                    key: ValueKey('rent-thread-${t.rentalOrderId}'),
                    leading: CircleAvatar(
                      child: Text(
                        counterpart.isEmpty
                            ? '?'
                            : counterpart.characters.first.toUpperCase(),
                      ),
                    ),
                    title: Text(
                      counterpart,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      '${t.quantity} × ${t.itemName}\n'
                      '${lastIsMine ? 'You: ' : ''}${t.lastMessage}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    isThreeLine: true,
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          relativeDayLabel(t.lastMessageAt),
                          style: theme.textTheme.labelSmall,
                        ),
                        if (unread) ...[
                          const SizedBox(height: 4),
                          Badge(label: Text('${t.unreadCount}')),
                        ],
                      ],
                    ),
                    onTap: () async {
                      // The order behind the thread, so the chat can lead to it.
                      final order = await ref
                          .read(
                            rentalOrderProvider(
                              t.rentalOrderId,
                              audience,
                            ).future,
                          )
                          .catchError(
                            (_) => RentalOrder(
                              id: t.rentalOrderId,
                              customerName: t.customerName,
                              businessName: t.businessName,
                              itemName: t.itemName,
                              quantity: t.quantity,
                              startDate: t.lastMessageAt,
                              endDate: t.lastMessageAt,
                              deliveryAddress: '',
                              status: '',
                              statusName: '',
                              statusTone: 'waiting',
                              isOut: false,
                            ),
                          );
                      if (context.mounted) {
                        pushScreen(
                          context,
                          RentalOrderChatScreen(
                            order: order,
                            audience: audience,
                          ),
                        );
                      }
                    },
                  );
                },
              ),
      ),
    );
  }
}
