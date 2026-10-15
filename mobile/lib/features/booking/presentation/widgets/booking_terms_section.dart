import 'package:flutter/material.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/features/booking/domain/entities/booking.dart';
import 'package:zuno/features/booking/domain/entities/booking_terms_proposal.dart';

/// Agreeing how many people a job takes, and what that costs.
///
/// One widget for both sides. The business offers first, having read what the customer said about
/// the event; the customer accepts or counters; whoever accepts confirms the order. The only
/// difference between the two views is who is allowed to answer, which is one flag.
///
/// Every round is shown, not just the latest. The number that was settled on matters less than
/// how it was arrived at — a customer who can see "we asked 20, you said 18" has a record; one
/// shown only "18" has to remember.
class BookingTermsSection extends StatelessWidget {
  const BookingTermsSection({
    required this.booking,
    required this.viewerIsBusiness,
    required this.onPropose,
    required this.onAccept,
    this.isBusy = false,
    super.key,
  });

  final Booking booking;
  final bool viewerIsBusiness;

  /// Opens the sheet for making or countering an offer.
  final VoidCallback onPropose;

  /// Takes up the open offer, by its id.
  final void Function(String proposalId) onAccept;

  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final open = booking.openProposal;

    // Nothing to negotiate and nothing negotiated: this order never needed it.
    if (booking.proposals.isEmpty && !booking.isPending) {
      return const SizedBox.shrink();
    }

    final myTurn = booking.needsMyReply(viewerIsBusiness: viewerIsBusiness);

    return Card(
      margin: const EdgeInsets.only(top: 14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Crew and price',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _StatusChip(
                  booking: booking,
                  viewerIsBusiness: viewerIsBusiness,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _explanation(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),

            if (booking.proposals.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final proposal in booking.proposals)
                _ProposalRow(
                  proposal: proposal,
                  viewerIsBusiness: viewerIsBusiness,
                ),
            ],

            const SizedBox(height: 12),
            if (isBusy)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (myTurn && open != null)
              // Accept is the prominent one: countering is the exception, agreeing is the point.
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () => onAccept(open.id),
                      child: Text('Accept ${open.workerCount}'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onPropose,
                      child: const Text('Counter'),
                    ),
                  ),
                ],
              )
            else if (booking.isPending && open == null && !booking.termsAreAgreed)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onPropose,
                  icon: const Icon(Icons.groups_outlined, size: 19),
                  label: const Text('Propose crew & price'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _explanation() {
    if (booking.termsAreAgreed) {
      final accepted = booking.acceptedProposal;
      return accepted == null
          ? 'Agreed.'
          : 'Agreed at ${accepted.workerCount} people for ${rupees(accepted.price)}.';
    }

    if (booking.needsMyReply(viewerIsBusiness: viewerIsBusiness)) {
      return viewerIsBusiness
          ? 'The customer has answered. Accept their number, or counter it.'
          : 'The business has proposed a crew. Accept it, or say what suits you.';
    }

    if (booking.awaitingTheirReply(viewerIsBusiness: viewerIsBusiness)) {
      return viewerIsBusiness
          ? 'Sent. Waiting for the customer to accept or counter.'
          : 'Sent. Waiting for the business to accept or counter.';
    }

    return viewerIsBusiness
        ? 'Read what they told you above, then propose how many people it takes.'
        : 'The business will propose a crew size once it has read your details.';
  }
}

/// Who owes whom a reply, said from the reader's own point of view.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.booking, required this.viewerIsBusiness});

  final Booking booking;
  final bool viewerIsBusiness;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (label, background, foreground) = switch (booking.agreementStatus) {
      'Agreed' => (
        'Agreed',
        theme.colorScheme.primaryContainer,
        theme.colorScheme.onPrimaryContainer,
      ),
      'Closed' => (
        'Closed',
        theme.colorScheme.surfaceContainerHighest,
        theme.colorScheme.onSurfaceVariant,
      ),
      // The wire says who is waited on; the chip says whether that is you.
      'AwaitingBusiness' || 'AwaitingCustomer' =>
        booking.needsMyReply(viewerIsBusiness: viewerIsBusiness)
            ? (
                'Waiting for you',
                theme.colorScheme.tertiaryContainer,
                theme.colorScheme.onTertiaryContainer,
              )
            : (
                'Waiting for them',
                theme.colorScheme.surfaceContainerHighest,
                theme.colorScheme.onSurfaceVariant,
              ),
      _ => (
        'Not agreed yet',
        theme.colorScheme.surfaceContainerHighest,
        theme.colorScheme.onSurfaceVariant,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// One round of the conversation.
class _ProposalRow extends StatelessWidget {
  const _ProposalRow({required this.proposal, required this.viewerIsBusiness});

  final BookingTermsProposal proposal;
  final bool viewerIsBusiness;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mine = proposal.isFromBusiness == viewerIsBusiness;
    final superseded = !proposal.isOpen && !proposal.isAccepted;

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            proposal.isAccepted
                ? Icons.check_circle
                : proposal.isOpen
                ? Icons.radio_button_checked
                : Icons.history,
            size: 17,
            color: proposal.isAccepted
                ? theme.colorScheme.primary
                : superseded
                ? theme.colorScheme.outline
                : theme.colorScheme.tertiary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${mine ? 'You' : (proposal.isFromBusiness ? 'The business' : 'The customer')}'
                  ' · ${proposal.workerCount} people · ${rupees(proposal.price)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: proposal.isOpen
                        ? FontWeight.w600
                        : FontWeight.w400,
                    // A superseded round is history, not a live number to act on.
                    color: superseded
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.onSurface,
                    decoration: superseded ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (proposal.message case final note?
                    when note.trim().isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    note,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
