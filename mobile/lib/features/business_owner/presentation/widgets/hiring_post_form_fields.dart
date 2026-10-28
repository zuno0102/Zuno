import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:zuno/core/constants/api_constants.dart';
import 'package:zuno/features/booking/domain/entities/booking.dart';
import 'package:zuno/features/booking/presentation/widgets/order_code.dart';
import 'package:zuno/features/hiring_post/domain/entities/hiring_post.dart';
import 'package:zuno/shared/widgets/job_location_card.dart';

/// Which order a new hiring post's crew is for, shown as a field that opens the order picker.
///
/// Choosing one fills in the date, the address and how many people are still missing — and puts
/// everyone who accepts straight onto that booking, so nobody has to be added by hand afterwards.
class HiringPostOrderField extends StatelessWidget {
  const HiringPostOrderField({
    required this.linkedBooking,
    required this.isLoading,
    required this.onTap,
    super.key,
  });

  /// Null for a post for the business's own event.
  final Booking? linkedBooking;

  /// While the orders are being fetched: a spinner stands in for the arrow and taps are ignored.
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final booking = linkedBooking;

    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: isLoading ? null : onTap,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'For which order?',
          border: OutlineInputBorder(),
          helperText: 'Workers who accept join that order.',
        ),
        child: Row(
          children: [
            Expanded(
              child: booking == null
                  ? Text(
                      'Not linked — my own event',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    )
                  : Row(
                      children: [
                        OrderCode(code: booking.reference, compact: true),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            booking.serviceName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
            ),
            if (isLoading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }
}

/// The post's picture: the one just picked, else the one already saved, else an "add" prompt.
class HiringPostImageSlot extends StatelessWidget {
  const HiringPostImageSlot({
    required this.pickedBytes,
    required this.existingImageUrl,
    required this.onTap,
    super.key,
  });

  final Uint8List? pickedBytes;

  /// The server path of the saved picture — the post's own, or the linked order's.
  final String? existingImageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 96,
          height: 96,
          color: theme.colorScheme.surfaceContainerHighest,
          child: pickedBytes != null
              ? Image.memory(pickedBytes!, fit: BoxFit.cover)
              : existingImageUrl != null
              ? CachedNetworkImage(
                  imageUrl: '${ApiConstants.baseUrl}$existingImageUrl',
                  fit: BoxFit.cover,
                )
              : Icon(
                  Icons.add_a_photo_outlined,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
        ),
      ),
    );
  }
}

/// When the event starts, as a field that opens the date and time pickers.
class HiringPostEventDateField extends StatelessWidget {
  const HiringPostEventDateField({
    required this.value,
    required this.onTap,
    super.key,
  });

  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: onTap,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Event date & time',
          border: OutlineInputBorder(),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              value == null
                  ? 'Select date & time'
                  : value!.toLocal().toString().substring(0, 16),
              style: value == null
                  ? TextStyle(color: theme.colorScheme.onSurfaceVariant)
                  : null,
            ),
            const Icon(Icons.edit_calendar_outlined),
          ],
        ),
      ),
    );
  }
}

/// Where the job is: the order's own pin when there is one, the directions box, and — for a post
/// without an order's pin — the controls for pinning it on a map.
class HiringPostLocationFields extends StatelessWidget {
  const HiringPostLocationFields({
    required this.controller,
    required this.orderPinBooking,
    required this.hasOwnPin,
    required this.onPick,
    required this.onClearPin,
    super.key,
  });

  /// The location text the post is saved with.
  final TextEditingController controller;

  /// The linked order, when its customer's exact pin is what the crew goes to. Null when the
  /// business places its own.
  final Booking? orderPinBooking;

  /// Whether the business has placed a pin of its own on this form.
  final bool hasOwnPin;

  /// Opens the pin picker, starting from the phone's position when [fromCurrentLocation].
  final void Function({required bool fromCurrentLocation}) onPick;
  final VoidCallback onClearPin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final order = orderPinBooking;
    final usesOrderPin = order != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (order != null) ...[
          // The customer pinned this order's door; the crew goes there. Shown, not asked.
          JobLocationCard(
            key: const Key('hirePostOrderPin'),
            latitude: order.latitude,
            longitude: order.longitude,
            caption: 'From the order · exact pin (set automatically)',
            addressLines: [
              order.addressLine1,
              order.addressLine2,
              order.city,
              order.state,
              order.postalCode,
            ],
            showActions: false,
          ),
          const SizedBox(height: 10),
        ],
        TextFormField(
          controller: controller,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: usesOrderPin
                ? 'Directions for the crew (optional)'
                : 'Location details',
            hintText: 'e.g. Hall behind the church, gate 2',
            border: const OutlineInputBorder(),
          ),
        ),
        if (!usesOrderPin) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ActionChip(
                key: const Key('hirePostSearchLocation'),
                avatar: const Icon(Icons.search, size: 18),
                label: const Text('Search location'),
                onPressed: () => onPick(fromCurrentLocation: false),
              ),
              ActionChip(
                key: const Key('hirePostCurrentLocation'),
                avatar: const Icon(Icons.my_location, size: 18),
                label: const Text('Current location'),
                onPressed: () => onPick(fromCurrentLocation: true),
              ),
              if (hasOwnPin)
                InputChip(
                  key: const Key('hirePostPinSet'),
                  avatar: Icon(
                    Icons.check_circle,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  label: const Text('Exact pin set'),
                  onPressed: () => onPick(fromCurrentLocation: false),
                  onDeleted: onClearPin,
                ),
            ],
          ),
          if (!hasOwnPin)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Pin it so nearby workers see the job and how far it is.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ],
    );
  }
}

/// Explains, inside the form, why the salary controls behave differently on a post that
/// already has confirmed workers.
class HiringPostSalaryLockNotice extends StatelessWidget {
  const HiringPostSalaryLockNotice({required this.post, super.key});

  final HiringPost post;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${post.confirmedCount} worker(s) confirmed at ${post.salaryLabel}. '
              'You can raise the salary, but not lower it or change the unit.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
