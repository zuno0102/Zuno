import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:zuno/core/constants/api_constants.dart';
import 'package:zuno/features/booking/domain/entities/booking.dart';
import 'package:zuno/features/booking/presentation/providers/customer_bookings_notifier.dart';
import 'package:zuno/features/booking/presentation/screens/booking_chat_screen.dart';
import 'package:zuno/features/booking/presentation/widgets/booking_status_chip.dart';
import 'package:zuno/features/booking/presentation/widgets/booking_terms_section.dart';
import 'package:zuno/features/booking/presentation/widgets/propose_terms_sheet.dart';
import 'package:zuno/shared/widgets/call_icon_button.dart';
import 'package:zuno/shared/widgets/primary_button.dart';
import 'package:zuno/shared/widgets/app_messages.dart';
import 'package:zuno/core/theme/app_colors.dart';

class CustomerBookingDetailScreen extends ConsumerStatefulWidget {
  const CustomerBookingDetailScreen({
    required this.booking,
    this.openRating = false,
    super.key,
  });

  final Booking booking;

  /// Opens the rating sheet as soon as the screen settles.
  ///
  /// Set when the person arrived from the "Work finished. Rate Boss T?" notification: they tapped
  /// the ask, so making them find the button again is asking twice. Ignored on an order that
  /// cannot be rated — already rated, or not finished — where the sheet would be a dead end.
  final bool openRating;

  @override
  ConsumerState<CustomerBookingDetailScreen> createState() =>
      _CustomerBookingDetailScreenState();
}

