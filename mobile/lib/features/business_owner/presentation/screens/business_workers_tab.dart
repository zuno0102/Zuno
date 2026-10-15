import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/features/business_owner/domain/entities/business_worker.dart';
import 'package:zuno/features/business_owner/domain/entities/worker_busy_period.dart';
import 'package:zuno/features/business_owner/presentation/providers/business_providers.dart';
import 'package:zuno/features/business_owner/presentation/providers/business_workers_notifier.dart';
import 'package:zuno/features/business_owner/presentation/screens/business_hiring_posts_tab.dart';
import 'package:zuno/features/business_owner/presentation/widgets/invite_worker_dialog.dart';
import 'package:zuno/shared/widgets/error_banner.dart';
import 'package:zuno/shared/widgets/status_pill.dart';

class BusinessWorkersTab extends StatelessWidget {
  const BusinessWorkersTab({this.initialIndex = 0, super.key});

  /// Which of the two sub-tabs opens first.
  ///
  /// Normally the crew. Set to the hire post when the owner arrived from a notification about one:
  /// landing them on "Active workers" and making them find the other tab is the hunting a
  /// notification exists to save.
  final int initialIndex;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialIndex,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: const TabBar(
              tabs: [
                Tab(text: 'Active workers'),
                Tab(text: 'Hire post'),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [_ActiveWorkersTab(), BusinessHiringPostsTab()],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveWorkersTab extends ConsumerWidget {
  const _ActiveWorkersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workersAsync = ref.watch(businessWorkersProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showInviteWorkerDialog(context),
        icon: const Icon(Icons.person_add_alt_outlined),
        label: const Text('Invite worker'),
      ),
      body: workersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ErrorBanner(message: error.toString()),
          ),
        ),
        data: (workers) {
          if (workers.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No workers yet. Invite a registered worker by email or phone.',
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.refresh(businessWorkersProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: workers.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) =>
                  _WorkerCard(worker: workers[index]),
            ),
          );
        },
      ),
    );
  }
}

class _WorkerCard extends ConsumerWidget {
  const _WorkerCard({required this.worker});

  final BusinessWorker worker;

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove worker?'),
        content: Text(
          '${worker.workerName} will no longer be part of your business.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(businessWorkersProvider.notifier).remove(worker.id);
    }
  }

  Future<void> _showSchedule(BuildContext context, WidgetRef ref) async {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${worker.workerName}\'s schedule'),
        content: SizedBox(
          width: 360,
          child: FutureBuilder<List<WorkerBusyPeriod>>(
            future: ref
                .read(businessRepositoryProvider)
                .getWorkerBusyDates(worker.workerProfileId),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const SizedBox(
                  height: 60,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return ErrorBanner(message: snapshot.error.toString());
              }

              final periods = snapshot.data ?? [];
              if (periods.isEmpty) {
                return const Text(
                  'No jobs on the books — this worker is fully available.',
                );
              }

              return _ScheduleList(periods: periods);
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// The colour that carries this worker's availability, used by the avatar and the pill so the
  /// row reads at a glance before any of it is actually read.
  StatusTone get _availabilityTone => worker.isAtWork
      ? StatusTone.progress
      : worker.isBooked
      ? StatusTone.waiting
      : StatusTone.success;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // Someone not yet on the roster has no availability to speak of, so the row is keyed by
    // their roster status instead.
    final accent = AppColors.status(
      worker.isActive ? _availabilityTone : StatusTone.waiting,
      theme.brightness,
    );
    final contact = worker.workerEmail ?? worker.workerPhone ?? '';

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showSchedule(context, ref),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 21,
                backgroundColor: accent.withValues(alpha: 0.16),
                child: Text(
                  worker.workerName.isEmpty
                      ? '?'
                      : worker.workerName[0].toUpperCase(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      worker.workerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (contact.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        contact,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    // Wrapped, not a fixed row: two pills and a long name used to fight for the
                    // same line and one of them lost.
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        StatusPill(
                          label: worker.status,
                          tone: switch (worker.status) {
                            'Active' => StatusTone.success,
                            'Invited' => StatusTone.progress,
                            'Rejected' => StatusTone.danger,
                            _ => StatusTone.waiting,
                          },
                          compact: true,
                        ),
                        // Availability is only worth a pill when it is a reason not to offer
                        // someone a job. A free worker already reads as Active, and a second
                        // pill repeating it in the same word said nothing while looking like
                        // it did.
                        if (worker.isActive && (worker.isAtWork || worker.isBooked))
                          StatusPill(
                            label: worker.isAtWork
                                ? 'At work'
                                : 'Already booked',
                            tone: _availabilityTone,
                            compact: true,
                          ),
                      ],
                    ),
                    // No dates here on purpose. The row says *whether* someone is spoken for;
                    // *when*, and for how many jobs, is the schedule's business — tapping the
                    // card opens it. One date on a row could only ever show the first of them.
                  ],
                ),
              ),
              // Quiet by design: removing someone is the rarest thing done on this row, and a
              // bold control would compete with the name for the eye.
              IconButton(
                icon: const Icon(Icons.close, size: 19),
                visualDensity: VisualDensity.compact,
                color: theme.colorScheme.onSurfaceVariant,
                tooltip: 'Remove',
                onPressed: () => _confirmRemove(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A worker.s jobs, grouped under the day they fall on.
///
/// Grouping is the whole point: a worker can hold several jobs on one date, and a flat list of
/// timestamps makes the reader spot that for themselves. Under one date heading, two rows say
/// plainly that the day is taken twice.
class _ScheduleList extends StatelessWidget {
  const _ScheduleList({required this.periods});

  final List<WorkerBusyPeriod> periods;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // The server returns these soonest first, so insertion order is already the order to read
    // them in — a plain map keeps it.
    final byDay = <DateTime, List<WorkerBusyPeriod>>{};
    for (final period in periods) {
      byDay.putIfAbsent(period.day, () => []).add(period);
    }

    final dayWord = byDay.length == 1 ? 'day' : 'days';
    final jobWord = periods.length == 1 ? 'job' : 'jobs';

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${periods.length} $jobWord across ${byDay.length} $dayWord',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          for (final entry in byDay.entries) ...[
            Row(
              children: [
                Text(
                  formatDate(entry.key),
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                // Said only when it is more than one, where it is the thing worth noticing.
                if (entry.value.length > 1) ...[
                  const SizedBox(width: 8),
                  StatusPill(
                    label: '${entry.value.length} jobs',
                    tone: StatusTone.progress,
                    compact: true,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            ...entry.value.map((p) => _ScheduleRow(period: p)),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({required this.period});

  final WorkerBusyPeriod period;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colour = theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 18,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: colour.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            period.timeRange,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              // Lines the digits up, so several rows under one date scan as a column.
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          // The one thing a bare time range cannot say for itself.
          if (period.endsNextDay) ...[
            const SizedBox(width: 8),
            Text(
              'next day',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
