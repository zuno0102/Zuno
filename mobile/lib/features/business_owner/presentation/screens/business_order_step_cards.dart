import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/shared/widgets/app_messages.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/features/booking/domain/entities/booking.dart';
import 'package:zuno/features/booking/domain/entities/booking_worker_assignment.dart';
import 'package:zuno/features/booking/presentation/providers/business_bookings_notifier.dart';
import 'package:zuno/features/booking/presentation/widgets/booking_crew_list.dart';
import 'package:zuno/features/booking/presentation/widgets/booking_tracks.dart';
import 'package:zuno/features/booking/presentation/widgets/order_code.dart';
import 'package:zuno/features/catalog/domain/entities/order_stage.dart';
import 'package:zuno/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:zuno/features/business_owner/presentation/widgets/crew_member_sheet.dart';
import 'package:zuno/features/business_owner/presentation/widgets/pay_crew_sheet.dart';
import 'package:zuno/features/business_owner/presentation/widgets/post_crew_wage_list.dart';
import 'package:zuno/features/business_owner/presentation/widgets/raise_salary_dialog.dart';
import 'package:zuno/features/hiring_post/domain/entities/hiring_post.dart';
import 'package:zuno/features/hiring_post/domain/entities/hiring_post_application.dart';
import 'package:zuno/features/hiring_post/presentation/providers/business_hiring_posts_notifier.dart';
import 'package:zuno/shared/widgets/status_pill.dart';
import 'package:zuno/shared/widgets/status_track.dart';

// ---------------------------------------------------------------------------------------------
// Tab 2 — the cards on Status management
// ---------------------------------------------------------------------------------------------

/// One customer order, with the single thing it is waiting on.
class OrderStepCard extends ConsumerStatefulWidget {
  const OrderStepCard({required this.order, required this.posts, super.key});

  final Booking order;
  final List<HiringPost> posts;

  @override
  ConsumerState<OrderStepCard> createState() => _OrderStepCardState();
}

class _OrderStepCardState extends ConsumerState<OrderStepCard> {
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
      messageCounterpartId: order.canMessageCrewMember(worker)
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

    return WorkStepCard(
      title: order.variantName ?? order.serviceName,
      subtitle: order.customerName,
      code: order.reference.isEmpty ? null : order.reference,
      when: order.scheduledDate,
      stage: (ref.watch(orderStagesProvider).value ?? const <OrderStage>[])
          .resolve(order.stage),
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
        _ when order.canStartWork() => WorkStep(
          'Start work',
          Icons.play_arrow_rounded,
          () => _run(() => notifier.startWork(order.id)),
        ),
        _ when order.canCompleteWork => WorkStep(
          'Mark completed',
          Icons.done_all_rounded,
          () => _run(() => notifier.completeWork(order.id)),
        ),
        // Paying runs through the hiring post that owes the money; there is no second payment
        // path for orders.
        _ when order.isCompleted && order.hasOutstandingWages => switch (linkedPost) {
          final post? => WorkStep(
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
class OwnEventStepCard extends ConsumerStatefulWidget {
  const OwnEventStepCard({required this.post, super.key});

  final HiringPost post;

  @override
  ConsumerState<OwnEventStepCard> createState() => _OwnEventStepCardState();
}

class _OwnEventStepCardState extends ConsumerState<OwnEventStepCard> {
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

    return WorkStepCard(
      title: post.title,
      subtitle: post.location ?? 'Your own event',
      code: null,
      when: post.eventDate,
      // The same stage, and so the same words, as the filter it sits under. How many are hired
      // is on the Workers line of the tracks below.
      stage: (ref.watch(orderStagesProvider).value ?? const <OrderStage>[])
          .resolve(post.stage),
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
        _ when post.canStartWork() => WorkStep(
          'Start work',
          Icons.play_arrow_rounded,
          () => _run(() => notifier.startWork(post.id)),
        ),
        _ when post.canMarkComplete() => WorkStep(
          'Mark work completed',
          Icons.done_all_rounded,
          () => _run(() => notifier.completeWork(post.id)),
        ),
        _ when post.isWorkCompleted && post.hasOutstandingPayment => WorkStep(
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
class WorkStep {
  const WorkStep(this.label, this.icon, this.onPressed);

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
class WorkStepCard extends StatelessWidget {
  const WorkStepCard({
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
    super.key,
  });

  final String title;
  final String subtitle;
  final String? code;
  final DateTime when;

  /// Where the job stands — its name and colour as the server's stage list gives them.
  final OrderStage stage;

  /// Every strand of this job's progress, in the order each one opens.
  final Widget tracks;
  final bool isBusy;
  final WorkStep? step;
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
                StatusPill(
                  label: stage.label,
                  tone: stage.statusTone,
                  compact: true,
                ),
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
