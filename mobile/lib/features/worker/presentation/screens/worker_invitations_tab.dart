import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/features/hiring_post/domain/entities/hiring_post.dart';
import 'package:zuno/features/hiring_post/presentation/providers/worker_job_offers_notifier.dart';
import 'package:zuno/features/worker/domain/entities/worker_invitation.dart';
import 'package:zuno/features/worker/presentation/providers/worker_invitations_notifier.dart';
import 'package:zuno/features/worker/presentation/screens/hiring_business_screen.dart';
import 'package:zuno/features/worker/presentation/widgets/job_details_sheet.dart';
import 'package:zuno/shared/widgets/app_messages.dart';
import 'package:zuno/shared/widgets/error_banner.dart';
import 'package:zuno/shared/widgets/section_header.dart';
import 'package:zuno/core/router/push_screen.dart';
import 'package:zuno/shared/widgets/confirm_dialog.dart';

/// Everything waiting on this worker's answer, and the teams they have already joined.
///
/// Two different things arrive here and they were not the same thing at all:
///
///   * **a job** — a business picked this worker for one specific post, by name. It has a date, a
///     place, a rate and a crew size, and it is what somebody means by "an invitation".
///   * **a team** — a standing offer to be on a business's roster. No job behind it, so nothing to
///     show but the business.
///
/// Only the second ever reached this tab. Job offers surfaced in the Find work feed, as a line on a
/// card among every other job in the radius, which is no place to find out that somebody asked for
/// you by name.
class WorkerInvitationsTab extends ConsumerWidget {
  const WorkerInvitationsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offersAsync = ref.watch(workerJobOffersProvider);
    final teamsAsync = ref.watch(workerInvitationsProvider);

    // The job offers decide the screen's state. The team invitations are the lesser half, so a
    // failure to load them must not replace a list of jobs with an error.
    if (offersAsync.isLoading && !offersAsync.hasValue) {
      return const Center(child: CircularProgressIndicator());
    }

    if (offersAsync case AsyncError(:final error) when !offersAsync.hasValue) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ErrorBanner(message: error.toString()),
        ),
      );
    }

    final offers = offersAsync.value ?? const <HiringPost>[];
    final teams = teamsAsync.value ?? const <WorkerInvitation>[];

    final pendingTeams = [
      for (final t in teams)
        if (t.status == 'Invited') t,
    ];
    final joinedTeams = [
      for (final t in teams)
        if (t.status == 'Active') t,
    ];

    if (offers.isEmpty && pendingTeams.isEmpty && joinedTeams.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No invitations right now. Businesses will invite you here once they '
            'find your profile, and jobs they pick you for will appear here too.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(workerJobOffersProvider);
        ref.invalidate(workerInvitationsProvider);
        await ref.read(workerJobOffersProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // Jobs first. A date that passes is a job lost, where a team invitation keeps.
          if (offers.isNotEmpty) ...[
            SectionHeader(
              title: 'Jobs you were invited to',
              count: offers.length,
              padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
            ),
            for (final offer in offers) ...[
              _JobOfferCard(offer: offer),
              const SizedBox(height: 10),
            ],
          ],

          if (pendingTeams.isNotEmpty) ...[
            SectionHeader(
              title: 'Teams asking you to join',
              count: pendingTeams.length,
              padding: EdgeInsets.fromLTRB(0, offers.isEmpty ? 4 : 14, 0, 8),
            ),
            for (final invitation in pendingTeams) ...[
              _TeamInvitationCard(invitation: invitation),
              const SizedBox(height: 10),
            ],
          ],

          if (joinedTeams.isNotEmpty) ...[
            SectionHeader(
              title: 'Businesses you work for',
              count: joinedTeams.length,
              padding: EdgeInsets.fromLTRB(
                0,
                offers.isEmpty && pendingTeams.isEmpty ? 4 : 14,
                0,
                8,
              ),
            ),
            for (final membership in joinedTeams) ...[
              _JoinedCard(membership: membership),
              const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }
}

/// One job a business picked this worker for.
///
/// Carries what the decision rests on — the pay, the day, the place, how far — rather than a
/// business name and a yes/no. Tapping opens the full details, where the answer is given.
class _JobOfferCard extends ConsumerWidget {
  const _JobOfferCard({required this.offer});

  final HiringPost offer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final whereParts = [
      offer.distanceLabel,
      if (offer.location case final at? when at.isNotEmpty) at,
    ].whereType<String>();

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => showJobDetailsSheet(
          context,
          job: offer,
          // A business that picked this worker by name is not a stranger to be checked out. The
          // question here is the job, and a second button under Accept competes with the answer
          // this screen exists to collect.
          showBusinessLink: false,
        ),
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
                          offer.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          offer.businessName,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // The number that decides it, where the eye lands first.
                  Text(
                    offer.salaryLabel,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              _Fact(icon: Icons.event_outlined, text: offer.scheduleLabel),
              if (whereParts.isNotEmpty)
                _Fact(icon: Icons.place_outlined, text: whereParts.join(' · ')),
              _Fact(
                icon: Icons.groups_outlined,
                text: offer.workersNeeded == 1
                    ? '1 person wanted'
                    : '${offer.workersNeeded} people wanted',
              ),

              const SizedBox(height: 12),
              _OfferAnswer(offer: offer),
            ],
          ),
        ),
      ),
    );
  }
}

