import 'package:zuno/core/utils/formatting.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/shared/widgets/app_messages.dart';
import 'package:zuno/core/constants/api_constants.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/features/business_owner/presentation/widgets/create_hiring_post_sheet.dart';
import 'package:zuno/features/business_owner/presentation/widgets/invite_worker_dialog.dart';
import 'package:zuno/features/business_owner/presentation/widgets/raise_salary_dialog.dart';
import 'package:zuno/features/hiring_post/domain/entities/hiring_post.dart';
import 'package:zuno/features/hiring_post/domain/entities/hiring_post_application.dart';
import 'package:zuno/features/hiring_post/presentation/providers/business_hiring_posts_notifier.dart';
import 'package:zuno/shared/widgets/error_banner.dart';
import 'package:zuno/shared/widgets/call_icon_button.dart';
import 'package:zuno/shared/widgets/status_pill.dart';

class BusinessHiringPostsTab extends ConsumerWidget {
  const BusinessHiringPostsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(businessHiringPostsProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showCreateHiringPostSheet(context),
        icon: const Icon(Icons.campaign_outlined),
        label: const Text('Post for hire'),
      ),
      body: postsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ErrorBanner(message: error.toString()),
          ),
        ),
        data: (posts) {
          if (posts.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No hiring posts yet. Post an event to recruit extra workers.',
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.refresh(businessHiringPostsProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: posts.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _PostCard(post: posts[index]),
            ),
          );
        },
      ),
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
  bool _isDeleting = false;

  HiringPost get post => widget.post;

  Future<void> _confirmAndDelete() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(post.isLapsed() ? 'Remove this post?' : 'Delete this post?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              post.isLapsed()
                  // Nobody was hired and nothing was owed, so there is no one to let down
                  // and nothing to warn about.
                  ? '"${post.title}" was never filled, so removing it costs nothing. Your '
                        'profile and rating are untouched either way.'
                  : '"${post.title}" and its ${post.applications.length} applicant record(s) '
                        'will be removed from your dashboard. This cannot be undone from the app.',
            ),
            if (post.deleteNeedsStrongWarning) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.errorContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${post.confirmedCount} worker(s) are confirmed for an event that '
                  'has not happened yet. They will lose the record of the address, '
                  'time and agreed salary. Tell them before you delete this.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
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
            child: Text(post.isLapsed() ? 'Remove' : 'Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      await ref.read(businessHiringPostsProvider.notifier).deletePost(post.id);
    } catch (e) {
      if (mounted) {
        context.showFailureMessage(e.toString().replaceFirst('Exception: ', ''));
        setState(() => _isDeleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settled = post.isSuccessfullyCompleted();
    final lapsed = post.isLapsed();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- Header ----------------------------------------------------------------
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (post.imageUrl != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CachedNetworkImage(
                      imageUrl: '${ApiConstants.baseUrl}${post.imageUrl}',
                      width: 52,
                      height: 52,
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
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (post.serviceSubCategoryName case final kind?)
                        Text(
                          kind,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      // Says which order this hire is for, so a business running several jobs
                      // at once can tell its posts apart at a glance.
                      if (post.bookingReference case final order?) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(
                              Icons.assignment_outlined,
                              size: 13,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'For order: $order',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 2),
                      Text(
                        '${formatDate(post.eventDate.toLocal())}'
                        ' · ${post.scheduleLabel}',
                        style: theme.textTheme.bodySmall,
                      ),
                      if (post.location case final where? when where.isNotEmpty)
                        Text(
                          where,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Edit and delete moved behind one menu. They are rare, and the top-right
                // corner is better spent on the state of the job than on two icons.
                if (_isDeleting)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20),
                    tooltip: 'More',
                    onSelected: (value) {
                      if (value == 'edit') {
                        showCreateHiringPostSheet(context, post: post);
                      } else if (value == 'delete') {
                        _confirmAndDelete();
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.edit_outlined, size: 20),
                          title: Text('Edit post'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.delete_outline,
                            size: 20,
                            color: theme.colorScheme.error,
                          ),
                          title: Text(
                            'Delete post',
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),

            const SizedBox(height: 10),

            // ---- Headline state + salary -----------------------------------------------
            // A Wrap, not a Row: a pill carrying a detail plus a locked salary label together
            // needed more than a 360dp card has, and the pair overflowed by 76px. Given the
            // choice between truncating the crew count and letting the salary take its own
            // line, the second loses nothing.
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                if (settled)
                  const StatusPill(
                    icon: Icons.workspace_premium_outlined,
                    label: 'SUCCESSFULLY COMPLETED',
                    tone: StatusTone.success,
                  )
                else if (lapsed)
                  const StatusPill(
                    icon: Icons.event_busy_outlined,
                    label: 'NOT FILLED',
                    tone: StatusTone.waiting,
                    detail: 'the date passed',
                  )
                // Once the job has run, the hiring target stops being the story — the crew
                // that turned up is. Showing "1/2 hired" on a finished job reads as a
                // shortfall the business can still do something about, and it cannot.
                else if (post.isWorkStarted)
                  StatusPill(
                    icon: Icons.groups,
                    label: '${post.filledCount} '
                        '${post.filledCount == 1 ? 'worker' : 'workers'}',
                    tone: StatusTone.success,
                    detail: post.isWorkCompleted ? 'worked this job' : 'on the job',
                  )
                else
                  StatusPill(
                    icon: post.isFullyStaffed
                        ? Icons.groups
                        : Icons.group_add_outlined,
                    label: '${post.filledCount}/${post.workersNeeded} hired',
                    tone: post.isFullyStaffed
                        ? StatusTone.success
                        : StatusTone.progress,
                    detail: post.pendingOfferCount > 0
                        ? '${post.pendingOfferCount} awaiting reply'
                        : null,
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (post.isSalaryLocked) ...[
                      Icon(
                        Icons.lock_outline,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      post.salaryLabel,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // No event, work or payment tracks here, and no Start / Complete / Pay buttons.
            // This tab is for hiring: who is needed, who applied, who is on it. Where the job
            // itself has got to — and what to do about it next — lives in Orders → Status
            // management, so one job is not worked from two screens.

            // A post nobody took is dead weight on the dashboard, and businesses reasonably
            // fear it counts against them. It does not — so say so plainly, and offer the one
            // thing worth doing with it.
            if (lapsed)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nobody took this job before the date. It does not count against '
                        'your profile or your rating — only jobs you finish and pay for '
                        'are counted, and this one was never worked.',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          // Moving it to a future date puts the same post back in the worker
                          // feed — better than deleting and retyping everything.
                          TextButton.icon(
                            onPressed: () =>
                                showCreateHiringPostSheet(context, post: post),
                            icon: const Icon(Icons.event_repeat_outlined, size: 18),
                            label: const Text('Give it a new date'),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _confirmAndDelete,
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: const Text('Remove it'),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              foregroundColor: theme.colorScheme.error,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            // ---- Crew ------------------------------------------------------------------
            const SizedBox(height: 4),
            _CrewSection(post: post),
          ],
        ),
      ),
    );
  }
}

/// Everyone on the job, folded away until it matters.
///
/// Expands itself whenever somebody is waiting on the business — an unanswered applicant, or a
/// payment that failed — so a tidy card never costs anyone a missed decision.
class _CrewSection extends StatelessWidget {
  const _CrewSection({required this.post});

  final HiringPost post;

  bool get _needsAttention =>
      post.applications.any((a) => a.isApplied) ||
      post.applications.any((a) => a.isPaymentFailed || a.isPaymentDisputed);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Same test the invite picker uses, so a job cannot be hidden from one route and offered
    // from the other.
    final canInvite = post.isInvitable();

    return Theme(
      // The default divider makes an ExpansionTile look like a separate card inside a card.
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: _needsAttention,
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        title: Row(
          children: [
            Text('Crew', style: theme.textTheme.labelLarge),
            const SizedBox(width: 8),
            // Yields to the NEEDS YOU pill rather than pushing it off the edge: the pill is the
            // part that asks for an action, so it is the part that must stay legible.
            Flexible(
              child: Text(
                // "1 of 2" only means something while there are still places to fill. Once the
                // job has run, the target is history and the count is simply who worked it --
                // otherwise a finished job reads as though a worker is missing from the list.
                post.isWorkStarted
                    ? '${post.filledCount} worked this job'
                    : '${post.filledCount} of ${post.workersNeeded}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (_needsAttention) ...[
              const SizedBox(width: 8),
              const StatusPill(
                label: 'NEEDS YOU',
                tone: StatusTone.progress,
                compact: true,
              ),
            ],
          ],
        ),
        children: [
          if (post.applications.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Nobody yet. Invite someone you know, or wait for applications.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ...post.applications.map(
            (application) => _ApplicationRow(
              application: application,
              isPostFull: !post.canOfferAnotherWorker,
              canCall: post.canCallCrewMember(application),
            ),
          ),
          if (canInvite)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: TextButton.icon(
                onPressed: () => showInviteWorkerDialog(context, post: post),
                icon: const Icon(Icons.person_add_alt_1, size: 18),
                label: const Text('Invite worker'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ApplicationRow extends ConsumerStatefulWidget {
  const _ApplicationRow({
    required this.application,
    required this.isPostFull,
    required this.canCall,
  });

  final HiringPostApplication application;

  /// Worked out by the post, which is the only thing that knows whether the job is over.
  final bool canCall;

  /// When the post has all the workers it needs the server refuses further
  /// confirmations, so the action is disabled here rather than failing on tap.
  final bool isPostFull;

  @override
  ConsumerState<_ApplicationRow> createState() => _ApplicationRowState();
}

class _ApplicationRowState extends ConsumerState<_ApplicationRow> {
  bool _isProcessing = false;

  Future<void> _respond({required bool confirm}) async {
    setState(() => _isProcessing = true);
    try {
      if (confirm) {
        await ref
            .read(businessHiringPostsProvider.notifier)
            .confirmApplication(widget.application.id);
      } else {
        await ref
            .read(businessHiringPostsProvider.notifier)
            .rejectApplication(widget.application.id);
      }
    } catch (e) {
      if (mounted) {
        context.showFailureMessage(e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _showDetails() async {
    final application = widget.application;
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(application.workerName),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailLine(
                label: 'Phone',
                value: application.workerPhone ?? 'No phone number on file',
              ),
              _DetailLine(
                label: 'Applied on',
                value: application.appliedAt.toLocal().toString().substring(
                  0,
                  16,
                ),
              ),
              _DetailLine(label: 'Status', value: application.statusLabel),
              if (application.hasAgreedSalary)
                _AgreedSalarySection(application: application),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          if (application.isApplied) ...[
            TextButton(
              onPressed: () => Navigator.of(context).pop('reject'),
              child: const Text('Reject'),
            ),
            FilledButton(
              onPressed: widget.isPostFull
                  ? null
                  : () => Navigator.of(context).pop('confirm'),
              child: Text(widget.isPostFull ? 'Post is full' : 'Confirm'),
            ),
          ] else if ((application.isAccepted || application.isOfferPending) && application.hasAgreedSalary)
            FilledButton.tonal(
              onPressed: () => Navigator.of(context).pop('raise'),
              child: const Text('Raise salary'),
            ),
        ],
      ),
    );

    if (!mounted) return;

    switch (action) {
      case 'confirm':
        await _respond(confirm: true);
      case 'reject':
        await _respond(confirm: false);
      case 'raise':
        await showRaiseSalaryDialog(context, application: application);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final application = widget.application;

    return InkWell(
      onTap: _showDetails,
      child: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    application.workerName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (application.hasAgreedSalary)
                    Text(
                      'Agreed ${rupees(application.agreedSalaryAmount!)}'
                      '${application.hasBeenRaised ? ' · raised' : ''}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  // Their earlier job has run past its finish time, so this one is at risk.
                  // Shown while there is still time to arrange cover.
                  if (application.delayRisk != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.schedule_outlined,
                            size: 14,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              application.delayRisk!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (_isProcessing)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (application.isApplied) ...[
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'Reject',
                onPressed: () => _respond(confirm: false),
              ),
              IconButton(
                icon: const Icon(Icons.check_circle_outline, size: 18),
                tooltip: widget.isPostFull
                    ? 'Post is already fully staffed'
                    : 'Confirm',
                onPressed: widget.isPostFull
                    ? null
                    : () => _respond(confirm: true),
              ),
            ] else
              // Flexible, because the pills are the one part of this row with no give: two of
              // them plus the call button can want more than a 360dp card has, and the pill
              // text ellipsises rather than pushing the button off the edge.
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StatusPill(
                      label: application.statusLabel,
                      tone: _statusTone(application),
                      compact: true,
                    ),
                    // Where this worker's own wages have got to. Only the crew-wide figure was
                    // shown before, so a single failed payout was invisible against three
                    // successful ones.
                    if (application.paymentLabel != null) ...[
                      const SizedBox(height: 4),
                      StatusPill(
                        label: application.paymentLabel!,
                        tone: _paymentTone(application),
                        compact: true,
                      ),
                    ],
                  ],
                ),
              ),
            // Beside the pills, not beneath them: in the isApplied branch above the actions sit
            // flush right, and stacking a 48dp button under two pills would treble the height of
            // every crew row.
            if (widget.canCall)
              CallIconButton(
                phoneNumber: application.workerPhone!,
                tooltip: 'Call worker',
                iconSize: 18,
              ),
          ],
        ),
      ),
    );
  }
}

/// The worker-facing record: what was agreed at confirmation and every raise since.
/// Shown to the business too, so both sides see the same trail.
class _AgreedSalarySection extends StatelessWidget {
  const _AgreedSalarySection({required this.application});

  final HiringPostApplication application;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final original = application.originalAgreedSalary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 20),
        Text('Agreed salary', style: theme.textTheme.labelMedium),
        const SizedBox(height: 2),
        Text(
          '${rupees(application.agreedSalaryAmount!)} '
          '${salaryUnitWords(application.agreedSalaryUnit ?? 'PerEvent')}',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.primary,
          ),
        ),
        if (application.hasBeenRaised && original != null) ...[
          const SizedBox(height: 2),
          Text(
            'Locked in at ${rupees(original)} on confirmation.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Text('Raises', style: theme.textTheme.labelMedium),
          ...application.salaryAdjustments.map(
            (adjustment) => Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${rupees(adjustment.previousAmount)} → '
                '${rupees(adjustment.newAmount)} on '
                '${adjustment.adjustedAt.toLocal().toString().substring(0, 16)}'
                '${adjustment.reason == null ? '' : ' — ${adjustment.reason}'}',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          Text(value),
        ],
      ),
    );
  }
}


/// Tone per application state. "Awaiting worker" is deliberately the in-flight tone rather than
/// the danger one — a pending offer is neither a win nor a loss, it is simply unresolved.
StatusTone _statusTone(HiringPostApplication application) {
  if (application.isAccepted) return StatusTone.success;
  if (application.isOfferPending) return StatusTone.progress;
  if (application.isApplied) return StatusTone.waiting;
  return StatusTone.danger;
}

StatusTone _paymentTone(HiringPostApplication application) {
  if (application.isPaid) return StatusTone.success;
  if (application.isPaymentFailed || application.isPaymentDisputed) {
    return StatusTone.danger;
  }
  return StatusTone.progress;
}
