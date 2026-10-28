import 'package:flutter/material.dart';
import 'package:zuno/shared/widgets/detail_row.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/core/ui_config/ui_config.dart';
import 'package:zuno/features/business_owner/domain/entities/business_dashboard.dart';
import 'package:zuno/features/business_owner/domain/entities/business_service.dart';
import 'package:zuno/features/business_owner/presentation/providers/business_services_notifier.dart';
import 'package:zuno/features/catalog/domain/entities/order_stage.dart';
import 'package:zuno/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:zuno/shared/widgets/empty_state.dart';
import 'package:zuno/shared/widgets/error_banner.dart';
import 'package:zuno/shared/widgets/status_pill.dart';

/// Bookings behind the Upcoming, Awaiting payment and Cancelled tiles.
///
/// One screen for all of them, because the row is the same booking whichever tile opened it —
/// what changes is which date matters, and what is worth saying about it.
class BookingListScreen extends StatelessWidget {
  const BookingListScreen({
    required this.title,
    required this.events,
    required this.mode,
    super.key,
  });

  final String title;
  final List<DashboardEvent> events;
  final BookingListMode mode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final plural = events.length == 1 ? '' : 's';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: events.isEmpty
          ? EmptyState(
              icon: switch (mode) {
                BookingListMode.upcoming => Icons.event_available_outlined,
                BookingListMode.awaitingPayment => Icons.payments_outlined,
                BookingListMode.cancelled => Icons.event_busy_outlined,
              },
              title: switch (mode) {
                BookingListMode.upcoming => 'Nothing confirmed yet',
                BookingListMode.awaitingPayment => 'Nobody waiting to be paid',
                BookingListMode.cancelled => 'Nothing cancelled',
              },
              message: switch (mode) {
                BookingListMode.upcoming =>
                  'Bookings you have confirmed, with a date still ahead, will appear here.',
                BookingListMode.awaitingPayment =>
                  'Work you marked complete while a worker is still unpaid will appear here.',
                BookingListMode.cancelled =>
                  'Bookings called off by you or the customer will appear here.',
              },
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemCount: events.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      switch (mode) {
                        BookingListMode.upcoming =>
                          '${events.length} confirmed booking$plural still to come',
                        BookingListMode.awaitingPayment =>
                          '${events.length} booking$plural with a wage still owed',
                        BookingListMode.cancelled =>
                          '${events.length} cancelled booking$plural',
                      },
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }

                return _BookingCard(event: events[index - 1], mode: mode);
              },
            ),
    );
  }
}

enum BookingListMode { upcoming, awaitingPayment, cancelled }

class _BookingCard extends ConsumerWidget {
  const _BookingCard({required this.event, required this.mode});

  final DashboardEvent event;
  final BookingListMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isCancelled = mode == BookingListMode.cancelled;
    final stage = (ref.watch(orderStagesProvider).value ?? const <OrderStage>[])
        .resolve(event.stage);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
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
                      Text(
                        event.subCategoryName ?? event.serviceName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${event.categoryName} · ${event.serviceName}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  rupees(event.price),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isCancelled
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.primary,
                    decoration: isCancelled ? TextDecoration.lineThrough : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            DetailRow.iconText(
              icon: Icons.person_outline,
              text: event.customerName.isEmpty
                  ? 'Customer'
                  : event.customerName,
            ),
            DetailRow.iconText(
              icon: Icons.schedule_outlined,
              text: '${formatDate(event.scheduledDate)} · ${event.whenLabel}',
            ),
            if (event.city case final city? when city.isNotEmpty)
              DetailRow.iconText(icon: Icons.place_outlined, text: city),
            DetailRow.iconText(
              icon: Icons.groups_outlined,
              // Zero is not "no workers" — it is a per-person job whose crew size is still to be
              // agreed with the customer. "0 workers needed" would read as nothing to staff.
              text: event.requiredWorkerCount < 1
                  ? 'Crew size to be agreed'
                  : '${event.requiredWorkerCount} '
                        '${event.requiredWorkerCount == 1 ? 'worker' : 'workers'} needed',
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                // The server's stage for this row — on the Awaiting payment list that is
                // "awaiting payment", not the order's bare Completed — named and coloured by the
                // stage list.
                StatusPill(
                  label: stage.label,
                  tone: stage.statusTone,
                  compact: true,
                ),
              ],
            ),
            // Why it fell through is the whole point of the cancelled list.
            if (isCancelled) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (event.cancelledAt case final at?)
                      Text(
                        'Cancelled ${formatDate(at)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.error,
                        ),
                      ),
                    Text(
                      event.cancellationReason?.isNotEmpty ?? false
                          ? event.cancellationReason!
                          : 'No reason was recorded.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Crew events behind the Crew events tile — hiring posts, with their wage bill.
class CrewEventListScreen extends StatelessWidget {
  const CrewEventListScreen({required this.events, super.key});

  final List<CrewEvent> events;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settled = events.where((e) => e.isFullyComplete).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Crew events')),
      body: events.isEmpty
          ? const EmptyState(
              icon: Icons.groups_outlined,
              title: 'No crew events yet',
              message:
                  'Post a job to hire workers for an event and it will appear here, with what '
                  'you owe and what you have paid.',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemCount: events.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '$settled of ${events.length} finished and fully paid. '
                      'Only these count towards your record.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }

                return _CrewEventCard(event: events[index - 1]);
              },
            ),
    );
  }
}

