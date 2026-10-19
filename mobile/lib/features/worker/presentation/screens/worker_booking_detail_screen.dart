import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/constants/api_constants.dart';
import 'package:zuno/features/booking/domain/entities/booking.dart';
import 'package:zuno/features/booking/presentation/providers/worker_jobs_notifier.dart';
import 'package:zuno/features/booking/presentation/widgets/booking_status_chip.dart';
import 'package:zuno/shared/widgets/call_icon_button.dart';
import 'package:zuno/shared/widgets/app_messages.dart';
import 'package:zuno/shared/widgets/job_location_card.dart';

class WorkerBookingDetailScreen extends ConsumerStatefulWidget {
  const WorkerBookingDetailScreen({required this.booking, super.key});

  final Booking booking;

  @override
  ConsumerState<WorkerBookingDetailScreen> createState() =>
      _WorkerBookingDetailScreenState();
}

class _WorkerBookingDetailScreenState
    extends ConsumerState<WorkerBookingDetailScreen> {
  bool _isProcessing = false;

  Future<void> _respond({required bool accept}) => _run(
    () => ref
        .read(workerJobsProvider.notifier)
        .respond(widget.booking.id, accept: accept),
  );

  Future<void> _complete() => _run(
    () => ref.read(workerJobsProvider.notifier).complete(widget.booking.id),
  );

  Future<void> _startJob() => _run(
    () => ref.read(workerJobsProvider.notifier).startJobAsLead(widget.booking.id),
  );

  Future<void> _finishJob() => _run(
    () => ref.read(workerJobsProvider.notifier).finishJobAsLead(widget.booking.id),
  );

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _isProcessing = true);
    try {
      await action();
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        context.showFailureMessage(e.toString().replaceFirst('Exception: ', ''));
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;

    return Scaffold(
      appBar: AppBar(title: const Text('Job Details')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (booking.imageUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: '${ApiConstants.baseUrl}${booking.imageUrl}',
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.variantName ?? booking.serviceName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (booking.variantName != null)
                      Text(
                        booking.serviceName,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    Text(
                      booking.businessName,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              BookingStatusChip(order: booking),
            ],
          ),
          if (booking.canBeCalled && booking.customerPhone != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => launchPhoneCall(context, booking.customerPhone!),
              icon: const Icon(Icons.call),
              label: const Text('Call customer'),
            ),
          ],
          const SizedBox(height: 20),
          _DetailRow(label: 'Customer', value: booking.customerName),
          if (booking.customerPhone != null)
            _DetailRow(label: 'Customer phone', value: booking.customerPhone!),
          _DetailRow(
            label: 'Scheduled for',
            value: booking.scheduledDate.toLocal().toString().substring(0, 16),
          ),
          _DetailRow(
            label: 'Price',
            value: booking.priceDisplay(),
          ),
          // What the customer told the business about the job, each line carrying the question as it

          // was worded when they answered it.

          for (final answer in booking.serviceAnswers)
            _DetailRow(label: answer.questionPrompt, value: answer.answerText),

          if (booking.notes != null && booking.notes!.isNotEmpty)
            _DetailRow(label: 'Notes', value: booking.notes!),
          // Where to go. The pin the customer placed, with Directions straight to it — the worker
          // is the one person who actually has to find the house.
          if (booking.addressLine1 != null) ...[
            const SizedBox(height: 8),
            JobLocationCard(
              latitude: booking.latitude,
              longitude: booking.longitude,
              caption: 'Exact job location from the customer',
              addressLines: [
                booking.addressLine1,
                booking.addressLine2,
                booking.city,
                booking.state,
                booking.postalCode,
              ],
            ),
          ],
          const SizedBox(height: 28),
          if (_isProcessing)
            const Center(child: CircularProgressIndicator())
          else if (booking.myAssignmentAwaitingResponse)
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
            )
          else ...[
            // The lead's controls move the WHOLE order. Shown above their own row's button and
            // labelled for the job rather than for them, so "finish the job" is never mistaken
            // for "I am done" — one closes everybody's work, the other only theirs.
            // The title is shown to anyone holding one of the three; only the Lead gets buttons
            // under it. A Supervisor told "you're the Supervisor" and given nothing to press is
            // correct — watching the work is the role.
            if (booking.iHaveARoleOnThisJob) ...[
              _RoleBanner(
                role: booking.myRole!,
                // Only while the job is still live. Once it is finished or called off the Lead
                // cannot start or finish anything — the order refuses both — so a banner still
                // offering it would be the screen promising something the server would reject.
                canMoveWork:
                    booking.iLeadThisJob && booking.canHoldCrewRoles,
                isOver: !booking.canHoldCrewRoles,
              ),
              const SizedBox(height: 12),
            ],
            if (booking.iLeadThisJob) ...[
              if (booking.canStartWork())
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _startJob,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Start this job'),
                  ),
                )
              else if (booking.canCompleteWork)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _finishJob,
                    icon: const Icon(Icons.flag_rounded),
                    label: const Text('Finish this job'),
                  ),
                ),
              if (booking.isInProgress && booking.myAssignmentIsAccepted)
                const SizedBox(height: 10),
            ],
            if (booking.isInProgress && booking.myAssignmentIsAccepted)
              SizedBox(
                width: double.infinity,
                child: booking.iLeadThisJob
                    ? OutlinedButton(
                        onPressed: _complete,
                        child: const Text('Mark my own part completed'),
                      )
                    : FilledButton(
                        onPressed: _complete,
                        child: const Text('Mark completed'),
                      ),
              ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
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

/// Says what this worker is on this job, and of no other.
///
/// Worth stating rather than leaving to be inferred from the buttons: the same person can lead
/// Saturday's job and be an ordinary pair of hands on Sunday's, and for a Supervisor or Support
/// there are no buttons at all — so without this line their role would be invisible to them.
class _RoleBanner extends StatelessWidget {
  const _RoleBanner({
    required this.role,
    required this.canMoveWork,
    required this.isOver,
  });

  final String role;

  /// Whether this role can start and finish the job right now. Only a Lead, and only while the
  /// job is still live.
  final bool canMoveWork;

  /// Whether the job is finished or called off, so the role is a record rather than a job to do.
  final bool isOver;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            // A star only where there is power behind it, so it does not promise a Supervisor
            // buttons that are not coming.
            canMoveWork ? Icons.star_rounded : Icons.badge_outlined,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              // Past tense once it is over. The role was only ever for this one order, so on a
              // finished job it is a record of what somebody did, not a job still to do — and
              // reading "you can start and finish it" under a completed order would be the app
              // offering work that no longer exists.
              isOver
                  ? 'You were the $role on this job.'
                  : canMoveWork
                  ? "You're the $role on this job — you can start and finish it."
                  : "You're the $role on this job.",
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
