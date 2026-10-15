import 'package:zuno/core/utils/formatting.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/constants/api_constants.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/features/business_owner/domain/entities/business_dashboard.dart';
import 'package:zuno/features/business_owner/presentation/providers/business_dashboard_notifier.dart';
import 'package:zuno/features/business_owner/presentation/providers/business_profile_notifier.dart';
import 'package:zuno/features/business_owner/presentation/screens/business_profile_tab.dart';
import 'package:zuno/features/business_owner/presentation/screens/dashboard_detail_screens.dart';
import 'package:zuno/shared/widgets/empty_state.dart';
import 'package:zuno/shared/widgets/error_banner.dart';
import 'package:zuno/shared/widgets/section_header.dart';
import 'package:zuno/shared/widgets/status_pill.dart';
import 'package:zuno/shared/widgets/trust_cards.dart';

/// The business home screen.
///
/// Leads with what the business has actually delivered, and lets that number open up: tap
/// "orders finished" and it splits by category, then by the kind of work inside each one.
class BusinessDashboardTab extends ConsumerWidget {
  const BusinessDashboardTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(businessDashboardProvider);

    return dashboardAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ErrorBanner(message: error.toString()),
        ),
      ),
      data: (dashboard) => RefreshIndicator(
        onRefresh: () => ref.refresh(businessDashboardProvider.future),
        child: _Body(dashboard: dashboard),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.dashboard});

  final BusinessDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _CompletedCard(dashboard: dashboard),
        const SizedBox(height: 12),
        _QuickStats(dashboard: dashboard),
        const SizedBox(height: 12),
        const _ProfileCard(),
        const SizedBox(height: 4),

        const SectionHeader(
          title: 'Customer activity',
          padding: EdgeInsets.fromLTRB(0, 18, 0, 8),
        ),
        _TrendChart(dashboard: dashboard),

        const SectionHeader(
          title: 'Your standing',
          padding: EdgeInsets.fromLTRB(0, 22, 0, 8),
        ),
        CustomerTrustCard(trust: dashboard.trust.customers),
        WorkerTrustCard(trust: dashboard.trust.workers),
      ],
    );
  }
}

/// The headline. Tapping it opens the category split.
class _CompletedCard extends StatelessWidget {
  const _CompletedCard({required this.dashboard});

