import 'package:zuno/core/utils/formatting.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/constants/api_constants.dart';
import 'package:zuno/core/utils/relative_time.dart';
import 'package:zuno/features/hiring_post/domain/entities/hiring_post.dart';
import 'package:zuno/features/hiring_post/presentation/providers/worker_hiring_posts_notifier.dart';
import 'package:zuno/features/worker/presentation/screens/hiring_business_screen.dart';
import 'package:zuno/shared/widgets/error_banner.dart';
import 'package:latlong2/latlong.dart';
import 'package:zuno/features/worker/presentation/providers/worker_job_filter_provider.dart';
import 'package:zuno/features/worker/presentation/widgets/nearby_jobs_filter_bar.dart';
import 'package:zuno/features/worker/presentation/widgets/job_details_sheet.dart';
import 'package:zuno/features/worker/presentation/widgets/nearby_jobs_map.dart';
import 'package:zuno/features/worker/presentation/widgets/single_job_map_screen.dart';
import 'package:zuno/shared/widgets/empty_state.dart';
import 'package:zuno/shared/widgets/status_track.dart';
import 'package:zuno/shared/widgets/status_pill.dart';
import 'package:zuno/shared/widgets/app_messages.dart';
import 'package:zuno/core/theme/app_colors.dart';

class WorkerHiringPostsTab extends ConsumerStatefulWidget {
  const WorkerHiringPostsTab({super.key});

  @override
  ConsumerState<WorkerHiringPostsTab> createState() =>
      _WorkerHiringPostsTabState();
}

class _WorkerHiringPostsTabState extends ConsumerState<WorkerHiringPostsTab> {
  /// Map or list. A view preference, not a filter, so it stays local to the screen.
  bool _showingMap = false;

