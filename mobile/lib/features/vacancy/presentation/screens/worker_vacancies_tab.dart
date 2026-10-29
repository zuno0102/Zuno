import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/router/push_screen.dart';
import 'package:zuno/features/vacancy/domain/entities/vacancy.dart';
import 'package:zuno/features/vacancy/presentation/providers/vacancy_providers.dart';
import 'package:zuno/features/vacancy/presentation/providers/worker_vacancies_notifier.dart';
import 'package:zuno/features/vacancy/presentation/screens/worker_vacancy_detail_screen.dart';
import 'package:zuno/features/vacancy/presentation/widgets/vacancy_labels.dart';
import 'package:zuno/features/worker/presentation/providers/worker_job_filter_provider.dart';
import 'package:zuno/shared/widgets/empty_state.dart';
import 'package:zuno/shared/widgets/error_banner.dart';

/// Find work › Full-time jobs: every open full-time job, narrowed by job type and the worker's
/// saved location. What they have applied to lives under My jobs › My applications.
class WorkerVacanciesTab extends ConsumerStatefulWidget {
  const WorkerVacanciesTab({super.key});

  @override
  ConsumerState<WorkerVacanciesTab> createState() => _WorkerVacanciesTabState();
}

class _WorkerVacanciesTabState extends ConsumerState<WorkerVacanciesTab> {
  String? _jobTypeId;

  @override
  Widget build(BuildContext context) {
    final provider = workerVacanciesProvider(jobTypeId: _jobTypeId);
    final vacanciesAsync = ref.watch(provider);
    final jobTypes =
        ref.watch(vacancyOptionsProvider(asWorker: true)).value?.jobTypes ??
        const [];
    final filter = ref.watch(workerJobFilterProvider);

    return Column(
      children: [
        if (jobTypes.isNotEmpty)
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: const Text('All'),
                    selected: _jobTypeId == null,
                    onSelected: (_) => setState(() => _jobTypeId = null),
                  ),
                ),
                for (final t in jobTypes)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(t.name),
                      selected: _jobTypeId == t.id,
                      onSelected: (_) => setState(() => _jobTypeId = t.id),
                    ),
                  ),
              ],
            ),
          ),
        if (filter.isFiltering)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Within ${filter.radiusKm} km of ${filter.placeLabel ?? 'your location'}'
                ' · change it under Service',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        Expanded(
          child: vacanciesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ErrorBanner(message: error.toString()),
              ),
            ),
            data: (page) => page.items.isEmpty
                ? const EmptyState(
                    icon: Icons.badge_outlined,
                    title: 'No full-time jobs here yet',
                    message:
                        'Shops and offices post jobs here. Check back soon, or widen your distance.',
                  )
                : RefreshIndicator(
                    onRefresh: () => ref.refresh(provider.future),
                    child: NotificationListener<ScrollEndNotification>(
                      onNotification: (n) {
                        if (n.metrics.extentAfter < 200) {
                          ref.read(provider.notifier).loadMore();
                        }
                        return false;
                      },
                      child: _VacancyList(items: page.items),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

/// My jobs › My applications: the full-time jobs this worker applied for, and where each stands.
class MyVacancyApplicationsList extends ConsumerWidget {
  const MyVacancyApplicationsList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applicationsAsync = ref.watch(myVacancyApplicationsProvider);

    return applicationsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ErrorBanner(message: error.toString()),
        ),
      ),
      data: (items) => items.isEmpty
          ? const EmptyState(
              icon: Icons.send_outlined,
              title: 'No applications yet',
              message:
                  'Full-time jobs you apply for appear here, with the job poster\'s answer.',
            )
          : RefreshIndicator(
              onRefresh: () =>
                  ref.refresh(myVacancyApplicationsProvider.future),
              child: _VacancyList(items: items),
            ),
    );
  }
}

class _VacancyList extends StatelessWidget {
  const _VacancyList({required this.items});

  final List<Vacancy> items;

  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: const EdgeInsets.all(16),
    itemCount: items.length,
    separatorBuilder: (_, _) => const SizedBox(height: 12),
    itemBuilder: (context, i) => _WorkerVacancyCard(vacancy: items[i]),
  );
}

class _WorkerVacancyCard extends StatelessWidget {
  const _WorkerVacancyCard({required this.vacancy});

  final Vacancy vacancy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final v = vacancy;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            pushScreen(context, WorkerVacancyDetailScreen(vacancyId: v.id)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(v.title, style: theme.textTheme.titleMedium),
              Text(
                '${v.businessName} · ${v.jobTypeName}',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 6),
              Text(
                vacancySalaryLabel(v),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              Text(vacancyScheduleLabel(v), style: theme.textTheme.bodySmall),
              if (v.location != null || v.distanceKm != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.place_outlined, size: 16),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          [
                            ?v.location ?? v.districtName,
                            if (v.distanceKm != null) '${v.distanceKm} km away',
                          ].join(' · '),
                          style: theme.textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              if (v.myApplicationStatus case final status?)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: applicationStatusPill(status, compact: true),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