  final BusinessDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canOpen = dashboard.byCategory.isNotEmpty;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: canOpen
            ? () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => CompletedBreakdownScreen(dashboard: dashboard),
                ),
              )
            : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 14, 18),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      // "Orders finished", not "events completed": this counts work done,
                      // while the profile's completed-jobs figure also requires the crew to
                      // have been paid. Two honest names beat one word meaning two things.
                      'ORDERS FINISHED',
                      style: theme.textTheme.labelSmall?.copyWith(
                        letterSpacing: 0.9,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${dashboard.eventsCompleted}',
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.primary,
                            height: 1,
                          ),
                        ),
                        if (dashboard.totalRevenue > 0) ...[
                          const SizedBox(width: 10),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Text(
                              '${rupees(dashboard.totalRevenue)} earned',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      canOpen
                          ? 'Tap to see the split by category'
                          : 'No finished orders yet',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: canOpen
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                        fontWeight: canOpen ? FontWeight.w600 : null,
                      ),
                    ),
                  ],
                ),
              ),
              if (canOpen)
                Icon(
                  Icons.chevron_right_rounded,
                  color: theme.colorScheme.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The way into the business's own details, now that they are not a bottom-bar destination.
///
/// Shows enough to be worth a glance on its own — the name customers see, the verification
/// state, and where the business is — so it earns its place on the home screen rather than
/// being a link dressed as a card.
class _ProfileCard extends ConsumerWidget {
  const _ProfileCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(businessProfileProvider);

    // Null while it loads or if it fails: the card still draws, and the page behind it reports
    // any error properly rather than this card trying to.
    final profile = profileAsync.maybeWhen(
      data: (p) => p,
      orElse: () => null,
    );
    final isVerified = profile?.verificationStatus == 'Verified';

    // Only the parts that were actually filled in, so a half-finished address does not read
    // as "Thrissur, , ".
    final where = [
      profile?.city,
      profile?.state,
    ].whereType<String>().where((p) => p.trim().isNotEmpty).join(', ');

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // Tappable even while the profile is still loading: the page it opens does its own
        // loading, and a card that ignores the first tap feels broken.
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const BusinessProfileScreen(),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 21,
                backgroundColor: theme.colorScheme.primaryContainer,
                backgroundImage: switch (profile?.logoUrl) {
                  final url? when url.isNotEmpty => NetworkImage(
                    '${ApiConstants.baseUrl}$url',
                  ),
                  _ => null,
                },
                child: (profile?.logoUrl?.isNotEmpty ?? false)
                    ? null
                    : Icon(
                        Icons.storefront_outlined,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'YOUR BUSINESS',
                      style: theme.textTheme.labelSmall?.copyWith(
                        letterSpacing: 0.9,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      profile?.businessName ?? 'Your business',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      where.isEmpty
                          ? 'Tap to add your details'
                          : '$where · tap to view and edit',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (profile != null)
                StatusPill(
                  label: isVerified ? 'Verified' : profile.verificationStatus,
                  tone: isVerified ? StatusTone.success : StatusTone.waiting,
                  compact: true,
                ),
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

class _QuickStats extends StatelessWidget {
  const _QuickStats({required this.dashboard});

  final BusinessDashboard dashboard;

  /// Tiles per row. Three is as many as fits before the labels start truncating on a phone,
  /// so the fourth and fifth wrap onto a second row rather than squeezing.
  static const _perRow = 3;

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      _StatTile(
        label: 'Upcoming',
        value: '${dashboard.upcomingEvents}',
        icon: Icons.event_outlined,
        tone: StatusTone.progress,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => BookingListScreen(
              title: 'Upcoming events',
              events: dashboard.upcoming,
              mode: BookingListMode.upcoming,
            ),
          ),
        ),
      ),
      _StatTile(
        label: 'Finished',
        value: '${dashboard.eventsCompleted}',
        icon: Icons.task_alt_outlined,
        tone: StatusTone.success,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => BookingListScreen(
              title: 'Finished orders',
              events: dashboard.completed,
              mode: BookingListMode.completed,
            ),
          ),
        ),
      ),
      _StatTile(
        label: 'Cancelled',
        value: '${dashboard.cancelledEvents}',
        icon: Icons.event_busy_outlined,
        tone: dashboard.cancelledEvents > 0
            ? StatusTone.danger
            : StatusTone.waiting,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => BookingListScreen(
              title: 'Cancelled events',
              events: dashboard.cancelled,
              mode: BookingListMode.cancelled,
            ),
          ),
        ),
      ),
      _StatTile(
        label: 'Crew events',
        value: '${dashboard.crewEventsCompleted}',
        icon: Icons.groups_outlined,
        tone: StatusTone.success,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CrewEventListScreen(events: dashboard.crewEvents),
          ),
        ),
      ),
      _StatTile(
        label: 'Active workers',
        value: '${dashboard.activeWorkers}',
        icon: Icons.badge_outlined,
        tone: dashboard.activeWorkers > 0
            ? StatusTone.progress
            : StatusTone.waiting,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ActiveWorkerListScreen(workers: dashboard.workers),
          ),
        ),
      ),
    ];

    return Column(
      children: [
        for (var start = 0; start < tiles.length; start += _perRow) ...[
          if (start > 0) const SizedBox(height: 10),
          // IntrinsicHeight, not CrossAxisAlignment.stretch. This Column sits in a ListView,
          // so its height is unbounded — and stretch would hand the tiles an infinite height
          // to fill, which fails the whole viewport's layout, not just this row.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = start; i < start + _perRow; i++) ...[
                  if (i > start) const SizedBox(width: 10),
                  // A short last row keeps the tile width of a full one, so every tile on the
                  // screen is the same size rather than the last two stretching to fill.
                  Expanded(child: i < tiles.length ? tiles[i] : const SizedBox()),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.tone,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final StatusTone tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colour = AppColors.status(tone, theme.brightness);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 17, color: colour),
                  const Spacer(),
                  // A quiet affordance rather than a button: the tile is the target, and three
                  // of these in a row should not read as three calls to action.
                  if (onTap != null)
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 15,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Six months of completed bookings, drawn as bars.
///
/// Hand-drawn rather than pulled from a charting package: it is a handful of bars, and the
/// app ships no chart library.
class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.dashboard});

  final BusinessDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!dashboard.hasTrend) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
          child: Column(
            children: [
              Icon(
                Icons.show_chart_rounded,
                size: 28,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 10),
              Text(
                'No completed bookings in the last 6 months',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'This chart fills in as customers book and you complete their events.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11.5,
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // The tallest bar sets the scale, with a floor of 1 so a single booking is not full height.
    final peak = dashboard.busiestMonthCount.clamp(1, 1 << 30);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Events completed per month',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 120,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final month in dashboard.trend)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              month.completed == 0 ? '' : '${month.completed}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            // A zero month still gets a sliver, so the axis reads as a row of
                            // months rather than gaps where nothing happened.
                            Container(
                              height: month.completed == 0
                                  ? 3
                                  : 6 + (76 * month.completed / peak),
                              decoration: BoxDecoration(
                                color: month.completed == 0
                                    ? theme.colorScheme.onSurfaceVariant
                                          .withValues(alpha: 0.22)
                                    : theme.colorScheme.primary,
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              month.label,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 10.5,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
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

/// The split behind the headline: category, then the kinds of work inside it.
class CompletedBreakdownScreen extends StatelessWidget {
  const CompletedBreakdownScreen({required this.dashboard, super.key});

  final BusinessDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Events completed')),
      body: dashboard.byCategory.isEmpty
          ? const EmptyState(
              icon: Icons.category_outlined,
              title: 'Nothing completed yet',
              message:
                  'Once you finish a customer booking it will appear here, grouped by the '
                  'kind of work.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Text(
                  '${dashboard.eventsCompleted} completed across '
                  '${dashboard.byCategory.length} '
                  '${dashboard.byCategory.length == 1 ? 'category' : 'categories'}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                for (final category in dashboard.byCategory)
                  _CategoryCard(
                    category: category,
                    total: dashboard.eventsCompleted,
                  ),
              ],
            ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category, required this.total});

  final CategoryBreakdown category;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final share = total == 0 ? 0.0 : category.count / total;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    category.categoryName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${category.count}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            if (category.revenue > 0)
              Text(
                '${rupees(category.revenue)} earned',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: share,
                minHeight: 6,
                backgroundColor: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.15,
                ),
              ),
            ),
            const SizedBox(height: 6),
            for (final sub in category.subCategories)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Expanded(
                      child: Text(sub.name, style: theme.textTheme.bodyMedium),
                    ),
                    if (sub.revenue > 0) ...[
                      Text(
                        rupees(sub.revenue),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Text(
                      '${sub.count}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
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