  /// Pulling the list down clears the location and starts the search over.
  ///
  /// A reset rather than a reload, by request. A worker who is moving between places sets one, works,
  /// and comes back expecting the screen to ask again rather than to keep searching around a town they
  /// have left — so the gesture that means "start again" empties the place instead of quietly
  /// re-running yesterday's search.
  ///
  /// The cost is real and worth stating: refreshing the jobs while keeping the place is no longer the
  /// same gesture. Setting the location again is what fetches them, which is one tap on the bar above.
  Future<void> _clearLocationAndReload() async {
    ref.read(workerJobFilterProvider.notifier).clear();

    // Said out loud, because a pull that empties the list would otherwise read as a failed load
    // rather than as the reset it is.
    if (mounted) {
      context.showInfoMessage(
        'Location cleared. Set where you are to see jobs.',
      );
    }

    // The feed watches the filter, so it empties on its own; awaited only so the spinner has
    // something to finish on.
    await ref.read(workerHiringPostsProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final postsAsync = ref.watch(workerHiringPostsProvider);
    final filter = ref.watch(workerJobFilterProvider);

    return Column(
      children: [
        // Outside the async switch on purpose: a worker must be able to reach the location controls
        // while the feed is still loading, and especially when it has failed.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          child: NearbyJobsFilterBar(
            showingMap: _showingMap,
            onToggleMap: () => setState(() => _showingMap = !_showingMap),
          ),
        ),
        // Finding work starts from a place. Until one is set there is nothing to show, and listing
        // every job in the country instead would bury the one thing the worker has to do.
        if (!filter.hasPosition)
          const Expanded(child: _AskForLocation())
        else
          Expanded(
            child: postsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ErrorBanner(message: error.toString()),
                ),
              ),
              data: (posts) => RefreshIndicator(
                onRefresh: _clearLocationAndReload,
                child: _Feed(
                  posts: posts,
                  filter: filter,
                  showingMap: _showingMap,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The jobs themselves: a map when asked for, otherwise a list in three groups.
class _Feed extends StatelessWidget {
  const _Feed({
    required this.posts,
    required this.filter,
    required this.showingMap,
  });

  final List<HiringPost> posts;
  final WorkerJobFilter filter;
  final bool showingMap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Only what the worker asked for. The server still sends a few jobs beyond the radius — ones
    // already applied to — and jobs with no location at all; both are dropped here, because a list
    // headed "within 2 km" that contains something 71 km away is a list nobody can trust.
    //
    // Nothing is lost by dropping them: an applied-to job appears on Home under what is waiting to be
    // paid, which is also where it can now be confirmed or disputed.
    final near = posts.where((post) {
      if (post.hasNoLocation) return false;
      if (filter.radiusKm case final radius?) {
        return (post.distanceKm ?? double.maxFinite) <= radius;
      }
      return true;
    }).toList();

    if (posts.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 50),
          EmptyState(
            icon: Icons.work_outline,
            title: filter.isFiltering
                ? 'No jobs within ${filter.radiusKm} km'
                : 'No hiring posts right now',
            message: filter.isFiltering
                ? 'Try a wider distance, or check back later.'
                : 'Check back later.',
          ),
        ],
      );
    }

    final mapJobs = near.where((p) => p.hasPosition).toList();

    // Map or cards, never both. A map squeezed above a list is too small to read and pushes the
    // cards off screen; picking one gives each the whole screen it needs.
    if (showingMap && filter.hasPosition) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(
          children: [
            Expanded(
              child: NearbyJobsMap(
                jobs: mapJobs,
                centre: LatLng(filter.latitude!, filter.longitude!),
                radiusKm: filter.radiusKm,
                // The job, not the business behind it. Somebody tapping a pin is asking "what is
                // this job?" — the business is a tap further in, from the details.
                onJobTapped: (job) => showJobDetailsSheet(context, job: job),
                fillAvailableHeight: true,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              mapJobs.isEmpty
                  ? 'No jobs with a location within ${filter.radiusKm} km.'
                  : mapJobs.length == 1
                  ? '1 job here. Tap the pin to see it.'
                  : '${mapJobs.length} jobs here. Tap a pin to see one.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        // The answer to what was asked, stated even when it is none. Twice now a reader has taken the
        // two groups below for the radius leaking, so the count within the radius is said outright.
        if (filter.isFiltering)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              near.isEmpty
                  ? 'No jobs within ${filter.radiusKm} km of '
                        '${filter.placeLabel ?? 'here'}.'
                  : near.length == 1
                  ? '1 job within ${filter.radiusKm} km'
                  : '${near.length} jobs within ${filter.radiusKm} km',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: near.isEmpty
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.onSurface,
              ),
            ),
          ),

        if (near.isEmpty && filter.isFiltering)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(
              'Try a wider distance. Anything below is outside that range.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),

        for (final post in near) ...[
          _PostCard(post: post),
          const SizedBox(height: 10),
        ],

        // Nothing else. This list answers one question — what work is within the chosen distance —
        // and anything outside that belongs elsewhere:
        //
        //   * a job already applied to is on Home, under what is waiting to be paid, where the
        //     confirm-or-dispute action now lives too;
        //   * a job whose business gave no location cannot be measured, so it cannot honestly appear
        //     in a distance result.
        //
        // The second of those hides most open posts today, which is a real cost and the reason
        // businesses need to be able to pin a job.
      ],
    );
  }
}

class _PostCard extends ConsumerStatefulWidget {
  const _PostCard({required this.post});

  final HiringPost post;

