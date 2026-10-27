import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/features/booking/domain/entities/booking.dart';
import 'package:zuno/features/booking/presentation/providers/worker_jobs_notifier.dart';
import 'package:zuno/features/booking/presentation/widgets/booking_status_chip.dart';
import 'package:zuno/features/worker/presentation/screens/worker_booking_detail_screen.dart';
import 'package:zuno/shared/widgets/call_icon_button.dart';
import 'package:zuno/shared/widgets/empty_state.dart';
import 'package:zuno/shared/widgets/error_banner.dart';
import 'package:zuno/shared/widgets/section_header.dart';
import 'package:zuno/shared/widgets/app_messages.dart';
import 'package:zuno/features/hiring_post/domain/entities/hiring_post.dart';
import 'package:zuno/features/hiring_post/presentation/providers/worker_post_jobs_notifier.dart';
import 'package:zuno/features/worker/presentation/widgets/job_details_sheet.dart';
import 'package:zuno/shared/widgets/status_pill.dart';
import 'package:zuno/shared/widgets/status_with_actions.dart';
import 'package:zuno/features/work_chat/presentation/providers/work_chat_providers.dart';
import 'package:zuno/features/work_chat/presentation/widgets/work_message_button.dart';
import 'package:zuno/features/work_chat/presentation/widgets/work_threads_list.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/features/hiring_post/presentation/providers/worker_job_offers_notifier.dart';
import 'package:zuno/features/worker/domain/entities/worker_invitation.dart';
import 'package:zuno/features/worker/presentation/providers/worker_invitations_notifier.dart';
import 'package:zuno/features/worker/presentation/screens/worker_invitations_tab.dart';
import 'package:zuno/core/router/push_screen.dart';

/// A worker's jobs, split into the work they still have to do, the work behind them, and the work
/// being offered to them.
///
/// This was one flat list in whatever order the server returned, which for a worker with a dozen
/// jobs meant a job awaiting their answer could sit below one finished last month. Sections fixed
/// the order; tabs fix the length. History only grows, so on any worker with a few months
/// behind them the live work — the part they can still act on — ends up at the top of a very long
/// scroll, with nothing to stop them scrolling past it into last March.
///
/// **Current** is everything still live: offers waiting on an answer, work under way, and what is
/// coming. **History** is finished and called-off work, which is a record to look things up in
/// rather than a list to act on. **Invitations** is work a business is offering them by name, and
/// teams asking them to join — the next jobs, so they sit beside the jobs rather than on a tab of
/// their own in the bottom bar.
///
/// The tab bar is always shown. A new worker with no jobs yet is exactly the one most likely to have
/// an invitation, so "no jobs" can never be allowed to replace the screen.
class WorkerJobsTab extends ConsumerWidget {
  const WorkerJobsTab({this.initialTab = currentTab, super.key});

  static const currentTab = 0;
  static const historyTab = 1;
  static const invitationsTab = 2;
  static const messagesTab = 3;

  /// Which tab opens first — the Invitations tab when a notification about one was tapped.
  final int initialTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(workerJobsProvider);

    // The other half of a worker's work. Jobs taken through a hiring post never came through the
    // bookings endpoint, so this screen showed none of them while the home page counted them.
    final postJobsAsync = ref.watch(workerPostJobsProvider);

    // Only for the Invitations count: what is still waiting on this worker's answer.
    final offerCount = ref.watch(workerJobOffersProvider).value?.length ?? 0;
    final teamCount = [
      for (final t
          in ref.watch(workerInvitationsProvider).value ??
              const <WorkerInvitation>[])
        if (t.status == 'Invited') t,
    ].length;
    final invitationCount = offerCount + teamCount;

    Future<void> refresh() async {
      ref
        ..invalidate(workerJobsProvider)
        ..invalidate(workerPostJobsProvider);
      await ref.read(workerJobsProvider.future);
    }

    // Post work is the lesser half: a failure to load it must not replace a worker's bookings
    // with an error, so it falls back to nothing and the bookings still show.
    final postJobs = postJobsAsync.value ?? const <HiringPost>[];

    final livePosts = [
      for (final p in postJobs)
        if (!p.isWorkCompleted) p,
    ]..sort((a, b) => a.eventDate.compareTo(b.eventDate));