class _CustomerBookingDetailScreenState
    extends ConsumerState<CustomerBookingDetailScreen> {
  bool _isProcessing = false;

  /// The screen's own copy, so an offer just answered shows without reopening the page.
  late Booking _booking = widget.booking;

  @override
  void initState() {
    super.initState();

    // After the first frame, so the sheet has a laid-out screen to sit on rather than appearing
    // over a half-built page.
    if (widget.openRating && _booking.canBeRated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _rate();
      });
    }
  }

  /// Counters the business's offer with the customer's own number.
  Future<void> _proposeTerms() async {
    final terms = await ProposeTermsSheet.show(
      context,
      booking: _booking,
      viewerIsBusiness: false,
    );
    if (terms == null || !mounted) return;

    await _runTermsAction(
      () => ref
          .read(customerBookingsProvider.notifier)
          .proposeTerms(
            _booking.id,
            workerCount: terms.workerCount,
            price: terms.price,
            message: terms.message,
          ),
    );
  }

  /// Takes up the business's offer, which confirms the order.
  Future<void> _acceptTerms(String proposalId) => _runTermsAction(
    () => ref
        .read(customerBookingsProvider.notifier)
        .acceptTerms(_booking.id, proposalId),
  );

  /// Runs a terms action, then picks the updated order back out of the refreshed list.
  Future<void> _runTermsAction(Future<void> Function() action) async {
    setState(() => _isProcessing = true);
    try {
      await action();

      final refreshed = ref
          .read(customerBookingsProvider)
          .value
          ?.firstWhereOrNull((b) => b.id == _booking.id);

      if (!mounted) return;
      setState(() {
        if (refreshed != null) _booking = refreshed;
        _isProcessing = false;
      });
    } catch (e) {
      if (!mounted) return;
      context.showFailureMessage(e.toString().replaceFirst('Exception: ', ''));
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _cancel() async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel booking?'),
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
            child: const Text('Keep booking'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancel booking'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    // The confirmation was a dialog, so the screen behind it may be gone by the time it closes.
    if (!mounted) return;

    setState(() => _isProcessing = true);
    // Taken before the await: this screen closes on success, and a messenger read off a dead
    // context afterwards would throw instead of saying the booking was cancelled.
    final messenger = AppMessenger.of(context);
    try {
      await ref
          .read(customerBookingsProvider.notifier)
          .cancel(
            widget.booking.id,
            reason: reasonController.text.trim().isEmpty
                ? null
                : reasonController.text.trim(),
          );
      if (mounted) {
        Navigator.of(context).pop();
        messenger.showSuccess('Booking cancelled.');
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

  Future<void> _rate() async {
    var score = 5;
    final commentController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Rate this service'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final starValue = index + 1;
                  return IconButton(
                    icon: Icon(
                      starValue <= score ? Icons.star : Icons.star_border,
                      color: AppColors.ratingStar,
                    ),
                    onPressed: () => setDialogState(() => score = starValue),
                  );
                }),
              ),
              TextField(
                controller: commentController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Comment (optional)',
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
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );

    if (result != true) {
      return;
    }

    // The rating sheet was a route of its own; this screen may have gone while it was open.
    if (!mounted) return;

    setState(() => _isProcessing = true);
    // As above: the screen closes, so the messenger is captured while the context is still alive.
    final messenger = AppMessenger.of(context);
    try {
      await ref
          .read(customerBookingsProvider.notifier)
          .rate(
            widget.booking.id,
            score: score,
            comment: commentController.text.trim().isEmpty
                ? null
                : commentController.text.trim(),
          );
      if (mounted) {
        Navigator.of(context).pop();
        messenger.showSuccess('Thanks — your rating is saved.');
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
    // The local copy, not the widget's: it is updated in place when an offer is answered.
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
                      booking.businessName,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              BookingStatusChip(order: booking),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (booking.canBeCalled && booking.businessPhone != null) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        launchPhoneCall(context, booking.businessPhone!),
                    icon: const Icon(Icons.call),
                    label: const Text('Call'),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              // Where a conversation starts. The Chat tab only lists bookings somebody has already
              // written on, so without this there would be no way to write the first message.
              //
              // Offered in the same window as the phone: once the business has taken the order on,
              // and not after it is called off. The server refuses outside it either way.
              if (booking.canBeMessaged)
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => BookingChatScreen(
                          bookingId: booking.id,
                          title: booking.variantName ?? booking.serviceName,
                          counterpartName: booking.businessName,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Message'),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          _DetailRow(
            label: 'Scheduled for',
            value: booking.scheduledDate.toLocal().toString().substring(0, 16),
          ),
          _DetailRow(
            label: 'Price',
            value: booking.priceDisplay(),
          ),
          // No crew here. How many people a business puts on a job, and who they are, is the
          // business's arrangement — a customer booked a service, not a headcount.
          // What the customer told the business about the job, each line carrying the question as it

          // was worded when they answered it.

          for (final answer in booking.serviceAnswers)
            _DetailRow(label: answer.questionPrompt, value: answer.answerText),

          // The crew and price being agreed. Shown to the customer because it is a number they
          // are being asked to accept — the order's *roster* stays the business's own affair.
          BookingTermsSection(
            booking: booking,
            viewerIsBusiness: false,
            isBusy: _isProcessing,
            onPropose: _proposeTerms,
            onAccept: _acceptTerms,
          ),

          if (booking.notes != null && booking.notes!.isNotEmpty)
            _DetailRow(label: 'Notes', value: booking.notes!),
          if (booking.addressLine1 != null)
            _DetailRow(
              label: 'Address',
              value: [
                booking.addressLine1,
                booking.city,
                booking.state,
                booking.postalCode,
              ].where((p) => p != null && p.isNotEmpty).join(', '),
            ),
          if (booking.cancellationReason != null)
            _DetailRow(
              label: 'Cancellation reason',
              value: booking.cancellationReason!,
            ),
          // Gated on the order, not on the crew. It used to need an assigned worker, which
          // stopped working once staffing moved off the order's status — and the customer has
          // no business knowing whether anyone has been assigned anyway.
          if (booking.isConfirmed ||
              booking.isAssigned ||
              booking.isInProgress) ...[
            const SizedBox(height: 24),
            Center(
              child: Column(
                children: [
                  Text(
                    'Show this QR to your worker on arrival',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Scanning it opens the exact order details for verification.',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    child: QrImageView(
                      data: 'zuno-booking:${booking.id}',
                      size: 180,
                      gapless: false,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (booking.rating != null) ...[
            const SizedBox(height: 12),
            Text('Your rating', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Row(
              children: List.generate(
                5,
                (i) => Icon(
                  i < booking.rating!.score ? Icons.star : Icons.star_border,
                  color: AppColors.ratingStar,
                  size: 20,
                ),
              ),
            ),
            if (booking.rating!.comment != null) Text(booking.rating!.comment!),
          ],
          const SizedBox(height: 28),
          if (_isProcessing)
            const Center(child: CircularProgressIndicator())
          else ...[
            if (booking.canBeCancelled)
              OutlinedButton(
                onPressed: _cancel,
                child: const Text('Cancel booking'),
              ),
            if (booking.canBeRated) ...[
              const SizedBox(height: 12),
              PrimaryButton(label: 'Rate this service', onPressed: _rate),
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
