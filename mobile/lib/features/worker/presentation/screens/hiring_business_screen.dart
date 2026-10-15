import 'package:zuno/core/utils/formatting.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/features/hiring_post/domain/entities/hiring_post.dart';
import 'package:zuno/features/worker/domain/entities/hiring_business.dart';
import 'package:zuno/features/worker/presentation/providers/worker_providers.dart';
import 'package:zuno/features/worker/presentation/widgets/job_details_sheet.dart';
import 'package:zuno/features/worker/presentation/widgets/single_job_map_screen.dart';
import 'package:zuno/shared/domain/business_trust.dart';
import 'package:zuno/shared/widgets/error_banner.dart';
import 'package:zuno/shared/widgets/section_header.dart';
import 'package:zuno/shared/widgets/status_pill.dart';
import 'package:zuno/shared/widgets/trust_cards.dart';

/// A hiring business as a worker sees it.
///
/// Salary is the hero, because that is what actually brings someone to a job. There are no star
/// ratings anywhere on this screen: a customer's opinion of the food tells a worker nothing
/// about whether they will be paid.
class HiringBusinessScreen extends ConsumerWidget {
  const HiringBusinessScreen({
    required this.businessId,
    this.fromPostId,
    super.key,
  });

  final String businessId;

  /// The job the worker arrived from, which is left out of the list below.
  ///
  /// Somebody who opened this page from a job already knows about that job — they are standing in
  /// it. Listing it back to them wastes the top of the one section that exists to show what *else*
  /// this business has, and tapping it leads in a circle: details, about the business, the same
  /// job, details again.
  final String? fromPostId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businessAsync = ref.watch(hiringBusinessProvider(businessId));

    return Scaffold(
      appBar: AppBar(title: const Text('About this business')),
      body: businessAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ErrorBanner(message: error.toString()),
          ),
        ),
        data: (business) => _Body(business: business, fromPostId: fromPostId),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.business, this.fromPostId});

  final HiringBusiness business;
  final String? fromPostId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pay = business.pay;

    // Everything this business has open except the job that brought the worker here.
    final otherPosts = [
      for (final post in business.openPosts)
        if (post.id != fromPostId) post,
    ];
    final good = AppColors.status(StatusTone.success, theme.brightness);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                business.businessName.isNotEmpty
                    ? business.businessName[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    business.businessName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (business.location case final where?)
                    Text(
                      where,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            if (business.isVerified)
              const StatusPill(
                label: 'Verified',
                tone: StatusTone.success,
                icon: Icons.verified_outlined,
                compact: true,
              ),
            if (business.hasEarnedLevel)
              StatusPill(
                label: '${business.levelName} · Level ${business.level}',
                tone: StatusTone.success,
                compact: true,
              ),
          ],
        ),
        const SizedBox(height: 18),

        // The hero. Everything below it exists to say whether this figure can be believed.
        if (pay.hasHires) _PayHero(business: business) else _NoHistoryYet(),

        if (pay.hasHires) ...[
          TrustCard(
            title: 'Do they pay what they promise?',
            headline: '${pay.paidPostedRateCount}/${pay.totalHires}',
            caption: 'jobs paid at the\nrate they posted',
            rows: [
              if (pay.raisedPayCount > 0)
                TrustRow(
                  'Raised pay above the post',
                  '${pay.raisedPayCount} ${pay.raisedPayCount == 1 ? 'job' : 'jobs'}',
                  tone: good,
                ),
              if (pay.crewsDue > 0)
                TrustRow(
                  'Crew paid after work',
                  '${pay.crewsPaid} of ${pay.crewsDue}',
                  tone: pay.crewsPaid == pay.crewsDue ? good : null,
                ),
              if (pay.payTimeLabel case final label?)
                TrustRow('Typical time to pay', label, tone: good),
              if (pay.hasRepeatCrew)
                TrustRow(
                  'Crew who came back',
                  '${pay.distinctWorkers} workers, ${pay.totalHires} hires',
                  tone: good,
                ),
            ],
          ),

          if (pay.openDisputes > 0 || pay.overdueWages > 0)
            _PayWarning(pay: pay),
        ],

        if (otherPosts.isNotEmpty) ...[
          SectionHeader(
            // "Other" once one has been left out, because the list no longer is all of them and a
            // worker counting four jobs against a heading that promises every one would be right
            // to wonder where the fifth went.
            title: otherPosts.length == business.openPosts.length
                ? 'Open jobs right now'
                : 'Other jobs open right now',
            count: otherPosts.length,
            padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
          ),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < otherPosts.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _OpenJobRow(post: otherPosts[i]),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// One of this business's open jobs, as a row that actually leads somewhere.
///
/// These were plain `ListTile`s with no `onTap`: a worker reading a business's page could see that
/// it had four jobs open, with pay and dates, and had no way to take any of them. Applying meant
/// going back to Find work and hunting for the same job in the feed.
///
/// So the row opens the same details sheet the feed and the map pins open — Apply included — and
/// carries the same two facts the feed card leads with: how far away it is, and where. Tapping that
/// line opens the map, as it does on the card.
class _OpenJobRow extends ConsumerWidget {
  const _OpenJobRow({required this.post});

  final HiringPost post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    // Distance first: on a business page every job is this business's, so how far it is, is the
    // thing that separates one row from the next.
    final whereParts = [
      post.distanceLabel,
      if (post.location case final at? when at.isNotEmpty) at,
    ].whereType<String>();

    return ListTile(
      onTap: () => showJobDetailsSheet(context, job: post),
      title: Text(
        post.title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(post.scheduleLabel),
          if (whereParts.isNotEmpty)
            InkWell(
              onTap: post.hasPosition
                  ? () => showJobOnMap(context, ref, post)
                  : null,
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    Icon(
                      Icons.place_outlined,
                      size: 13,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        whereParts.join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: post.hasPosition
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            post.salaryLabel,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 2),
          // Says the row leads somewhere. Without it the tap is a secret.
          Icon(
            Icons.chevron_right,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

/// The single number a worker came for.
class _PayHero extends StatelessWidget {
  const _PayHero({required this.business});

  final HiringBusiness business;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pay = business.pay;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
        child: Column(
          children: [
            Text(
              'WHAT THIS BUSINESS PAYS',
              style: theme.textTheme.labelSmall?.copyWith(
                letterSpacing: 0.8,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              pay.averageSalary == null ? '—' : rupees(pay.averageSalary!),
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'average ${pay.unitLabel}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (pay.salaryRangeLabel.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: theme.dividerColor)),
                ),
                child: Text(
                  '${pay.salaryRangeLabel}  across ${pay.totalHires} hires',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Saying "no history" plainly beats showing ₹0, which reads as a business that pays nothing.
class _NoHistoryYet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.hourglass_empty_rounded,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'This business has not hired anyone through Zuno yet, so there is no pay '
                'record to show. The salary on each job below is what they have advertised.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The one thing a worker most needs to know, so it is loud rather than a quiet row.
class _PayWarning extends StatelessWidget {
  const _PayWarning({required this.pay});

  final WorkerFacingTrust pay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final danger = theme.colorScheme.error;

    final parts = <String>[
      if (pay.openDisputes > 0)
        '${pay.openDisputes} ${pay.openDisputes == 1 ? 'worker has' : 'workers have'} '
            'reported not being paid',
      if (pay.overdueWages > 0)
        '${rupees(pay.overdueWages)} is owed on work already finished',
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: danger.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: danger.withValues(alpha: 0.32)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, size: 19, color: danger),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              '${parts.join('. ')}.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: danger,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
