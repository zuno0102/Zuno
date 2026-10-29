import 'package:zuno/shared/domain/job_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/features/worker/domain/entities/worker_dashboard.dart';
import 'package:zuno/features/worker/domain/entities/worker_profile.dart';
import 'package:zuno/features/worker/presentation/providers/worker_dashboard_notifier.dart';
import 'package:zuno/features/worker/presentation/screens/worker_job_list_screen.dart';
import 'package:zuno/features/worker/presentation/screens/worker_payments_screen.dart';
import 'package:zuno/features/worker/presentation/screens/worker_profile_screen.dart';
import 'package:zuno/features/worker/presentation/widgets/worker_profile_edit_sheet.dart';
import 'package:zuno/shared/widgets/error_banner.dart';
import 'package:zuno/shared/widgets/section_header.dart';
import 'package:zuno/shared/widgets/stat_tile.dart';
import 'package:zuno/core/ui_config/ui_config.dart';
import 'package:zuno/features/vacancy/presentation/providers/worker_vacancies_notifier.dart';
import 'package:zuno/features/vacancy/presentation/screens/worker_vacancies_tab.dart';
import 'package:zuno/shared/widgets/trust_cards.dart';
import 'package:zuno/core/router/push_screen.dart';

/// The worker's home screen.
///
/// Answers, in order, the four questions a worker actually opens the app with: what am I owed, what
/// have I earned, what am I doing next, and are my details right. The work record used to live on a
/// separate Profile tab, which meant the figures a worker cares about most were the ones furthest
/// from where they landed.
///
/// Money and work are shown here; the details behind them open as pages of their own. A dashboard is
/// for reading at a glance, and four labelled rows of contact details are not that.
class WorkerDashboardTab extends ConsumerWidget {
  const WorkerDashboardTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(workerDashboardProvider);

