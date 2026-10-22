import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/features/booking/domain/entities/booking.dart';
import 'package:zuno/features/catalog/domain/entities/order_stage.dart';
import 'package:zuno/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:zuno/shared/widgets/status_pill.dart';

/// Where an order has got to, in the words a customer would use.
///
/// The stage is the server's ([Booking.stage]), and its name and colour come from the order stage
/// list — nothing about how a stage reads is written into the app.
class BookingStatusChip extends ConsumerWidget {
  const BookingStatusChip({required this.order, super.key});

  final Booking order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stages = ref.watch(orderStagesProvider).value ?? const <OrderStage>[];
    final stage = stages.resolve(order.stage);
    return StatusPill(
      label: stage.label,
      tone: stage.statusTone,
      compact: true,
    );
  }
}
