import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/shared/widgets/app_messages.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/features/booking/domain/entities/booking.dart';
import 'package:zuno/features/booking/domain/entities/booking_worker_assignment.dart';
import 'package:zuno/features/booking/presentation/providers/business_bookings_notifier.dart';
import 'package:zuno/features/booking/presentation/widgets/booking_status_chip.dart';
import 'package:zuno/features/booking/presentation/widgets/booking_crew_list.dart';
import 'package:zuno/features/booking/presentation/widgets/booking_threads_list.dart';
import 'package:zuno/features/booking/presentation/widgets/booking_tracks.dart';
import 'package:zuno/features/booking/presentation/widgets/order_code.dart';
import 'package:zuno/features/booking/presentation/providers/booking_message_providers.dart';
import 'package:zuno/features/business_owner/presentation/screens/business_booking_detail_screen.dart';
import 'package:zuno/features/business_owner/presentation/widgets/crew_member_sheet.dart';
import 'package:zuno/features/business_owner/presentation/widgets/pay_crew_sheet.dart';
import 'package:zuno/features/business_owner/presentation/widgets/post_crew_wage_list.dart';
import 'package:zuno/features/business_owner/presentation/widgets/raise_salary_dialog.dart';
import 'package:zuno/features/hiring_post/domain/entities/hiring_post.dart';
import 'package:zuno/features/hiring_post/domain/entities/hiring_post_application.dart';
import 'package:zuno/features/hiring_post/presentation/providers/business_hiring_posts_notifier.dart';
import 'package:zuno/features/notifications/presentation/providers/notification_providers.dart';
import 'package:zuno/features/work_chat/presentation/providers/work_chat_providers.dart';
import 'package:zuno/features/work_chat/presentation/widgets/work_threads_list.dart';
import 'package:zuno/shared/widgets/call_icon_button.dart';
import 'package:zuno/shared/widgets/empty_state.dart';
import 'package:zuno/shared/widgets/error_banner.dart';
import 'package:zuno/shared/widgets/message_icon_button.dart';
import 'package:zuno/shared/widgets/status_pill.dart';
import 'package:zuno/shared/widgets/status_with_actions.dart';
import 'package:zuno/shared/widgets/status_track.dart';

/// Everything that came in from customers, and everything waiting on the business to act.
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
                _BusinessMessagesTab(),
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
/// Read like unread mail. Five new requests read "From customers 5"; opening one makes it 4. The
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

/// "From customers", with the new orders waiting on the business written after it.
class _NewOrdersTabLabel extends ConsumerWidget {
  const _NewOrdersTabLabel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders =
        ref.watch(businessBookingsProvider).value ?? const <Booking>[];
    final unread =
        ref.watch(unreadNotificationTargetsProvider).value ?? const <String>{};
    return _CountedTabLabel(
      label: 'From customers',
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

/// Every order with a conversation on it.
///
/// The same list the customer sees, read from the other end: the server decides who the counterpart
/// is, so nothing here knows which side it is on.
class _BusinessMessagesTab extends ConsumerStatefulWidget {
  const _BusinessMessagesTab();

  @override
  ConsumerState<_BusinessMessagesTab> createState() =>
      _BusinessMessagesTabState();
}

/// Who the business is reading: its customers (one chat per order) or its workers (one chat per
/// worker). The business is the go-between, so it is the one side that talks to both.
enum _Audience { customers, workers }

class _BusinessMessagesTabState extends ConsumerState<_BusinessMessagesTab> {
  _Audience _audience = _Audience.customers;

  @override
  Widget build(BuildContext context) {
    final customerUnread = ref.watch(unreadChatCountProvider);
    final workerUnread = ref.watch(unreadWorkChatCountProvider);

    String label(String name, int unread) =>
        unread > 0 ? '$name ($unread)' : name;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<_Audience>(
              key: const Key('businessMessagesAudience'),
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: _Audience.customers,
                  icon: const Icon(Icons.person_outline),
                  label: Text(label('Customers', customerUnread)),
                ),
                ButtonSegment(
                  value: _Audience.workers,
                  icon: const Icon(Icons.engineering_outlined),
                  label: Text(label('Workers', workerUnread)),
                ),
              ],
              selected: {_audience},
              onSelectionChanged: (s) => setState(() => _audience = s.first),
            ),
          ),
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
class _CustomerThreads extends StatelessWidget {
  const _CustomerThreads();

