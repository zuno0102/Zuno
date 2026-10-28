import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:zuno/shared/widgets/detail_row.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/constants/api_constants.dart';
import 'package:zuno/core/ui_config/ui_config.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/features/hiring_post/domain/entities/hiring_post.dart';
import 'package:zuno/features/hiring_post/presentation/providers/hiring_post_providers.dart';
import 'package:zuno/features/hiring_post/presentation/providers/worker_hiring_posts_notifier.dart';
import 'package:zuno/features/hiring_post/presentation/providers/worker_post_jobs_notifier.dart';
import 'package:zuno/features/worker/presentation/widgets/job_role_banner.dart';
import 'package:latlong2/latlong.dart';
import 'package:zuno/features/worker/presentation/providers/worker_job_filter_provider.dart';
import 'package:zuno/features/worker/presentation/screens/hiring_business_screen.dart';
import 'package:zuno/features/worker/presentation/widgets/single_job_map_screen.dart';
import 'package:zuno/features/work_chat/presentation/screens/work_chat_screen.dart';
import 'package:zuno/shared/widgets/call_icon_button.dart';
import 'package:zuno/shared/widgets/status_pill.dart';
import 'package:zuno/shared/widgets/app_messages.dart';
import 'package:zuno/features/hiring_post/presentation/providers/worker_job_offers_notifier.dart';
import 'package:zuno/core/router/push_screen.dart';
import 'package:zuno/shared/widgets/confirm_dialog.dart';

/// One job, in full, with the decision at the bottom.
///
/// Opened from a map pin, where there is no room to show a whole card. Everything a worker needs to
/// decide is here — pay, when, where, how far, who is hiring — and Apply is on the same sheet so the
/// answer does not require closing it and hunting for the card in the list.
Future<void> showJobDetailsSheet(
  BuildContext context, {
  required HiringPost job,
  bool showBusinessLink = true,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) =>
        _JobDetailsSheet(job: job, showBusinessLink: showBusinessLink),
  );
}

class _JobDetailsSheet extends ConsumerStatefulWidget {
  const _JobDetailsSheet({required this.job, this.showBusinessLink = true});

  /// Whether to offer the business behind the job.
  ///
  /// Off for an invitation. A business that picked this worker by name is not a stranger to be
  /// checked out — the question there is the job, and a second button under the first one competes
  /// with the answer the screen exists to collect.
  final bool showBusinessLink;

  final HiringPost job;

  @override
  ConsumerState<_JobDetailsSheet> createState() => _JobDetailsSheetState();
}

class _JobDetailsSheetState extends ConsumerState<_JobDetailsSheet> {
  bool _isApplying = false;