    return dashboardAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ErrorBanner(message: error.toString()),
        ),
      ),
      data: (dashboard) => RefreshIndicator(
        onRefresh: () => ref.refresh(workerDashboardProvider.future),
        child: _Body(dashboard: dashboard),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.dashboard});

  final WorkerDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final profile = dashboard.profile;

    return ListView(
      // Needed for RefreshIndicator to work on a list shorter than the screen.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // Money first, and money that is late before money already banked. A worker checking this
        // screen is far more often asking "where is my wage" than "what is my lifetime total".
        //
        // Always present, even at zero, so the answer to "am I owed anything" is in the same place
        // every time rather than a card that appears only on the days it is bad news.
        _AwaitingPaymentCard(dashboard: dashboard),
        const SizedBox(height: 12),

        // Payout setup leads whenever it is missing, because nothing else on this screen can
        // happen without it: the payout provider refuses a worker with no verified destination.
        if (profile != null && profile.needsPayoutSetup) ...[
          _PayoutWarning(profile: profile),
          const SizedBox(height: 12),
        ],

        _EarningsCard(dashboard: dashboard),
        const SizedBox(height: 12),

        // Grouped and named the way the business home groups its tiles, so each set says which
        // kind of work it counts. The names come from the label table.
        SectionHeader(
          title: UiConfig.current.label(dashboardSectionGroup, 'Service'),
          padding: const EdgeInsets.fromLTRB(0, 6, 0, 8),
        ),
        _WorkStats(dashboard: dashboard),
        SectionHeader(
          title: UiConfig.current.label(dashboardSectionGroup, 'FullTime'),
          padding: const EdgeInsets.fromLTRB(0, 18, 0, 8),
        ),
        const _FullTimeStats(),

        if (profile != null) ...[
          const SizedBox(height: 12),
          _ProfileCard(profile: profile),
        ],

        if (dashboard.hasTrend) ...[
          const SectionHeader(
            title: 'Your last six months',
            padding: EdgeInsets.fromLTRB(0, 22, 0, 8),
          ),
          _TrendChart(
            trend: dashboard.trend,
            busiest: dashboard.busiestMonthCount,
          ),
        ],

        if (profile != null && dashboard.hasWorkRecord) ...[
          const SectionHeader(
            title: 'Your record',
            padding: EdgeInsets.fromLTRB(0, 22, 0, 8),
          ),
          TrustCard(
            title: 'Work and pay',
            headline: '${profile.jobsPaid}',
            caption: 'jobs completed and paid',
            rows: [
              TrustRow('Total earned', rupees(profile.totalEarned)),
              if (profile.averageSalary != null)
                TrustRow('Average per job', rupees(profile.averageSalary!)),
              TrustRow(
                'Businesses worked for',
                '${profile.businessesWorkedFor}',
              ),
              TrustRow(
                'Offers declined',
                profile.offersDeclined == 0
                    ? 'None'
                    : '${profile.offersDeclined}',
                muted: profile.offersDeclined == 0,
              ),
              if (profile.openDisputes > 0)
                TrustRow(
                  'Unpaid reports open',
                  '${profile.openDisputes}',
                  tone: Theme.of(context).colorScheme.error,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Wages earned and not received, and the way in to answering for them.
///
/// The card is the route to the confirm-or-dispute screen. The rows themselves used to sit inline
/// below the profile and the chart, which put the one action that recovers a worker's money three
/// cards down the page.
class _AwaitingPaymentCard extends StatelessWidget {
  const _AwaitingPaymentCard({required this.dashboard});

  final WorkerDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOwed = dashboard.isOwedMoney;
    final jobs = dashboard.pendingPayments.length;
    final accent = isOwed
        ? AppColors.status(StatusTone.progress, theme.brightness)
        : theme.colorScheme.onSurfaceVariant;

    // A settled worker gets a plain card, an owed one a tinted card. Same place, same shape, so the
    // answer is always found in the same glance — but ₹0 is not dressed up as an event.
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: isOwed ? accent.withValues(alpha: 0.10) : null,
      child: InkWell(
        onTap: () => pushScreen(context, const WorkerPaymentsScreen()),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 12, 18),
          child: Row(
            children: [
              Icon(
                isOwed
                    ? Icons.account_balance_wallet_outlined
                    : Icons.verified_outlined,
                size: 30,
                color: accent,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AWAITING PAYMENT',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isOwed
                          ? rupees(dashboard.pendingPaymentTotal)
                          : 'Nothing waiting',
                      style: isOwed
                          ? theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: accent,
                            )
                          : theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                    ),
                    Text(
                      isOwed
                          ? jobs == 1
                                ? 'On one job you have finished. Tap to confirm or report it.'
                                : 'On $jobs jobs you have finished. Tap to confirm or report them.'
                          : 'Every wage you have earned has been paid.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lifetime earnings. Deliberately quieter than what is owed.
class _EarningsCard extends StatelessWidget {
  const _EarningsCard({required this.dashboard});

  final WorkerDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = dashboard.profile;
    final earned = profile?.totalEarned ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'EARNED THROUGH ZUNO',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  rupees(earned),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                // Flexible, because the figure beside it grows with the worker: a long total in
                // headlineMedium plus this caption overflowed a 360dp card by 96px.
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      dashboard.hasWorkRecord
                          ? 'across ${profile?.jobsCompleted ?? 0} '
                                '${(profile?.jobsCompleted ?? 0) == 1 ? 'job' : 'jobs'}'
                          // No ₹0 dressed up as an achievement.
                          : 'your first job is still to come',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Where the service work stands: running now, still to come, waiting on an answer.
///
/// Names, icons, colours and empty-list messages come from the `Dashboard.WorkerTile` label group,
/// so wording changes in the table rather than here. Laid out by the same grid as the business
/// home, so a tile is the same size in both panels.
class _WorkStats extends StatelessWidget {
  const _WorkStats({required this.dashboard});

  final WorkerDashboard dashboard;

  static const _group = 'Dashboard.WorkerTile';

  /// Live jobs this worker holds a role on, newest first.
  ///
  /// Only work still going: a role ends with its order, so listing finished jobs would be
  /// telling somebody they lead a job that closed last month.
  List<WorkerJobSummary> get _roleJobs => [
    ...dashboard.inProgress,
    ...dashboard.upcoming,
  ].where((j) => (j.myRole ?? '').trim().isNotEmpty).toList();

  int get _leadCount =>
      _roleJobs.where((j) => JobRole.grantsWorkControl(j.myRole)).length;

  @override
  Widget build(BuildContext context) {
    final config = UiConfig.current;

    /// One tile. [tone] overrides the table's colour where the count changes the meaning — a
    /// "Needs you" of zero is good news, not a warning.
    Widget tile(
      String code,
      int count,
      List<WorkerJobSummary> jobs, {
      StatusTone? tone,
      String? emptyCode,
    }) {
      final entry = config.entry(_group, code);
      return StatTile(
        label: entry.label,
        value: '$count',
        icon: entry.iconData,
        tone: tone ?? entry.statusTone,
        // Every tile opens its jobs. A count with no way in tells a worker how many but never
        // which, and which is the part they act on.
        onTap: () => pushScreen(
          context,
          WorkerJobListScreen(
            title: entry.label,
            jobs: jobs,
            emptyMessage: config.entry(_group, emptyCode ?? code).detail ?? '',
          ),
        ),
      );
    }

    final waitingOnMe = [
      ...dashboard.upcoming.where((j) => j.needsMyAnswer),
      ...dashboard.inProgress.where((j) => j.needsMyAnswer),
    ];

    return StatTileGrid(
      tiles: [
        tile('OnTheJob', dashboard.inProgressCount, dashboard.inProgress),
        tile('ComingUp', dashboard.upcomingCount, dashboard.upcoming),
        tile(
          'Completed',
          dashboard.profile?.jobsCompleted ?? 0,
          dashboard.completed,
        ),
        tile(
          'NeedsYou',
          dashboard.needsMyAnswerCount,
          waitingOnMe,
          tone: dashboard.needsMyAnswerCount > 0
              ? StatusTone.danger
              : StatusTone.success,
        ),
        // Which jobs made them a Lead, a Supervisor or Support. The role was only ever on the
        // job's own screen, so a worker on several jobs had to open each one to remember which
        // of them they were running.
        tile(
          _leadCount > 0 ? 'Leading' : 'MyRole',
          _roleJobs.length,
          _roleJobs,
          emptyCode: 'MyRole',
        ),
      ],
    );
  }
}

/// Full-time jobs the worker applied for, one tile per stage an application can be at.
///
/// The stages, their names, icons and colours, and their order all come from the
/// `VacancyApplication.Worker` label group — a stage added to the table becomes a tile here with
/// no change to this code. A stage with nothing in it stays grey, the way the business's
/// full-time tiles do.
class _FullTimeStats extends ConsumerWidget {
  const _FullTimeStats();

  static const _group = 'VacancyApplication.Worker';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applicationsAsync = ref.watch(myVacancyApplicationsProvider);

    if (applicationsAsync.hasError && !applicationsAsync.hasValue) {
      return ErrorBanner(message: applicationsAsync.error.toString());
    }

    final items = applicationsAsync.value;

    return StatTileGrid(
      tiles: [
        for (final code in UiConfig.current.codes(_group))
          _tile(
            context,
            code,
            items?.where((v) => applicationStage(v) == code).length,
          ),
      ],
    );
  }

  /// [count] is null while the applications are loading.
  Widget _tile(BuildContext context, String code, int? count) {
    final entry = UiConfig.current.entry(_group, code);
    return StatTile(
      label: entry.shortLabel,
      // A dash while loading rather than a spinner, so the section keeps its shape.
      value: count == null ? '–' : '$count',
      icon: entry.iconData,
      tone: (count ?? 0) > 0 ? entry.statusTone : StatusTone.waiting,
      onTap: () => pushScreen(
        context,
        MyVacancyApplicationsScreen(status: code, title: entry.label),
      ),
    );
  }
}

/// The way in to the worker's own details.
///
/// Shows enough to be worth a glance on its own — the picture, the name, the level, and whether
/// anything important is missing — so it earns its place on the home screen rather than being a link
/// dressed as a card. The same shape the business home uses for its profile.
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile});

  final WorkerProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // What a business would notice is missing, in the order it costs the worker most. Kept on the
    // home screen even though the details moved: a worker nobody can phone will not go looking.
    final missing = [
      if (profile.phoneNumber == null) 'phone number',
      if (!profile.hasPayoutDestination) 'UPI',
    ];

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => pushScreen(context, const WorkerProfileScreen()),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
          child: Row(
            children: [
              WorkerAvatar(photoUrl: profile.photoUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'YOUR PROFILE',
                      style: theme.textTheme.labelSmall?.copyWith(
                        letterSpacing: 0.9,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      profile.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      missing.isEmpty
                          ? 'Tap to view and edit your details'
                          // Named, not counted: "2 things missing" sends a worker hunting.
                          : 'Add your ${missing.join(' and ')} — tap to fix',
                      maxLines: 2,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: missing.isEmpty
                            ? theme.colorScheme.onSurfaceVariant
                            : theme.colorScheme.error,
                        fontWeight: missing.isEmpty ? null : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // The level, because it is the one thing here a worker watches change.
              WorkerLevelBadge(profile: profile, showNextStep: false),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A worker with no payout destination cannot be paid at all, so this is stated loudly.
class _PayoutWarning extends StatelessWidget {
  const _PayoutWarning({required this.profile});

  final WorkerProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasDestination = profile.hasPayoutDestination;

    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              hasDestination ? Icons.hourglass_top : Icons.error_outline,
              color: theme.colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasDestination
                        ? 'Your UPI is being checked'
                        : 'Add your UPI to get paid',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasDestination
                        ? 'Nothing for you to do. Wages can be sent once it is verified.'
                        : 'Until there is somewhere to send it, your wages cannot leave Zuno.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                  if (!hasDestination) ...[
                    const SizedBox(height: 8),
                    FilledButton.tonal(
                      onPressed: () =>
                          showWorkerProfileEditSheet(context, profile: profile),
                      child: const Text('Add UPI'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Six months of work, drawn by hand — the same shape the business dashboard uses.
class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.trend, required this.busiest});

  final List<WorkerMonthlyEarning> trend;
  final int busiest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Never divide by zero, and never let a single job fill the whole chart height.
    final ceiling = busiest < 1 ? 1 : busiest;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 10),
        child: Column(
          children: [
            SizedBox(
              height: 110,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final month in trend)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              month.jobsCompleted == 0
                                  ? ''
                                  : '${month.jobsCompleted}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 2),
                            // A quiet month still gets a sliver, so the axis reads as a row of
                            // months rather than a gap where nothing happened.
                            Container(
                              height: 4 + (74 * month.jobsCompleted / ceiling),
                              decoration: BoxDecoration(
                                color: month.jobsCompleted == 0
                                    ? theme.colorScheme.surfaceContainerHighest
                                    : theme.colorScheme.primary,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                for (final month in trend)
                  Expanded(
                    child: Text(
                      month.label,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Jobs finished each month',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