  @override
  Widget build(BuildContext context) {
    return BookingThreadsList(
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

// ---------------------------------------------------------------------------------------------
// Tab 1 — what came in
// ---------------------------------------------------------------------------------------------

/// The orders themselves, newest arrangement first. One status each, and nothing to press.
class _CustomerOrdersTab extends ConsumerWidget {
  const _CustomerOrdersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(businessBookingsProvider);

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
            title: 'No orders yet',
            message: 'Orders customers place with you will appear here.',
          );
        }

        return RefreshIndicator(
          onRefresh: () => ref.refresh(businessBookingsProvider.future),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) => _OrderCard(order: orders[index]),
          ),
        );
      },
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final Booking order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final canMessage = order.canBeMessaged;
    final canCall = order.canBeCalled && order.customerPhone != null;

    // A plain row rather than a ListTile. A ListTile takes its height from its text alone, which
    // left the status and the buttons about 62px to share: they were squeezed together and the
    // buttons shrunk below a comfortable tap size. Laid out like this, the card grows to fit
    // whichever side is taller, so the status, a real gap and normal buttons all fit.
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BusinessBookingDetailScreen(booking: order),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // The order code first. A business running three weddings at once needs
                    // something it can say out loud and match against the hiring post it raised.
                    if (order.reference.isNotEmpty)
                      OrderCode(code: order.reference, compact: true),
                    const SizedBox(height: 4),
                    Text(
                      order.variantName ?? order.serviceName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (order.variantName != null)
                      Text(order.serviceName, style: theme.textTheme.bodySmall),
                    Text(order.customerName, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 4),
                    Text(
                      '${formatDate(order.scheduledDate)} · '
                      '${formatTime(order.scheduledDate)}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusWithActions(
                // One status, and the one a customer would recognise. The work, crew and wage
                // tracks belong to the other tab — this list is for reading, not working.
                status: BookingStatusChip(order: order),
                actions: [
                  // Where a conversation starts from this end. The Messages tab only lists
                  // orders somebody has already written on, so without this the business could
                  // only ever reply to a customer who wrote first.
                  if (canMessage)
                    MessageIconButton(
                      bookingId: order.id,
                      title: order.variantName ?? order.serviceName,
                      // The customer, since this is the business reading it.
                      counterpartName: order.customerName,
                      tooltip: 'Message customer',
                      iconSize: 22,
                    ),
                  if (canCall)
                    CallIconButton(
                      phoneNumber: order.customerPhone!,
                      tooltip: 'Call customer',
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

// ---------------------------------------------------------------------------------------------
// Tab 2 — what to do next
// ---------------------------------------------------------------------------------------------

/// Every job the business still has to move along, each showing only its next step.
///
/// Covers both kinds of work: customer orders, and the business's own events run through a
/// standalone hiring post. Leaving the second kind out would strand it — a post with no order
/// behind it would have nowhere left to be started, finished or paid.
class _StatusManagementTab extends ConsumerWidget {
  const _StatusManagementTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(businessBookingsProvider);
    final postsAsync = ref.watch(businessHiringPostsProvider);

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

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait(<Future<void>>[
          ref.refresh(businessBookingsProvider.future),
          ref.refresh(businessHiringPostsProvider.future),
        ]);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final order in live) ...[
            _OrderStepCard(order: order, posts: posts),
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
              _OwnEventStepCard(post: post),
              const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }
}

/// One customer order, with the single thing it is waiting on.
class _OrderStepCard extends ConsumerStatefulWidget {
  const _OrderStepCard({required this.order, required this.posts});

  final Booking order;
  final List<HiringPost> posts;

  @override
  ConsumerState<_OrderStepCard> createState() => _OrderStepCardState();
}

class _OrderStepCardState extends ConsumerState<_OrderStepCard> {
  bool _isBusy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _isBusy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        context.showFailureMessage(
          e.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  /// The hiring raised for this order, if any — what the Pay crew button pays.
  HiringPost? get _linkedPost {
    for (final post in widget.posts) {
      if (post.bookingId == widget.order.id) return post;
    }
    return null;
  }

  /// How many on this order can still be given extra pay: added directly, or hired through its post.
  int _raisableCount(HiringPost? linkedPost) {
    final direct = widget.order.assignedWorkers.where((w) => w.canRaiseSalary);
    final hires = (linkedPost?.applications ?? const []).where(
      (h) => h.isAccepted && h.canRaiseSalary,
    );
    return direct.length + hires.length;
  }

  /// Tapping a worker's name: raise, message or call them, whichever applies right now.
  void _openWorker(
    BookingWorkerAssignment worker,
    HiringPostApplication? hire,
  ) {
    final order = widget.order;
    final crewTotal = order.wageOutstandingAmount;

    final VoidCallback? raise = switch (hire) {
      final hire? when hire.canRaiseSalary && !worker.isRejected =>
        () => showRaiseSalaryDialog(
          context,
          application: hire,
          crewTotal: crewTotal,
        ),
      null when worker.canRaiseSalary => () => showRaiseAssignmentSalaryDialog(
        context,
        bookingId: order.id,
        worker: worker,
        crewTotal: crewTotal,
      ),
      _ => null,
    };

    final wage =
        worker.wageLabel ??
        switch (hire) {
          final hire? when hire.hasAgreedSalary =>
            '${rupees(hire.agreedSalaryAmount!)} '
                '${salaryUnitWords(hire.agreedSalaryUnit ?? SalaryUnit.perEvent)}'
                '${hire.hasBeenRaised ? ' (raised)' : ''}',
          _ => 'Paid outside Zuno',
        };

    CrewMemberSheet.show(
      context,
      name: worker.workerName,
      detail: '${worker.displayStatusLabel} · $wage',
      onRaise: raise,
      messageCounterpartId:
          !order.isCancelled && (worker.isAccepted || worker.isCompleted)
          ? worker.workerProfileId
          : null,
      phone: order.canCallCrewMember(worker) ? worker.workerPhone : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final notifier = ref.read(businessBookingsProvider.notifier);
    final linkedPost = _linkedPost;

    return _StepCard(
      title: order.variantName ?? order.serviceName,
      subtitle: order.customerName,
      code: order.reference.isEmpty ? null : order.reference,
      when: order.scheduledDate,
      stage: order.orderStatusLabel(),
      // The tracks say how far the job has got; the crew list says who is on it and what each of
      // them is owed. This is the screen the business works from, so both belong here.
      tracks: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BookingTracks(booking: order),
          BookingCrewList(
            booking: order,
            canSetRoles: true,
            // Workers hired through the post carry their wage there, and that is where a raise
            // for extra work is recorded — and what Pay crew then charges.
            postHires: {
              for (final hire in linkedPost?.applications ?? const [])
                if (hire.isAccepted) hire.workerProfileId: hire,
            },
            raiseSalaryAction: (hire) => RaiseSalaryButton(
              application: hire,
              crewTotal: order.wageOutstandingAmount,
            ),
            raiseAssignmentAction: (worker) => IconButton(
              icon: const Icon(Icons.trending_up_rounded),
              tooltip: 'Raise salary',
              onPressed: () => showRaiseAssignmentSalaryDialog(
                context,
                bookingId: order.id,
                worker: worker,
                crewTotal: order.wageOutstandingAmount,
              ),
            ),
            onWorkerTap: _openWorker,
            onRaiseAll: switch (_raisableCount(linkedPost)) {
              0 => null,
              final count => () => showRaiseOrderCrewDialog(
                context,
                bookingId: order.id,
                count: count,
                crewTotal: order.wageOutstandingAmount,
              ),
            },
          ),
        ],
      ),
      isBusy: _isBusy,
      step: switch (order) {
        _ when order.canStartWork() => _Step(
          'Start work',
          Icons.play_arrow_rounded,
          () => _run(() => notifier.startWork(order.id)),
        ),
        _ when order.canCompleteWork => _Step(
          'Mark completed',
          Icons.done_all_rounded,
          () => _run(() => notifier.completeWork(order.id)),
        ),
        // Paying runs through the hiring post that owes the money; there is no second payment
        // path for orders.
        _ when order.isCompleted && order.hasOutstandingWages => switch (linkedPost) {
          final post? => _Step(
            'Pay crew · ${rupees(order.wageOutstandingAmount)}',
            Icons.payments_outlined,
            () async {
              // Captured before the await, not read after it. Paying the last wage makes
              // this order entirely complete, which drops it out of the list and disposes
              // this very card — so by the time the sheet closes, `ref` has no context left
              // to use and throws. The container outlives the card and refreshes either way.
              final container = ProviderScope.containerOf(
                context,
                listen: false,
              );
              await PayCrewSheet.show(context, post);
              container.invalidate(businessBookingsProvider);
            },
          ),
          _ => null,
        },
        _ => null,
      },
      waitingFor: switch (order) {
        _ when order.isEntirelyComplete => 'Finished and settled',
        _ when order.isConfirmed && !order.hasReachedItsDate() =>
          'Waiting for the day',
        _ when order.isConfirmed => 'Nobody has accepted the job yet',
        _ when order.isWageDisputed => 'A worker disputed their payment',
        _ => null,
      },
      done: order.isEntirelyComplete,
    );
  }
}

/// One of the business's own events, run through a standalone hiring post.
class _OwnEventStepCard extends ConsumerStatefulWidget {
  const _OwnEventStepCard({required this.post});

  final HiringPost post;

  @override
  ConsumerState<_OwnEventStepCard> createState() => _OwnEventStepCardState();
}

class _OwnEventStepCardState extends ConsumerState<_OwnEventStepCard> {
  bool _isBusy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _isBusy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        context.showFailureMessage(
          e.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final notifier = ref.read(businessHiringPostsProvider.notifier);

    return _StepCard(
      title: post.title,
      subtitle: post.location ?? 'Your own event',
      code: null,
      when: post.eventDate,
      stage: post.isFullyComplete
          ? 'Finished and settled'
          : post.isWorkCompleted
          ? 'Work done'
          : post.isWorkStarted
          ? 'In progress'
          : '${post.filledCount} of ${post.workersNeeded} hired',
      // The post's own three strands. Same treatment as an order's, because it is the same
      // question — how far has this job got — asked about the business's own event.
      tracks: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatusTrackList(
            tracks: [
              TrackRow(
                name: 'Event',
                state: post.eventState(),
                detail: post.eventDetail(),
              ),
              TrackRow(
                name: 'Workers',
                state: post.workersState(),
                detail: post.workersDetail(),
              ),
              TrackRow(
                name: 'Payment',
                state: post.paymentState(),
                detail: post.paymentDetail(),
              ),
            ],
          ),
          // Who is owed what, and where a wage is raised for extra work before Pay all.
          PostCrewWageList(post: post),
        ],
      ),
      isBusy: _isBusy,
      step: switch (post) {
        _ when post.canStartWork() => _Step(
          'Start work',
          Icons.play_arrow_rounded,
          () => _run(() => notifier.startWork(post.id)),
        ),
        _ when post.canMarkComplete() => _Step(
          'Mark work completed',
          Icons.done_all_rounded,
          () => _run(() => notifier.completeWork(post.id)),
        ),
        _ when post.isWorkCompleted && post.hasOutstandingPayment => _Step(
          post.isPartiallyPaid
              ? 'Resume paying · ${rupees(post.outstandingAmount)}'
              : 'Pay all · ${rupees(post.outstandingAmount)}',
          Icons.payments_outlined,
          () async {
            // Same reason as the order card above: settling the last wage removes this event
            // from the list and disposes the card mid-await, so the container does the
            // refreshing rather than a `ref` whose widget is already gone.
            final container = ProviderScope.containerOf(context, listen: false);
            await PayCrewSheet.show(context, post);
            container.invalidate(businessHiringPostsProvider);
          },
        ),
        _ => null,
      },
      waitingFor: switch (post) {
        _ when post.isFullyComplete => 'Finished and settled',
        _ when post.filledCount == 0 => 'Nobody hired yet',
        _ when !post.isEventOver() && !post.isWorkStarted =>
          'Waiting for the day',
        _ when post.hasDisputedPayment => 'A worker disputed their payment',
        _ => null,
      },
      done: post.isFullyComplete,
    );
  }
}

/// A button on a step card: what it says, what it looks like, what it does.
class _Step {
  const _Step(this.label, this.icon, this.onPressed);

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
}

/// One job, every track it runs on, and at most one thing to press.
///
/// The tracks live here rather than on the order's own screen: this is where they can be acted
/// on, and a status a business can only read is a status in the wrong place.
///
/// Only ever one button, though. A card offering start, finish and pay together asks the
/// business to work out the order for itself; showing only the next step means there is nothing
/// to work out.
class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.title,
    required this.subtitle,
    required this.code,
    required this.when,
    required this.stage,
    required this.tracks,
    required this.isBusy,
    required this.step,
    required this.waitingFor,
    required this.done,
  });

  final String title;
  final String subtitle;
  final String? code;
  final DateTime when;
  final String stage;

  /// Every strand of this job's progress, in the order each one opens.
  final Widget tracks;
  final bool isBusy;
  final _Step? step;
  final String? waitingFor;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = done ? StatusTone.success : StatusTone.progress;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (code case final c?) ...[
                        OrderCode(code: c, compact: true),
                        const SizedBox(height: 4),
                      ],
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${formatDate(when)} · ${formatTime(when)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                StatusPill(label: stage, tone: tone, compact: true),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            tracks,
            if (isBusy) ...[
              const SizedBox(height: 12),
              const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ] else if (step case final s?) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: s.onPressed,
                  icon: Icon(s.icon, size: 19),
                  label: Text(s.label),
                ),
              ),
            ] else if (waitingFor case final reason?) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    done ? Icons.verified_rounded : Icons.schedule_rounded,
                    size: 15,
                    color: AppColors.status(tone, theme.brightness),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      reason,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.status(tone, theme.brightness),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