class _CrewEventCard extends StatelessWidget {
  const _CrewEventCard({required this.event});

  final CrewEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (label, tone) = switch (event) {
      _ when event.isFullyComplete => ('Complete & paid', StatusTone.success),
      _ when event.isWorkDone => ('Work done, wages owed', StatusTone.progress),
      _ when event.workersHired > 0 => ('Crew hired', StatusTone.progress),
      _ => ('Still hiring', StatusTone.waiting),
    };

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    event.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                StatusPill(label: label, tone: tone, compact: true),
              ],
            ),
            const SizedBox(height: 10),
            DetailRow.iconText(
              icon: Icons.event_outlined,
              text: formatDate(event.eventDate),
            ),
            if (event.location case final where? when where.isNotEmpty)
              DetailRow.iconText(icon: Icons.place_outlined, text: where),
            DetailRow.iconText(
              icon: Icons.groups_outlined,
              text: event.crewLabel,
            ),
            if (event.workCompletedAt case final done?)
              DetailRow.iconText(
                icon: Icons.check_circle_outline,
                text: 'Work finished ${formatDate(done)}',
              ),
            if (event.totalWages > 0) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.55,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _WageFigure(
                        label: 'Wage bill',
                        value: rupees(event.totalWages),
                      ),
                    ),
                    Expanded(
                      child: _WageFigure(
                        label: event.outstandingWages > 0
                            ? 'Still owed'
                            : 'Paid',
                        value: event.outstandingWages > 0
                            ? rupees(event.outstandingWages)
                            : 'In full',
                        tone: event.outstandingWages > 0
                            ? AppColors.status(
                                StatusTone.progress,
                                theme.brightness,
                              )
                            : AppColors.status(
                                StatusTone.success,
                                theme.brightness,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WageFigure extends StatelessWidget {
  const _WageFigure({required this.label, required this.value, this.tone});

  final String label;
  final String value;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 11,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: tone,
          ),
        ),
      ],
    );
  }
}

/// The roster behind the Active workers tile.
///
/// Ordered by the server so whoever is free reads first — this screen keeps that order rather
/// than re-sorting, since the question being asked is "who can I put on the next job".
class ActiveWorkerListScreen extends StatelessWidget {
  const ActiveWorkerListScreen({required this.workers, super.key});

  final List<DashboardWorker> workers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final free = workers.where((w) => w.isFree).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Active workers')),
      body: workers.isEmpty
          ? const EmptyState(
              icon: Icons.badge_outlined,
              title: 'Nobody on your roster yet',
              message:
                  'Workers who accept an invitation appear here, ready to be put '
                  'on a job.',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemCount: workers.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      // The number that decides whether they can take the next job is how many
                      // are free, not how many are on the books.
                      '$free of ${workers.length} free right now',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }

                return _WorkerCard(worker: workers[index - 1]);
              },
            ),
    );
  }
}

class _WorkerCard extends StatelessWidget {
  const _WorkerCard({required this.worker});