/// One line of the job: an icon and a fact, repeated so the card reads as a list of facts.
class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// Accept or decline, on the card itself.
///
/// Answering is the whole reason this screen exists, so it does not require opening the job first —
/// though the details are one tap away for anybody who wants them before deciding.
class _OfferAnswer extends ConsumerStatefulWidget {
  const _OfferAnswer({required this.offer});

  final HiringPost offer;

  @override
  ConsumerState<_OfferAnswer> createState() => _OfferAnswerState();
}

class _OfferAnswerState extends ConsumerState<_OfferAnswer> {
  bool _isResponding = false;

  Future<void> _respond(bool accept) async {
    final applicationId = widget.offer.myApplicationId;
    if (applicationId == null) return;

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
    final messenger = AppMessenger.of(context);

    try {
      await ref
          .read(workerJobOffersProvider.notifier)
          .respond(applicationId: applicationId, accept: accept);

      messenger.showSuccess(
        accept
            ? 'Taken. It is on My jobs now.'
            : 'Declined. The business has been told.',
      );
    } catch (e) {
      messenger.showFailure(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isResponding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isResponding) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => _respond(false),
            child: const Text('Decline'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton(
            onPressed: () => _respond(true),
            child: const Text('Accept'),
          ),
        ),
      ],
    );
  }
}

/// Opens the business behind a team invitation.
///
/// There is no job to show — this is an offer to join a roster, not to work one day — so the detail
/// a worker needs is the business itself: what it pays, whether it pays on time, and what it has
/// open. Saying yes to a business that owes three workers money is the mistake this prevents.
void _openBusiness(BuildContext context, WorkerInvitation invitation) {
  pushScreen(
    context,
    HiringBusinessScreen(businessId: invitation.businessOwnerProfileId),
  );
}

class _TeamInvitationCard extends ConsumerStatefulWidget {
  const _TeamInvitationCard({required this.invitation});

  final WorkerInvitation invitation;

  @override
  ConsumerState<_TeamInvitationCard> createState() =>
      _TeamInvitationCardState();
}

class _TeamInvitationCardState extends ConsumerState<_TeamInvitationCard> {
  bool _isResponding = false;

  Future<void> _respond({required bool accept}) async {
    setState(() => _isResponding = true);
    final messenger = AppMessenger.of(context);
    final name = widget.invitation.businessName;

    try {
      await ref
          .read(workerInvitationsProvider.notifier)
          .respond(widget.invitation.id, accept: accept);

      messenger.showSuccess(
        accept ? 'You now work for $name.' : 'Invitation from $name declined.',
      );
    } catch (e) {
      messenger.showFailure(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isResponding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openBusiness(context, widget.invitation),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.invitation.businessName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Wants you on their team, for work as it comes up.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 2),
              Text(
                'Tap to see what they pay and what they have open.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 14),
              if (_isResponding)
                const Center(child: CircularProgressIndicator(strokeWidth: 2))
              else
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
            ],
          ),
        ),
      ),
    );
  }
}

/// A business the worker has already joined.
///
/// No buttons: leaving a team is not something the app offers, and a card that looked like it might
/// would be worse than one that plainly does not. It is a record and a way in — tapping it opens the
/// business, where that business's open jobs are listed and can be applied for.
class _JoinedCard extends StatelessWidget {
  const _JoinedCard({required this.membership});

  final WorkerInvitation membership;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: () => _openBusiness(context, membership),
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(
            Icons.storefront_outlined,
            size: 20,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          membership.businessName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: const Text('See their open jobs'),
        trailing: Icon(
          Icons.chevron_right,
          size: 18,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