  @override
  ConsumerState<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<_PostCard> {
  bool _isApplying = false;

  Future<void> _apply() async {
    setState(() => _isApplying = true);
    try {
      await ref.read(workerHiringPostsProvider.notifier).apply(widget.post.id);
    } catch (e) {
      if (mounted) {
        context.showFailureMessage(
          e.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isApplying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (post.imageUrl != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: '${ApiConstants.baseUrl}${post.imageUrl}',
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      // Already started and still a hand short: say so, and say when it ends,
                      // so a worker can judge whether they can get there in time to matter.
                      if (post.isNeededNow()) ...[
                        const SizedBox(height: 4),
                        StatusPill(
                          icon: Icons.bolt,
                          label: 'NEEDED NOW',
                          tone: StatusTone.progress,
                          detail: 'ends ${formatTime(post.eventEndDate)}',
                          compact: true,
                        ),
                        const SizedBox(height: 2),
                      ],
                      // What kind of work it actually is. The reason a worker can skip a
                      // painting job that is not the painting they do.
                      if (post.serviceSubCategoryName case final kind?)
                        Text(
                          kind,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      // Tappable: before committing a day, a worker can now check what this
                      // business actually pays and whether it pays on time.
                      InkWell(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => HiringBusinessScreen(
                              businessId: post.businessOwnerProfileId,
                              // Opened from this job's card, so the page shows the business's
                              // other jobs rather than repeating the one in front of them.
                              fromPostId: post.id,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                post.businessName,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 15,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${post.eventDate.toLocal().toString().substring(0, 10)}'
                        '  ${post.scheduleLabel}',
                      ),
                      Text(
                        'Posted ${timeAgo(post.createdDate)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      // Distance and place on one line, with the map a tap away. This is what a
                      // worker scans the card for, so it reads as one thought rather than a list.
                      if (post.location case final where? when where.isNotEmpty)
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
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(
                                    [
                                      post.distanceLabel,
                                      where,
                                    ].where((p) => p != null).join(' · '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ),
                                if (post.hasPosition)
                                  Icon(
                                    Icons.map_outlined,
                                    size: 15,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
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
            if (post.description != null && post.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                post.description!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 10),
            _SalaryLine(post: post),
            // Once they are on the job, the same three tracks the business sees. Before that
            // it is just a listing, and progress bars on something they have not been given
            // would be noise.
            if (post.myOfferAccepted) ...[
              const SizedBox(height: 12),
              StatusTrackList(
                tracks: [
                  TrackRow(
                    name: 'Event',
                    state: post.eventState(),
                    detail: post.eventDetail(),
                  ),
                  TrackRow(
                    name: 'Work',
                    state: post.workersState(),
                    detail: post.workersDetail(),
                  ),
                  TrackRow(
                    name: 'My pay',
                    state: post.myPaymentState,
                    detail: post.myPaymentDetail,
                  ),
                ],
              ),
              _MyPaymentDecision(post: post),
            ],
            const SizedBox(height: 12),
            if (_isApplying)
              const Center(child: CircularProgressIndicator(strokeWidth: 2))
            else if (post.hasPendingOffer)
              _OfferDecision(post: post)
            else if (post.hasApplied)
              Align(
                alignment: Alignment.centerRight,
                child: Chip(
                  label: Text(switch (post.myApplicationStatus) {
                    'Applied' => 'Applied — awaiting the business',
                    'Accepted' => 'You accepted this job',
                    'Declined' => 'You declined this offer',
                    'Rejected' => 'Not selected',
                    final other => 'Applied: $other',
                  }, style: const TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: post.myOfferAccepted
                      ? AppColors.status(
                          StatusTone.success,
                          Theme.of(context).brightness,
                        ).withValues(alpha: 0.12)
                      : null,
                ),
              )
            // Gated on isOpenToWorkers, not isOpen: a post whose hiring is over is closed
            // even though its stored status still says Open, and the server would refuse.
            else if (post.isOpenToWorkers())
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _apply,
                  child: const Text('Apply'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The worker's half of the handshake. The business has approved them; nothing is settled
/// and no slot is taken until they answer here.
class _OfferDecision extends ConsumerStatefulWidget {
  const _OfferDecision({required this.post});

  final HiringPost post;

  @override
  ConsumerState<_OfferDecision> createState() => _OfferDecisionState();
}

class _OfferDecisionState extends ConsumerState<_OfferDecision> {
  bool _isResponding = false;

  Future<void> _respond(bool accept) async {
    final applicationId = widget.post.myApplicationId;
    if (applicationId == null) return;

    if (!accept) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Decline this job?'),
          content: const Text(
            'The business will be told and your place goes back to other applicants. '
            'You cannot take it back afterwards.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep deciding'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Decline'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() => _isResponding = true);
    try {
      await ref
          .read(workerHiringPostsProvider.notifier)
          .respondToOffer(applicationId: applicationId, accept: accept);
    } catch (e) {
      if (mounted) {
        context.showFailureMessage(
          e.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _isResponding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amount = widget.post.myAgreedSalaryAmount ?? widget.post.salaryAmount;
    final formatted = amount.truncateToDouble() == amount
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(2);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.mark_email_unread_outlined,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'You have been offered this job',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Accept to take it at ₹$formatted '
            '${salaryUnitWords(widget.post.salaryUnit)}. '
            'The place is not yours until you accept.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          if (_isResponding)
            const Center(child: CircularProgressIndicator(strokeWidth: 2))
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _respond(false),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _respond(true),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Approve'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Shows what this job pays. Once the worker is confirmed their own locked-in figure
/// takes over from the advertised one — that agreed amount is the binding number and
/// the business can no longer reduce it.
class _SalaryLine extends StatelessWidget {
  const _SalaryLine({required this.post});

  final HiringPost post;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final agreed = post.myAgreedSalaryAmount;
    final isAgreed = agreed != null;
    final amount = agreed ?? post.salaryAmount;
    final formatted = amount.truncateToDouble() == amount
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(2);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            isAgreed ? Icons.verified_outlined : Icons.payments_outlined,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '₹$formatted ${salaryUnitWords(post.salaryUnit)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
                if (isAgreed)
                  Text(
                    'Locked in for you. This cannot be reduced.',
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The worker's answer on whether their wages actually arrived.
///
/// The business marking someone paid is only its own word, and a payout provider reporting
/// success says the instruction was accepted rather than that money landed. The person whose
/// account it should have reached is the one who knows — so this is what finally closes a
/// payment, and reporting it missing is what holds the job open against the business.
class _MyPaymentDecision extends ConsumerStatefulWidget {
  const _MyPaymentDecision({required this.post});

  final HiringPost post;

  @override
  ConsumerState<_MyPaymentDecision> createState() => _MyPaymentDecisionState();
}

class _MyPaymentDecisionState extends ConsumerState<_MyPaymentDecision> {
  bool _isResponding = false;

  HiringPost get post => widget.post;

  Future<void> _respond({required bool received}) async {
    final applicationId = post.myApplicationId;
    if (applicationId == null) return;

    String? reason;

    if (!received) {
      // A dispute is a serious claim against someone's livelihood, so it is made deliberately
      // and in the worker's own words rather than on a single stray tap.
      final controller = TextEditingController();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Report this as unpaid?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Only do this if the money never reached your account. The business will be '
                'flagged and this job stays open until it is sorted out.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'What happened? (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Report'),
            ),
          ],
        ),
      );

      if (confirmed != true || !mounted) return;
      reason = controller.text.trim().isEmpty ? null : controller.text.trim();
    }

    setState(() => _isResponding = true);
    try {
      await ref
          .read(workerHiringPostsProvider.notifier)
          .respondToPayment(
            applicationId: applicationId,
            received: received,
            disputeReason: reason,
          );
    } catch (e) {
      if (mounted) {
        context.showFailureMessage(
          e.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _isResponding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (post.isMyPaymentDisputed) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text(
          'You reported this as unpaid. Zuno has flagged the business.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
      );
    }

    if (!post.canRespondToMyPayment) return const SizedBox.shrink();

    if (_isResponding) {
      return const Padding(
        padding: EdgeInsets.only(top: 12),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Did this money reach your account?',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _respond(received: true),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Yes, received'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _respond(received: false),
                  child: const Text('Not paid'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shown until the worker says where they are.
///
/// Explains the reason rather than only blocking: a worker who understands that jobs are listed by
/// distance knows why the app is asking, and the two ways in are on the bar just above.
class _AskForLocation extends StatelessWidget {
  const _AskForLocation();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 0, 32, 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.explore_outlined,
              size: 52,
              color: theme.colorScheme.primary.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              'Where are you working from?',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Jobs are listed by how far they are from you. Use the buttons above to share your '
              'location or type a place.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
