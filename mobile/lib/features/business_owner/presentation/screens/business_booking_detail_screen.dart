import 'package:zuno/features/booking/presentation/widgets/order_code.dart';
import 'package:zuno/features/booking/presentation/widgets/booking_status_chip.dart';
import 'package:zuno/features/business_owner/presentation/widgets/create_hiring_post_sheet.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import 'package:zuno/features/booking/presentation/widgets/booking_crew_list.dart';
import 'package:zuno/features/booking/presentation/widgets/booking_terms_section.dart';
import 'package:zuno/features/booking/presentation/widgets/propose_terms_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/constants/api_constants.dart';
import 'package:zuno/features/booking/domain/entities/booking.dart';
import 'package:zuno/features/booking/presentation/providers/business_bookings_notifier.dart';
import 'package:zuno/features/business_owner/presentation/widgets/assign_worker_dialog.dart';
import 'package:zuno/shared/widgets/call_icon_button.dart';
import 'package:zuno/shared/widgets/job_location_card.dart';

class BusinessBookingDetailScreen extends ConsumerStatefulWidget {
  const BusinessBookingDetailScreen({required this.booking, super.key});

  final Booking booking;

  @override
  ConsumerState<BusinessBookingDetailScreen> createState() =>
      _BusinessBookingDetailScreenState();
}

