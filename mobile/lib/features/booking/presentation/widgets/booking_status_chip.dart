import 'package:flutter/material.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/features/booking/domain/entities/booking.dart';
import 'package:zuno/shared/widgets/status_pill.dart';

/// Where an order has got to, in the words a customer would use.
///
/// Takes the order rather than a status string, because the label is not a translation of the
/// stored value: a confirmed order reads **Active** before its day and **In progress** on it,
/// and only the order knows its own date.
class BookingStatusChip extends StatelessWidget {
  const BookingStatusChip({required this.order, super.key});

  final Booking order;

  @override
  Widget build(BuildContext context) => StatusPill(
    label: order.orderStatusLabel(),
    tone: switch (order.status) {
      'Completed' => StatusTone.success,
      'InProgress' => StatusTone.progress,
      'Cancelled' => StatusTone.danger,
      'Pending' => StatusTone.waiting,
      // Confirmed: Active before the day, In progress on it. Both read as good news.
      _ => order.hasReachedItsDate() ? StatusTone.progress : StatusTone.success,
    },
    compact: true,
  );
}
