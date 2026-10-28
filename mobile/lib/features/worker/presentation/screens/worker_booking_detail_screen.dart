import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:zuno/shared/widgets/detail_row.dart';
import 'package:zuno/features/worker/presentation/widgets/job_role_banner.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/constants/api_constants.dart';
import 'package:zuno/features/booking/domain/entities/booking.dart';
import 'package:zuno/features/booking/presentation/providers/worker_jobs_notifier.dart';
import 'package:zuno/features/booking/presentation/widgets/booking_status_chip.dart';
import 'package:zuno/features/notifications/presentation/providers/notification_providers.dart';
import 'package:zuno/features/work_chat/presentation/screens/work_chat_screen.dart';
import 'package:zuno/shared/widgets/call_icon_button.dart';
import 'package:zuno/shared/widgets/app_messages.dart';
import 'package:zuno/shared/widgets/job_location_card.dart';
import 'package:zuno/core/router/push_screen.dart';

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

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Reading the job is as good as reading the notification about it. The same rule all three
      // roles now follow: the bell counts what you have not looked at, and the thing itself counts
      // as having looked.
      ref
          .read(unreadNotificationTargetsProvider.notifier)
          .markBookingSeen(widget.booking.id);
    });
  }

  Future<void> _respond({required bool accept}) => _run(
    () => ref
        .read(workerJobsProvider.notifier)
        .respond(widget.booking.id, accept: accept),
  );

  Future<void> _complete() => _run(
    () => ref.read(workerJobsProvider.notifier).complete(widget.booking.id),
  );

  Future<void> _startJob() => _run(
    () =>
        ref.read(workerJobsProvider.notifier).startJobAsLead(widget.booking.id),
  );

  Future<void> _finishJob() => _run(
    () => ref
        .read(workerJobsProvider.notifier)
        .finishJobAsLead(widget.booking.id),
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
        context.showFailureMessage(
          e.toString().replaceFirst('Exception: ', ''),
        );
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
          // The business is who a worker contacts about a job — never the customer directly; the
          // business is the middle man and arranges everything with the customer.
          if (booking.workerCanContactBusiness) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => pushScreen(
                    context,
                    WorkChatScreen(
                      counterpartId: booking.businessOwnerProfileId,
                      counterpartName: booking.businessName,
                      subtitle: booking.variantName ?? booking.serviceName,
                    ),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Message business'),
                ),
                if (booking.businessPhone != null)
                  OutlinedButton.icon(
                    onPressed: () =>
                        launchPhoneCall(context, booking.businessPhone!),
                    icon: const Icon(Icons.call),
                    label: const Text('Call business'),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          DetailRow(label: 'Customer', value: booking.customerName),
          DetailRow(
            label: 'Scheduled for',
            value:
                '${formatDate(booking.scheduledDate)} · ${formatTime(booking.scheduledDate)}',
          ),
          DetailRow(label: 'Price', value: booking.priceDisplay()),

          // What the customer told the business about the job, each line carrying the question as it

          // was worded when they answered it.
          for (final answer in booking.serviceAnswers)
            DetailRow(label: answer.questionPrompt, value: answer.answerText),

          if (booking.notes != null && booking.notes!.isNotEmpty)
            DetailRow(label: 'Notes', value: booking.notes!),
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
              JobRoleBanner(
                role: booking.myRole!,
                // Only while the job is still live. Once it is finished or called off the Lead
                // cannot start or finish anything — the order refuses both — so a banner still
                // offering it would be the screen promising something the server would reject.
                canMoveWork: booking.iLeadThisJob && booking.canHoldCrewRoles,
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