class _BusinessBookingDetailScreenState
    extends ConsumerState<BusinessBookingDetailScreen> {
  late Booking _booking = widget.booking;
  bool _isProcessing = false;

  Future<void> _confirm() async {
    setState(() => _isProcessing = true);
    try {
      await ref
          .read(businessBookingsProvider.notifier)
          .confirm(widget.booking.id);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
        setState(() => _isProcessing = false);
      }
    }
  }

  /// Offers the customer a crew size and price, or counters theirs.
  Future<void> _proposeTerms() async {
    final terms = await ProposeTermsSheet.show(
      context,
      booking: _booking,
      viewerIsBusiness: true,
    );
    if (terms == null || !mounted) return;

    await _runTermsAction(
      () => ref
          .read(businessBookingsProvider.notifier)
          .proposeTerms(
            _booking.id,
            workerCount: terms.workerCount,
            price: terms.price,
            message: terms.message,
          ),
    );
  }

  /// Takes up the customer's counter, which confirms the order.
  Future<void> _acceptTerms(String proposalId) => _runTermsAction(
    () => ref
        .read(businessBookingsProvider.notifier)
        .acceptTerms(_booking.id, proposalId),
  );

  /// Runs a terms action and picks the updated order back up.
  ///
  /// The screen holds its own copy of the booking, so after the notifier refreshes the list this
  /// has to read the new version out of it — otherwise the offer just made would not appear until
  /// the screen was closed and reopened.
  Future<void> _runTermsAction(Future<void> Function() action) async {
    setState(() => _isProcessing = true);
    try {
      await action();

      final refreshed = ref
          .read(businessBookingsProvider)
          .value
          ?.firstWhereOrNull((b) => b.id == _booking.id);

      if (!mounted) return;
      setState(() {
        if (refreshed != null) _booking = refreshed;
        _isProcessing = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _addWorker() async {
    final updated = await showAssignWorkerDialog(context, booking: _booking);
    if (updated != null && mounted) {
      setState(() => _booking = updated);
    }
  }

  Future<void> _cancel() async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Decline this order?'),
        // Said plainly, because it is the last moment this choice exists.
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Reason (optional)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Decline order'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() => _isProcessing = true);
    try {
      await ref
          .read(businessBookingsProvider.notifier)
          .cancel(
            widget.booking.id,
            reason: reasonController.text.trim().isEmpty
                ? null
                : reasonController.text.trim(),
          );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = _booking;

    return Scaffold(
      appBar: AppBar(title: const Text('Booking Details')),
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
                      booking.customerName,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              if (booking.reference.isNotEmpty)
                OrderCode(code: booking.reference),
            ],
          ),
          const SizedBox(height: 14),
          // One status, as the customer would read it. The four tracks behind it — event, crew,
          // work, wages — belong to Status management, where they can be acted on.
          Align(
            alignment: Alignment.centerLeft,
            child: BookingStatusChip(order: booking),
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
          _DetailRow(
            label: 'Scheduled for',
            // Through the shared formatters, not a substring of toString(), which printed
            // "2026-09-23 09:0" — machine format, with a digit clipped off the time.
            value: '${formatDate(booking.scheduledDate)} · '
                '${formatTime(booking.scheduledDate)}',
          ),
          _DetailRow(
            label: 'Price',
            value: booking.priceDisplay(),
          ),
          if (booking.customerPhone != null)
            _DetailRow(label: 'Customer phone', value: booking.customerPhone!),
          // What the customer told the business about the job, each line carrying the question as it

          // was worded when they answered it.

          for (final answer in booking.serviceAnswers)
            _DetailRow(label: answer.questionPrompt, value: answer.answerText),

          // Agreeing how many people the job takes, right under what the customer told us —
          // the answers are what the number is worked out from.
          BookingTermsSection(
            booking: booking,
            viewerIsBusiness: true,
            isBusy: _isProcessing,
            onPropose: _proposeTerms,
            onAccept: _acceptTerms,
          ),

          if (booking.notes != null && booking.notes!.isNotEmpty)
            _DetailRow(label: 'Notes', value: booking.notes!),
          // The customer's pinned location, with Directions — so the business (and anyone it
          // forwards the address to) goes to the right door, not wherever the typed text points.
          if (booking.addressLine1 != null) ...[
            const SizedBox(height: 8),
            JobLocationCard(
              latitude: booking.latitude,
              longitude: booking.longitude,
              caption: 'Exact location from the customer',
              addressLines: [
                booking.addressLine1,
                booking.addressLine2,
                booking.city,
                booking.state,
                booking.postalCode,
              ],
            ),
            const SizedBox(height: 12),
          ],
          // Who is actually on this job, and what each of them is owed.
          //
          // The rule below is about the CUSTOMER's view of the crew — this screen is the
          // business's own, and until this list existed it could not see its own crew at all:
          // add three workers and nothing on screen changed.
          BookingCrewList(
            booking: booking,
            canSetRoles: true,
            initiallyExpanded: true,
          ),

          // No crew count in the header. The customer booked a service; how many people the
          // business puts on it is the business's own call, made when it hires.
          const SizedBox(height: 20),
          if (_isProcessing)
            const Center(child: CircularProgressIndicator())
          else ...[
            // Only while nothing is being negotiated. With an offer on the table this would mean
            // confirming at the service's listed price instead of the one under discussion, so
            // the server refuses it — and a button that always fails is worse than no button.
            if (booking.canConfirmAsBooked)
              FilledButton(
                onPressed: _confirm,
                child: const Text('Accept as booked'),
              ),
            // No Start work or Mark completed here. This screen is the order as it came in —
            // who wants what, when and where — and the one place to accept it or staff it.
            // Moving the job along is Status management's job, and a button in both places is
            // the same job worked from two screens.
            //
            // Not gated on being "fully staffed" — there is no such thing here. The business
            // keeps adding people for as long as it judges the job needs them.
            if (booking.isConfirmed || booking.isAssigned) ...[
              FilledButton(
                onPressed: _addWorker,
                child: const Text('Add worker'),
              ),
              const SizedBox(height: 10),
              // For the crew the business does not have yet. Anyone who accepts the post lands
              // on this booking without the business having to come back and pick them.
              OutlinedButton.icon(
                onPressed: () =>
                    showCreateHiringPostSheet(context, booking: booking),
                icon: const Icon(Icons.campaign_outlined, size: 18),
                label: const Text('Hire workers from Zuno'),
              ),
            ],
            // Only before it is accepted. Confirming an order is a promise the customer starts
            // planning around; a business cannot un-promise it from a button. Once confirmed,
            // calling the job off is the customer's to do.
            if (booking.isPending) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _cancel,
                child: const Text('Decline order'),
              ),
            ],
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
