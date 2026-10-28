import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/features/booking/domain/entities/booking.dart';
import 'package:zuno/features/booking/presentation/providers/business_bookings_notifier.dart';
import 'package:zuno/features/catalog/domain/entities/order_stage.dart';
import 'package:zuno/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:zuno/features/booking/presentation/providers/booking_message_providers.dart';
import 'package:zuno/features/hiring_post/domain/entities/hiring_post.dart';
import 'package:zuno/features/hiring_post/presentation/providers/business_hiring_posts_notifier.dart';
import 'package:zuno/features/notifications/presentation/providers/notification_providers.dart';
import 'package:zuno/features/work_chat/presentation/providers/work_chat_providers.dart';
import 'package:zuno/shared/widgets/empty_state.dart';
import 'package:zuno/shared/widgets/error_banner.dart';
import 'package:zuno/features/business_owner/presentation/screens/business_messages_tab.dart';
import 'package:zuno/features/business_owner/presentation/screens/business_order_card.dart';
import 'package:zuno/features/business_owner/presentation/screens/business_order_filters.dart';
import 'package:zuno/features/business_owner/presentation/screens/business_order_step_cards.dart';

/// Every booking customers have made, and everything waiting on the business to act.
///
/// Two tabs because they answer two different questions. "What have I got on?" is read down a
/// list; "what do I have to do next?" is worked one job at a time. They used to be the same
/// screen, which meant a card had to show its whole history and its next action at once — and a
/// business scanning for the day's work read past four status lines on every finished job.
class BusinessOrdersTab extends StatelessWidget {
  const BusinessOrdersTab({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: const TabBar(
              // Fixed thirds, not a scrolling bar. A scrolling bar sized itself to the labels and
              // pushed Messages off the right edge of a phone, where it had to be swiped into
              // view — which is the same "there is nowhere to message from" this tab exists to
              // answer. Three equal thirds keep it on screen.
              //
              // Tight side padding and room for two lines, so a long name with its count after it
              // wraps ("Status / management 2") rather than being cut off.
              labelPadding: EdgeInsets.symmetric(horizontal: 4),
              tabs: [
                Tab(height: 56, child: _NewOrdersTabLabel()),
                Tab(height: 56, child: _WorkStepsTabLabel()),
                Tab(height: 56, child: _MessagesTabLabel()),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                _CustomerOrdersTab(),
                _StatusManagementTab(),
                BusinessMessagesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// New orders the business has not opened yet: placed by a customer, still waiting on the
/// business, and not looked at since.
///
/// Read like unread mail. Five new requests read "Bookings 5"; opening one makes it 4. The
/// [unread] set is what the business has been told about and not yet opened (the same set the
/// bell counts), and opening an order takes it out — so the number falls the moment an order is
/// read, and rises again if the customer does something new on it, such as answering an offer.
///
/// One the business has already made an offer on is waiting on the customer instead, so it is not
/// counted at all.
int newOrdersAwaitingBusiness(List<Booking> orders, Set<String> unread) {
  bool unopened(Booking o) => UnreadNotificationTargets.bookingTargets.any(
    (target) => unread.contains(UnreadNotificationTargets.keyFor(target, o.id)),
  );

  return orders
      .where(
        (o) =>
            o.isPending &&
            !o.awaitingTheirReply(viewerIsBusiness: true) &&
            unopened(o),
      )
      .length;
}

/// Jobs whose next step can be taken right now: work to start on the day, or to mark completed.
///
/// Exactly the cards on the Status management tab that are showing a Start or Complete button,
/// for customer orders and the business's own events alike.
int workStepsReady(
  List<Booking> orders,
  List<HiringPost> posts, {
  DateTime? now,
}) {
  final orderSteps = orders
      .where((o) => o.canStartWork(now: now) || o.canCompleteWork)
      .length;
  final eventSteps = posts
      .where(
        // The same events the tab lists: the business's own, and not lapsed.
        (p) =>
            p.bookingId == null &&
            !p.isLapsed(now: now) &&
            (p.canStartWork(now: now) || p.canMarkComplete(now: now)),
      )
      .length;
  return orderSteps + eventSteps;
}

/// How many items sit in each of [filters], keyed by stage code, every filter present even at zero.
///
/// [stageCodes] is each item's stage as the server decided it — an order's or an own event's
/// `stage`. Nothing here knows any stage by name: the filters are whatever the server lists.
Map<String, int> countByStage(
  Iterable<String> stageCodes,
  List<OrderStage> filters,
) {
  final counts = {for (final stage in filters) stage.code: 0};
  for (final code in stageCodes) {
    if (counts.containsKey(code)) counts[code] = counts[code]! + 1;
  }
  return counts;
}

/// "Bookings", with the new orders waiting on the business written after it.
class _NewOrdersTabLabel extends ConsumerWidget {
  const _NewOrdersTabLabel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders =
        ref.watch(businessBookingsProvider).value ?? const <Booking>[];
    final unread =
        ref.watch(unreadNotificationTargetsProvider).value ?? const <String>{};
    return _CountedTabLabel(
      label: 'Bookings',
      count: newOrdersAwaitingBusiness(orders, unread),
    );
  }
}

/// "Status management", with the jobs ready to start or finish written after it.
class _WorkStepsTabLabel extends ConsumerWidget {
  const _WorkStepsTabLabel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Each half selected on its own, so the label rebuilds only when a number changes.
    final orderSteps = ref.watch(
      businessBookingsProvider.select(
        (orders) => workStepsReady(orders.value ?? const [], const []),
      ),
    );
    final eventSteps = ref.watch(
      businessHiringPostsProvider.select(
        (posts) => workStepsReady(const [], posts.value ?? const []),
      ),
    );
    return _CountedTabLabel(
      label: 'Status management',
      count: orderSteps + eventSteps,
    );
  }
}

/// "Messages", carrying the number of unread ones.
///
/// Watched here rather than on [BusinessOrdersTab] so a message arriving repaints two words
/// instead of both order lists — and so the bar above can stay const.
class _MessagesTabLabel extends ConsumerWidget {
  const _MessagesTabLabel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Customers and workers together: everything waiting to be read in this tab.
    return _CountedTabLabel(
      label: 'Messages',
      count:
          ref.watch(unreadChatCountProvider) +
          ref.watch(unreadWorkChatCountProvider),
    );
  }
}

/// A tab's name with its count written after it — "Messages 1" — never on top of it.
///
/// It was a corner badge, and on a phone the badge sat over the last letters of the name. The
/// count now follows the name as a small pill in the same line of text, so a long name wraps
/// with its count rather than either one being hidden.
class _CountedTabLabel extends StatelessWidget {
  const _CountedTabLabel({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) {
      return Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }

    // The last word and the pill travel as one piece. Left as separate pieces, a name that filled
    // the tab let the pill drop onto a line of its own; held together, the name wraps before its
    // last word and the count stays after it: "From / customers 1".
    final cut = label.lastIndexOf(' ');
    final head = cut < 0 ? '' : label.substring(0, cut + 1);
    final lastWord = cut < 0 ? label : label.substring(cut + 1);

    return Semantics(
      // Read as one thing by a screen reader: "Messages, 1 new".
      label: '$label, $count new',
      excludeSemantics: true,
      child: Text.rich(
        TextSpan(
          text: head,
          children: [
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Inherits the tab's own text style, so it reads as part of the name. Allowed to
                  // shorten only on a screen too narrow for the word itself — the count is the
                  // part that must stay readable.
                  Flexible(
                    child: Text(
                      lastWord,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  _CountPill(key: ValueKey('tabCount:$label'), count: count),
                ],
              ),
            ),
          ],
        ),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// The small red number after a tab's name.
class _CountPill extends StatelessWidget {
  const _CountPill({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // The app's badge colours (the role's own colour, set in AppTheme), so this pill matches every
    // other count in the app rather than borrowing the red kept for errors.
    final background =
        theme.badgeTheme.backgroundColor ?? theme.colorScheme.primary;
    final foreground =
        theme.badgeTheme.textColor ?? theme.colorScheme.onPrimary;
    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        // Capped, so the pill stays a pill. Past this is "a lot", and the list is where the real
        // number lives.
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        // The theme's small label style, the same one Material's own badges use.
        style: theme.textTheme.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------
// Tab 1 — what came in
// ---------------------------------------------------------------------------------------------

/// The bookings themselves, newest arrangement first, split by status. One status each, and
/// nothing to press.
///
/// A row of filters with counts sits on top — All, then each stage the server lists for this tab —
/// because one mixed list made a business read past every finished and cancelled job to find the
/// new ones.
class _CustomerOrdersTab extends ConsumerStatefulWidget {
  const _CustomerOrdersTab();

  @override
  ConsumerState<_CustomerOrdersTab> createState() => _CustomerOrdersTabState();
}

class _CustomerOrdersTabState extends ConsumerState<_CustomerOrdersTab> {
  /// The stage code being shown, or null for All. Kept across refreshes; an emptied stage stays
  /// selected and says so, rather than silently jumping back to All.
  String? _stageCode;

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(businessBookingsProvider);
    final stages = ref.watch(orderStagesProvider).value ?? const <OrderStage>[];
    final filters = stages.onBookings;

    return ordersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ErrorBanner(message: error.toString()),
        ),
      ),
      data: (orders) {
        if (orders.isEmpty) {
          return const EmptyState(
            icon: Icons.assignment_outlined,
            title: 'No bookings yet',
            message: 'Bookings customers make with you will appear here.',
          );
        }

        final counts = countByStage(orders.map((o) => o.stage), filters);
        final shown = _stageCode == null
            ? orders
            : orders.where((o) => o.stage == _stageCode).toList();

        return Column(
          children: [
            OrderStatusFilterBar(
              filters: filters,
              total: orders.length,
              counts: counts,
              selected: _stageCode,
              onSelected: (code) => setState(() => _stageCode = code),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => ref.refresh(businessBookingsProvider.future),
                child: shown.isEmpty
                    // Scrollable even when empty, so pull-to-refresh still works here.
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          EmptyState(
                            icon: Icons.filter_list_off_outlined,
                            title:
                                'No ${stages.resolve(_stageCode!).label.toLowerCase()} bookings',
                            message:
                                'Bookings will appear here when they reach this status.',
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        itemCount: shown.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) =>
                            BusinessOrderCard(order: shown[index]),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------------------------
// Tab 2 — what to do next
// ---------------------------------------------------------------------------------------------

/// Every job the business still has to move along, each showing only its next step.
///
/// Covers both kinds of work: customer orders, and the business's own events run through a
/// standalone hiring post. Leaving the second kind out would strand it — a post with no order
/// behind it would have nowhere left to be started, finished or paid.
///
/// Split by stage like the Bookings tab — All, then each stage the server lists for this tab — with
/// orders and own events counted together, since both are work the business is moving along.
class _StatusManagementTab extends ConsumerStatefulWidget {
  const _StatusManagementTab();

  @override
  ConsumerState<_StatusManagementTab> createState() =>
      _StatusManagementTabState();
}

class _StatusManagementTabState extends ConsumerState<_StatusManagementTab> {
  /// The stage code being shown, or null for All.
  String? _stageCode;

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(businessBookingsProvider);
    final postsAsync = ref.watch(businessHiringPostsProvider);
    final stages = ref.watch(orderStagesProvider).value ?? const <OrderStage>[];

    if (ordersAsync.hasError || postsAsync.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ErrorBanner(
            message: (ordersAsync.error ?? postsAsync.error).toString(),
          ),
        ),
      );
    }

    if (ordersAsync.isLoading || postsAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final orders = ordersAsync.value ?? const <Booking>[];
    final posts = postsAsync.value ?? const <HiringPost>[];

    // A cancelled order has nothing left to manage, and one still awaiting confirmation is
    // answered from the other tab — this list is work the business has already taken on.
    final live = orders.where((o) => !o.isPending && !o.isCancelled).toList()
      ..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));

    // Own events only. A post raised for an order is managed through that order, so listing it
    // here as well would ask the business to finish the same job twice.
    final ownEvents =
        posts.where((p) => p.bookingId == null && !p.isLapsed()).toList()
          ..sort((a, b) => a.eventDate.compareTo(b.eventDate));

    if (live.isEmpty && ownEvents.isEmpty) {
      return const EmptyState(
        icon: Icons.checklist_rtl_outlined,
        title: 'Nothing to manage',
        message:
            'Once you accept an order, or post your own job, its next step appears here.',
      );
    }

    // Both kinds of work carry a stage the server decided, in the same codes.
    final filters = stages.onWork;
    final counts = countByStage([
      ...live.map((o) => o.stage),
      ...ownEvents.map((p) => p.stage),
    ], filters);

    final shownOrders = _stageCode == null
        ? live
        : live.where((o) => o.stage == _stageCode).toList();
    final shownEvents = _stageCode == null
        ? ownEvents
        : ownEvents.where((p) => p.stage == _stageCode).toList();

    return Column(
      children: [
        OrderStatusFilterBar(
          filters: filters,
          total: live.length + ownEvents.length,
          counts: counts,
          selected: _stageCode,
          onSelected: (code) => setState(() => _stageCode = code),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              await Future.wait(<Future<void>>[
                ref.refresh(businessBookingsProvider.future),
                ref.refresh(businessHiringPostsProvider.future),
              ]);
            },
            child: shownOrders.isEmpty && shownEvents.isEmpty
                // Scrollable even when empty, so pull-to-refresh still works here.
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      EmptyState(
                        icon: Icons.filter_list_off_outlined,
                        title:
                            'Nothing ${stages.resolve(_stageCode!).label.toLowerCase()}',
                        message:
                            'Work will appear here when it reaches this status.',
                      ),
                    ],
                  )
                : _workList(context, shownOrders, shownEvents, posts),
          ),
        ),
      ],
    );
  }

  Widget _workList(
    BuildContext context,
    List<Booking> live,
    List<HiringPost> ownEvents,
    List<HiringPost> posts,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: [
        for (final order in live) ...[
          OrderStepCard(order: order, posts: posts),
          const SizedBox(height: 10),
        ],
        if (ownEvents.isNotEmpty) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 2),
            child: Text(
              'YOUR OWN EVENTS',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                letterSpacing: 0.8,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          for (final post in ownEvents) ...[
            OwnEventStepCard(post: post),
            const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }
}
