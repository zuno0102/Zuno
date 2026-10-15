import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/features/booking/domain/entities/booking.dart';
import 'package:zuno/features/booking/presentation/providers/business_bookings_notifier.dart';
import 'package:zuno/features/booking/presentation/widgets/booking_status_chip.dart';
import 'package:zuno/features/booking/presentation/widgets/booking_crew_list.dart';
import 'package:zuno/features/booking/presentation/widgets/booking_tracks.dart';
import 'package:zuno/features/booking/presentation/widgets/order_code.dart';
import 'package:zuno/features/business_owner/presentation/screens/business_booking_detail_screen.dart';
import 'package:zuno/features/business_owner/presentation/widgets/pay_crew_sheet.dart';
import 'package:zuno/features/hiring_post/domain/entities/hiring_post.dart';
import 'package:zuno/features/hiring_post/presentation/providers/business_hiring_posts_notifier.dart';
import 'package:zuno/shared/widgets/call_icon_button.dart';
import 'package:zuno/shared/widgets/empty_state.dart';
import 'package:zuno/shared/widgets/error_banner.dart';
import 'package:zuno/shared/widgets/status_pill.dart';
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
      length: 2,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: const TabBar(
              tabs: [
                Tab(text: 'From customers'),
                Tab(text: 'Status management'),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [_CustomerOrdersTab(), _StatusManagementTab()],
            ),
          ),
        ],
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

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The order code first. A business running three weddings at once needs something
            // it can say out loud and match against the hiring post it raised for that job.
            if (order.reference.isNotEmpty)
              OrderCode(code: order.reference, compact: true),
            const SizedBox(height: 4),
            Text(
              order.variantName ?? order.serviceName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            if (order.variantName != null)
              Text(order.serviceName, style: theme.textTheme.bodySmall),
            Text(order.customerName),
            const SizedBox(height: 4),
            Text(
              '${formatDate(order.scheduledDate)} · '
              '${formatTime(order.scheduledDate)}',
            ),
          ],
        ),
        isThreeLine: true,
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // One status, and the one a customer would recognise. The work, crew and wage
            // tracks belong to the other tab — this list is for reading, not working.
            BookingStatusChip(order: order),
            if (order.canBeCalled && order.customerPhone != null)
              CallIconButton(
                phoneNumber: order.customerPhone!,
                tooltip: 'Call customer',
              ),
          ],
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BusinessBookingDetailScreen(booking: order),
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
    final live = orders
        .where((o) => !o.isPending && !o.isCancelled)
        .toList()
      ..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));

    // Own events only. A post raised for an order is managed through that order, so listing it
    // here as well would ask the business to finish the same job twice.
    final ownEvents = posts
        .where((p) => p.bookingId == null && !p.isLapsed())
        .toList()
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
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

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final notifier = ref.read(businessBookingsProvider.notifier);

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
          BookingCrewList(booking: order, canSetRoles: true),
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
        _ when order.isCompleted && order.hasOutstandingWages =>
          switch (_linkedPost) {
            final post? => _Step(
              'Pay crew · ${rupees(order.wageOutstandingAmount)}',
              Icons.payments_outlined,
              () async {
                // Captured before the await, not read after it. Paying the last wage makes
                // this order entirely complete, which drops it out of the list and disposes
                // this very card — so by the time the sheet closes, `ref` has no context left
                // to use and throws. The container outlives the card and refreshes either way.
                final container = ProviderScope.containerOf(context, listen: false);
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
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
      tracks: StatusTrackList(
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