  final DashboardWorker worker;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = UiConfig.current.tone(
      'WorkerAvailability.Business',
      worker.availabilityStatus,
    );
    final colour = AppColors.status(tone, theme.brightness);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 19,
              backgroundColor: colour.withValues(alpha: 0.16),
              child: Text(
                worker.workerName.isEmpty
                    ? '?'
                    : worker.workerName[0].toUpperCase(),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colour,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    worker.workerName.isEmpty ? 'Worker' : worker.workerName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // What they have done for this business, which is what earns them the next
                  // job — and how long they have been on the books.
                  // The date first when there is one: the whole point of reading this list is
                  // working out who is free *when*, and a status with no date cannot answer it.
                  if (worker.busyDetail case final busy?)
                    DetailRow.iconText(
                      icon: Icons.event_busy_outlined,
                      text: busy,
                    ),
                  DetailRow.iconText(
                    icon: Icons.workspace_premium_outlined,
                    text:
                        '${worker.experienceLabel} · with you since '
                        '${formatDayMonth(worker.sinceDate)}',
                  ),
                  if (worker.workerPhone case final phone?
                      when phone.isNotEmpty)
                    DetailRow.iconText(icon: Icons.phone_outlined, text: phone),
                ],
              ),
            ),
            const SizedBox(width: 8),
            StatusPill(
              label: worker.availabilityLabel,
              tone: tone,
              compact: true,
            ),
          ],
        ),
      ),
    );
  }
}

/// The services behind the Active services and Inactive services tiles.
///
/// One screen for both, because the row is the same service either way — what differs is which half
/// of the list it belongs to, and that is already said in the title.
///
/// A `ConsumerWidget` where its neighbours here are plain, and for one reason: the dashboard carries
/// `activeServices` and `inactiveServices` as counts, not as lists, unlike the bookings and workers
/// the other tiles hand straight to their screen. So this reads the services the Services tab
/// already loads and takes the half it wants, rather than widening the dashboard payload for a page
/// most people never open.
///
/// Read-only, like [ActiveWorkerListScreen]. Editing a service, managing its items and switching it
/// off all live on the Services tab, where the whole list is.
class BusinessServiceListScreen extends ConsumerWidget {
  const BusinessServiceListScreen({
    required this.title,
    required this.active,
    super.key,
  });

  final String title;

  /// Which half this page is: the services customers can find, or the ones switched off.
  final bool active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicesAsync = ref.watch(businessServicesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: servicesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ErrorBanner(message: error.toString()),
          ),
        ),
        data: (services) {
          final shown = services.where((s) => s.isActive == active).toList();

          if (shown.isEmpty) {
            // Reached by tapping a tile that reads 0, which is a thing somebody does to find out
            // what it means. A blank page would answer nothing.
            return EmptyState(
              icon: active
                  ? Icons.storefront_outlined
                  : Icons.visibility_off_outlined,
              title: active
                  ? 'Nothing live for customers'
                  : 'Nothing switched off',
              message: active
                  ? 'Services you switch on appear here, ready for customers to '
                        'find and book.'
                  : 'Services you switch off are kept here, out of sight of '
                        'customers but yours to switch back on.',
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.refresh(businessServicesProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemCount: shown.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) =>
                  _ServiceSummaryCard(service: shown[index]),
            ),
          );
        },
      ),
    );
  }
}

class _ServiceSummaryCard extends StatelessWidget {
  const _ServiceSummaryCard({required this.service});

  final BusinessService service;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 19,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(
                Icons.design_services_outlined,
                size: 19,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  DetailRow.iconText(
                    icon: Icons.category_outlined,
                    text: service.serviceCategoryName,
                  ),
                  DetailRow.iconText(
                    icon: Icons.payments_outlined,
                    text: priceLabel(service.price, service.priceType),
                  ),
                  // Only where there are any: an item count of nothing reads as a fault rather
                  // than as a service priced as one thing.
                  if (service.variants.isNotEmpty)
                    DetailRow.iconText(
                      icon: Icons.list_alt_outlined,
                      text:
                          '${service.variants.length} '
                          'item${service.variants.length == 1 ? '' : 's'} inside',
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