  Future<void> _apply() async {
    setState(() => _isApplying = true);

    // Captured before the await: applying refreshes the feed, which can dispose this sheet's
    // element while the call is still in flight.
    final navigator = Navigator.of(context);
    final messenger = AppMessenger.of(context);
    final notifier = ref.read(workerHiringPostsProvider.notifier);

    try {
      await notifier.apply(widget.job.id);
      navigator.pop();
      messenger.showSuccess('Applied. The business will be in touch.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isApplying = false);
      messenger.showFailure(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final job = widget.job;

    return DraggableScrollableSheet(
      expand: false,
      // Opens tall. At 0.7 the Apply button sat below the fold on a normal phone, so the sheet
      // whose whole job is to let somebody take the work opened without the way to take it.
      initialChildSize: 0.88,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Column(
        children: [
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
              children: [
                // A grab handle, because this sheet is draggable and nothing else says so.
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                if (job.imageUrl != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: '${ApiConstants.baseUrl}${job.imageUrl}',
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                Text(
                  job.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (job.serviceSubCategoryName case final kind?)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      kind,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                const SizedBox(height: 14),

                // The pay, given the most room. It is the first thing a worker looks for.
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'WHAT YOU GET PAID',
                        style: theme.textTheme.labelSmall?.copyWith(
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${rupees(job.myAgreedSalaryAmount ?? job.salaryAmount)} '
                        '${salaryUnitWords(job.salaryUnit)}',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      if (job.myAgreedSalaryAmount != null)
                        Text(
                          'Locked in for you. This cannot be reduced.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                DetailRow.icon(
                  icon: Icons.event_outlined,
                  label: 'When',
                  value: '${formatDate(job.eventDate)} · ${job.scheduleLabel}',
                ),
                DetailRow.icon(
                  icon: Icons.place_outlined,
                  label: 'Where',
                  value: [
                    job.location,
                    job.districtName,
                  ].where((p) => p != null && p.isNotEmpty).join(', '),
                  // Said plainly, because an approximate pin can send somebody to the wrong street.
                  detail: job.hasNoLocation
                      ? 'The business did not give a location'
                      : job.isLocationApproximate
                      ? 'Approximate location'
                      : null,
                ),
                if (job.distanceLabel case final distance?)
                  DetailRow.icon(
                    icon: Icons.social_distance,
                    label: 'Distance',
                    value: distance,
                    detail: 'In a straight line. The road is usually further.',
                  ),
                DetailRow.icon(
                  icon: Icons.groups_outlined,
                  label: 'Crew wanted',
                  value: job.workersNeeded == 1
                      ? '1 person'
                      : '${job.workersNeeded} people',
                  detail: job.filledCount > 0
                      ? '${job.filledCount} already taken on'
                      : null,
                ),

                if (job.description case final about?
                    when about.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'About the work',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(about, style: theme.textTheme.bodyMedium),
                ],

                const SizedBox(height: 18),

                // Seeing the venue is often what decides it, so this sits with the other actions rather
                // than being buried. Offered only when the job actually has a position to show.
                if (job.hasPosition) ...[
                  OutlinedButton.icon(
                    onPressed: () {
                      final filter = ref.read(workerJobFilterProvider);
                      pushScreen(
                        context,
                        SingleJobMapScreen(
                          job: job,
                          from: filter.hasPosition
                              ? LatLng(filter.latitude!, filter.longitude!)
                              : null,
                        ),
                      );
                    },
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: const Text('See it on the map'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                if (widget.showBusinessLink)
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      pushScreen(
                        context,
                        HiringBusinessScreen(
                          businessId: job.businessOwnerProfileId,
                          // This job is the one they are standing in, so the business page shows
                          // what else is open rather than listing it back to them.
                          fromPostId: job.id,
                        ),
                      );
                    },
                    icon: const Icon(Icons.storefront_outlined, size: 18),
                    label: Text('About ${job.businessName}'),
                  ),
              ],
            ),
          ),

          // The decision, pinned below the scroll rather than at the end of it.
          //
          // Mirrors what the card in the list offers, so a worker reaching a job by either route
          // gets the same choice rather than being sent back to find the other one — and it stays on
          // screen however long the description runs, which is the point of putting it here. A
          // button you have to go looking for is a button that costs somebody the job.
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: theme.dividerColor.withValues(alpha: 0.6),
                ),
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              12 + MediaQuery.of(context).padding.bottom,
            ),
            child: switch (job) {
              _ when _isApplying => const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: CircularProgressIndicator(),
                ),
              ),
              // An offer is answered here, not somewhere else. It used to say "answer on the job
              // card", which was a direction rather than a control — and once invitations started
              // opening this sheet it became a dead end: the one screen that exists to show a job
              // somebody was picked for, with no way to take it.
              _
                  when job.myApplicationStatus == 'Confirmed' &&
                      job.myApplicationId != null =>
                _OfferAnswer(
                  applicationId: job.myApplicationId!,
                  onAnswered: () => Navigator.of(context).pop(),
                ),
              // A job this worker took: the business accepted them and they agreed. They can now
              // message and call the business — never the customer; the business is the middle man.
              _ when job.myApplicationStatus == 'Accepted' => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Their role on one of the business's own events, as on an order: a Lead can
                  // start and finish the work, so they get the button for the next step.
                  if (job.holdsOwnRoles &&
                      (job.myRole ?? '').trim().isNotEmpty) ...[
                    JobRoleBanner(
                      role: job.myRole!.trim(),
                      canMoveWork: job.iAmLead && job.canHoldCrewRoles,
                      isOver: !job.canHoldCrewRoles,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (job.iAmLead &&
                      (job.canStartWork() || job.canMarkComplete())) ...[
                    _LeadWorkButton(job: job),
                    const SizedBox(height: 12),
                  ],
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => pushScreen(
                          context,
                          WorkChatScreen(
                            counterpartId: job.businessOwnerProfileId,
                            counterpartName: job.businessName,
                            subtitle: job.title,
                          ),
                        ),
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: const Text('Message business'),
                      ),
                      if (job.businessPhone case final phone?
                          when phone.isNotEmpty)
                        OutlinedButton.icon(
                          onPressed: () => launchPhoneCall(context, phone),
                          icon: const Icon(Icons.call),
                          label: const Text('Call business'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _applicationPill(job.myApplicationStatus),
                ],
              ),
              _ when job.hasApplied => Center(
                child: _applicationPill(job.myApplicationStatus),
              ),
              _ when job.isOpenToWorkers() => FilledButton(
                onPressed: _apply,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Apply for this job'),
              ),
              _ => Center(
                child: Text(
                  'This job is no longer taking applications.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            },
          ),
        ],
      ),
    );
  }
}

/// Where the worker's application stands, in this sheet's words. A state the table does not name
/// reads as the server's own word for it.
StatusPill _applicationPill(String? status) {
  const group = 'HiringPostApplication.WorkerDetail';
  return StatusPill(
    label: UiConfig.current.labels[group]?[status]?.label ?? status ?? '',
    tone: UiConfig.current.tone(group, status),
  );
}

/// The Lead's button on one of a business's own events: start the work on the day, then finish it.
///
/// It moves the whole job, not just this worker's part, which is why it is said for the job.
class _LeadWorkButton extends ConsumerStatefulWidget {
  const _LeadWorkButton({required this.job});

  final HiringPost job;

  @override
  ConsumerState<_LeadWorkButton> createState() => _LeadWorkButtonState();
}

class _LeadWorkButtonState extends ConsumerState<_LeadWorkButton> {
  bool _isBusy = false;

  Future<void> _run({required bool start}) async {
    setState(() => _isBusy = true);

    // Taken before the await: the job list refreshes underneath this sheet.
    final navigator = Navigator.of(context);
    final messenger = AppMessenger.of(context);
    final container = ProviderScope.containerOf(context, listen: false);
    final repository = ref.read(hiringPostRepositoryProvider);

    try {
      if (start) {
        await repository.leadStartWork(widget.job.id);
      } else {
        await repository.leadCompleteWork(widget.job.id);
      }
      container.invalidate(workerPostJobsProvider);
      navigator.pop();
      messenger.showSuccess(start ? 'Work started.' : 'Work marked completed.');
    } catch (e) {
      if (mounted) setState(() => _isBusy = false);
      messenger.showFailure(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final start = widget.job.canStartWork();

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _isBusy ? null : () => _run(start: start),
        icon: _isBusy
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(start ? Icons.play_arrow_rounded : Icons.flag_rounded),
        label: Text(start ? 'Start this job' : 'Finish this job'),
      ),
    );
  }
}

/// Accept or decline a job this worker was picked for, from inside the details.
///
/// The business has chosen them; nothing is settled and no place is taken until this is answered.
/// Declining asks first, because it cannot be taken back — accepting can at least be discussed with
/// the business afterwards, where a decline hands the place straight to somebody else.
class _OfferAnswer extends ConsumerStatefulWidget {
  const _OfferAnswer({required this.applicationId, required this.onAnswered});

  final String applicationId;

  /// Closes the sheet. The job has left the list it was opened from either way.
  final VoidCallback onAnswered;

  @override
  ConsumerState<_OfferAnswer> createState() => _OfferAnswerState();
}

class _OfferAnswerState extends ConsumerState<_OfferAnswer> {
  bool _isResponding = false;

  Future<void> _respond(bool accept) async {
    if (!accept) {
      final confirmed = await showConfirmDialog(
        context,
        title: 'Decline this job?',
        message:
            'The business will be told and your place goes back to other applicants. '
            'You cannot take it back afterwards.',
        confirmLabel: 'Decline',
        cancelLabel: 'Keep deciding',
        destructive: true,
      );
      if (!confirmed || !mounted) return;
    }

    setState(() => _isResponding = true);

    // Both taken before the await: this sheet closes on success, and anything read off its context
    // afterwards throws.
    final messenger = AppMessenger.of(context);
    final notifier = ref.read(workerJobOffersProvider.notifier);

    try {
      await notifier.respond(
        applicationId: widget.applicationId,
        accept: accept,
      );
      widget.onAnswered();
      messenger.showSuccess(
        accept
            ? 'Taken. It is on My jobs now.'
            : 'Declined. The business has been told.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isResponding = false);
      messenger.showFailure(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isResponding) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => _respond(false),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text('Decline'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton(
            onPressed: () => _respond(true),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text('Accept'),
          ),
        ),
      ],
    );
  }
}