    final donePosts = [
      for (final p in postJobs)
        if (p.isWorkCompleted) p,
    ]..sort((a, b) => b.eventDate.compareTo(a.eventDate));

    final jobs = jobsAsync.value;
    final sections = jobs == null ? null : WorkerJobSections.from(jobs);
    final hasNoJobs = jobs != null && jobs.isEmpty && postJobs.isEmpty;

    /// One of the two job tabs, or the loading, error or empty state they share.
    Widget jobsTab(Widget Function(WorkerJobSections sections) builder) =>
        jobsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ErrorBanner(message: error.toString()),
            ),
          ),
          data: (_) => RefreshIndicator(
            onRefresh: refresh,
            child: hasNoJobs ? const _NoJobs() : builder(sections!),
          ),
        );

    String label(String name, int? count) =>
        count == null ? name : '$name ($count)';

    // Unread messages from the businesses this worker works for.
    final messageCount = ref.watch(unreadWorkChatCountProvider);

    // Four tabs on a phone: tight side padding and room for two lines, so a long name wraps
    // rather than being cut off (the same treatment as the business's Orders tabs).
    Tab tab(String text, {Key? key}) => Tab(
      key: key,
      height: 56,
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );

    return DefaultTabController(
      length: 4,
      initialIndex: initialTab,
      child: Column(
        children: [
          TabBar(
            labelPadding: const EdgeInsets.symmetric(horizontal: 4),
            tabs: [
              tab(
                label(
                  'Current',
                  sections == null
                      ? null
                      : sections.currentCount + livePosts.length,
                ),
              ),
              tab(
                label(
                  'History',
                  sections == null
                      ? null
                      : sections.finished.length + donePosts.length,
                ),
              ),
              tab(
                label('Invitations', invitationCount),
                key: const Key('workerInvitationsTab'),
              ),
              tab(
                label('Messages', messageCount),
                key: const Key('workerMessagesTab'),
              ),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                jobsTab((s) => _CurrentJobs(sections: s, postJobs: livePosts)),
                jobsTab(
                  (s) => _JobHistory(jobs: s.finished, postJobs: donePosts),
                ),
                const WorkerInvitationsTab(),
                // Conversations with the businesses this worker works for. Customers are never
                // here: the business is the go-between for everything about a job.
                const WorkThreadsList(
                  emptyState: EmptyState(
                    icon: Icons.chat_bubble_outline,
                    title: 'No messages yet',
                    message:
                        'Once a business has taken you on for a job, you can message and call '
                        'it from the job card.',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// How a worker's jobs are split up, and in what order they are shown.
///
/// Kept apart from the widget so the rule can be tested without pumping a screen, and so the four
/// buckets can be shown to be exhaustive — every job lands in exactly one.
class WorkerJobSections {
  const WorkerJobSections({
    required this.needsAnswer,
    required this.active,
    required this.upcoming,
    required this.finished,
  });

  /// Sorts each bucket the way a worker reads it.
  factory WorkerJobSections.from(List<Booking> jobs, {DateTime? now}) {
    final at = now ?? DateTime.now();

    final needsAnswer = <Booking>[];
    final active = <Booking>[];
    final upcoming = <Booking>[];
    final finished = <Booking>[];

    for (final job in jobs) {
      // Tested in this order deliberately, so each job falls in exactly one bucket.
      //
      // The answer comes first even on a job whose date has passed: an unanswered offer is the one
      // thing only the worker can clear, and burying it under "done" is how it gets missed.
      if (job.myAssignmentAwaitingResponse && !job.isCancelled) {
        needsAnswer.add(job);
      } else if (job.isCompleted || job.isCancelled) {
        finished.add(job);
      } else if (job.isInProgress) {
        active.add(job);
      } else if (!job.scheduledDate.isBefore(at)) {
        upcoming.add(job);
      } else {
        // The day has gone by and nobody started it. Not upcoming — a worker would plan around a
        // date that has passed — and not finished either, so it sits with the live work where it
        // can still be chased.
        active.add(job);
      }
    }

    // Soonest first for anything still to come; most recent first for history.
    needsAnswer.sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
    active.sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
    upcoming.sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
    finished.sort((a, b) => b.scheduledDate.compareTo(a.scheduledDate));

    return WorkerJobSections(
      needsAnswer: needsAnswer,
      active: active,
      upcoming: upcoming,
      finished: finished,
    );
  }

  /// Offers waiting on this worker to accept or decline.
  final List<Booking> needsAnswer;

  /// Work under way, plus anything whose day has passed without being finished.
  final List<Booking> active;

  final List<Booking> upcoming;

  /// Done or called off. History, kept last.
  final List<Booking> finished;

  int get total =>
      needsAnswer.length + active.length + upcoming.length + finished.length;

  /// Everything still live, which is what the first tab holds.
  int get currentCount => needsAnswer.length + active.length + upcoming.length;
}

/// The work a worker can still do something about.
class _CurrentJobs extends StatelessWidget {
  const _CurrentJobs({required this.sections, this.postJobs = const []});

  final WorkerJobSections sections;

  /// Work taken through a hiring post, which comes from a different endpoint entirely.
  final List<HiringPost> postJobs;

  @override
  Widget build(BuildContext context) {
    if (sections.currentCount == 0 && postJobs.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 50),
          EmptyState(
            icon: Icons.event_available_outlined,
            title: 'Nothing on just now',
            message:
                'No job is waiting on you and none is booked. Everything you have done is under '
                'History, and Find work is where the next one comes from.',
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        // An unanswered offer is the only thing here nobody else can do for them.
        // No hint under it: the Accept and Decline buttons already say what to do.
        _JobSection(
          title: 'Waiting for your answer',
          jobs: sections.needsAnswer,
        ),
        _JobSection(title: 'On the job', jobs: sections.active),
        _JobSection(title: 'Coming up', jobs: sections.upcoming),

        // Kept as its own section rather than mixed in: these are a different kind of work, paid a
        // different way, and the card can offer what a booking card cannot — the map to the venue.
        if (postJobs.isNotEmpty) ...[
          SectionHeader(
            title: 'Jobs you took',
            count: postJobs.length,
            padding: const EdgeInsets.fromLTRB(0, 14, 0, 8),
          ),
          for (final post in postJobs)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PostJobCard(post: post),
            ),
        ],
      ],
    );
  }
}

/// Finished and called-off work.
///
/// One flat list, newest first, with no headings: history is looked things up in rather than worked
/// through, and splitting "done" from "called off" would make somebody check two places for the job
/// they half-remember. Each card still says which it was.
class _JobHistory extends StatelessWidget {
  const _JobHistory({required this.jobs, this.postJobs = const []});

  final List<Booking> jobs;
  final List<HiringPost> postJobs;

  @override
  Widget build(BuildContext context) {
    if (jobs.isEmpty && postJobs.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 50),
          EmptyState(
            icon: Icons.history,
            title: 'Nothing finished yet',
            message:
                'Jobs you have done, and any that were called off, are kept here once they are '
                'over.',
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        for (final job in jobs)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _JobCard(booking: job),
          ),
        for (final post in postJobs)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _PostJobCard(post: post),
          ),
      ],
    );
  }
}

/// One job taken through a hiring post.
///
/// Its own card rather than the booking one, because the two are not the same shape: this has a
/// wage per worker rather than an order total, a crew rather than a customer, and — the part a
/// worker actually wanted — a pinned venue, so the details behind it can show the way there.
class _PostJobCard extends StatelessWidget {
  const _PostJobCard({required this.post});

  final HiringPost post;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final whereParts = [
      post.distanceLabel,
      if (post.location case final at? when at.isNotEmpty) at,
    ].whereType<String>();

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        // The details, which carry the map. The business link is left on, because unlike an
        // invitation this is somebody they are already working for and may want to look up.
        onTap: () => showJobDetailsSheet(context, job: post),
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                          post.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          post.businessName,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    post.salaryLabel,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  Icon(
                    Icons.event_outlined,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      post.scheduleLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),

              if (whereParts.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Row(
                    children: [
                      Icon(
                        Icons.place_outlined,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          whereParts.join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      if (post.hasPosition)
                        Text(
                          'Open map',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),

              const SizedBox(height: 10),
              Row(
                children: [
                  StatusPill(
                    label: post.isWorkCompleted
                        ? 'Work finished'
                        : post.isWorkStarted
                        ? 'Work started'
                        : 'Booked',
                    tone: post.isWorkCompleted
                        ? StatusTone.success
                        : post.isWorkStarted
                        ? StatusTone.progress
                        : StatusTone.waiting,
                    compact: true,
                  ),
                  const Spacer(),
                  // Every job here is one the worker was accepted on, so the business can be
                  // messaged and called about it — the business, never the customer.
                  CardActions(
                    actions: [
                      WorkMessageButton(
                        counterpartId: post.businessOwnerProfileId,
                        counterpartName: post.businessName,
                        subtitle: post.title,
                        tooltip: 'Message business',
                        iconSize: 22,
                      ),
                      if (post.businessPhone case final phone?
                          when phone.isNotEmpty)
                        CallIconButton(
                          phoneNumber: phone,
                          tooltip: 'Call business',
                          iconSize: 22,
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JobSection extends StatelessWidget {
  const _JobSection({required this.title, required this.jobs});

  final String title;
  final List<Booking> jobs;

  @override
  Widget build(BuildContext context) {
    // An empty section is left out entirely rather than shown with a zero — four headings with
    // nothing under three of them reads as a broken screen.
    if (jobs.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: title,
          count: jobs.length,
          padding: const EdgeInsets.fromLTRB(0, 14, 0, 8),
        ),
        for (final job in jobs)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _JobCard(booking: job),
          ),
      ],
    );
  }
}

class _NoJobs extends StatelessWidget {
  const _NoJobs();

  @override
  Widget build(BuildContext context) {
    // A scroll view, so pull-to-refresh still works on an empty screen.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(height: 60),
        EmptyState(
          icon: Icons.work_outline,
          title: 'No jobs yet',
          message:
              'Jobs appear here when a business puts you on one. Look under Find work to apply '
              'for something.',
        ),
      ],
    );
  }
}

class _JobCard extends ConsumerStatefulWidget {
  const _JobCard({required this.booking});

  final Booking booking;

  @override
  ConsumerState<_JobCard> createState() => _JobCardState();
}

class _JobCardState extends ConsumerState<_JobCard> {
  bool _isProcessing = false;

  Future<void> _respond({required bool accept}) => _run(
    () => ref
        .read(workerJobsProvider.notifier)
        .respond(widget.booking.id, accept: accept),
  );

  Future<void> _complete() => _run(
    () => ref.read(workerJobsProvider.notifier).complete(widget.booking.id),
  );

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _isProcessing = true);
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
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () =>
            pushScreen(context, WorkerBookingDetailScreen(booking: booking)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                // Top-aligned, so the status sits level with the job's name as on every card.
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          booking.variantName ?? booking.serviceName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (booking.variantName != null)
                          Text(
                            booking.serviceName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                        Text(
                          booking.businessName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // The same right-hand side as the business's and customer's cards: status,
                  // a gap, then the buttons. The worker contacts the business — never the
                  // customer directly; the business is the middle man.
                  StatusWithActions(
                    status: BookingStatusChip(order: booking),
                    actions: [
                      if (booking.workerCanContactBusiness)
                        WorkMessageButton(
                          counterpartId: booking.businessOwnerProfileId,
                          counterpartName: booking.businessName,
                          subtitle: booking.variantName ?? booking.serviceName,
                          tooltip: 'Message business',
                          iconSize: 22,
                        ),
                      if (booking.workerCanContactBusiness &&
                          booking.businessPhone != null)
                        CallIconButton(
                          phoneNumber: booking.businessPhone!,
                          tooltip: 'Call business',
                          iconSize: 22,
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Through the shared formatters. This used to print a substring of toString(),
              // which read "2026-09-23 09:0" — machine format with a digit clipped off the time.
              Row(
                children: [
                  Icon(
                    Icons.event_outlined,
                    size: 15,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${relativeDayLabel(booking.scheduledDate)} · '
                      '${formatTime(booking.scheduledDate)}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
              if (booking.addressLine1 != null) ...[
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.place_outlined,
                      size: 15,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        [
                          booking.addressLine1,
                          booking.city,
                          booking.state,
                        ].where((p) => p != null && p.isNotEmpty).join(', '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
              if (_isProcessing) ...[
                const SizedBox(height: 14),
                const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ] else if (booking.myAssignmentAwaitingResponse) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _respond(accept: false),
                        child: const Text('Decline'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => _respond(accept: true),
                        child: const Text('Accept'),
                      ),
                    ),
                  ],
                ),
              ] else if (booking.isInProgress &&
                  booking.myAssignmentIsAccepted) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _complete,
                    child: const Text('Mark completed'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
