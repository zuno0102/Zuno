import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/features/rental/domain/entities/rental_customer.dart';
import 'package:zuno/features/rental/domain/entities/rental_stock.dart';
import 'package:zuno/features/rental/presentation/providers/rental_order_providers.dart';
import 'package:zuno/features/rental/presentation/providers/rental_providers.dart';
import 'package:zuno/shared/widgets/app_messages.dart';
import 'package:zuno/shared/widgets/confirm_dialog.dart';

/// Takes one step on a rent order — "Send out", "Mark returned", "Cancel order" — asking first when
/// the step says so, then refreshes every Rent list, stock figure and tile.
///
/// Returns the order as it now stands, or null if the business backed out or the step failed (the
/// failure is shown).
Future<RentalOrder?> runRentalOrderAction(
  BuildContext context,
  WidgetRef ref,
  RentalOrder order,
  RentalOrderAction action, {
  RentalAudience audience = RentalAudience.business,
}) async {
  if (action.confirmFirst) {
    final confirmed = await showConfirmDialog(
      context,
      title: '${action.label}?',
      message:
          '${order.customerName} · ${order.quantity} × ${order.itemName}. '
          'This cannot be undone.',
      confirmLabel: action.label,
      cancelLabel: 'Keep order',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return null;
  }

  // Before the await, as the app's messages need: the screen's colours and its messenger.
  final messenger = AppMessenger.of(context);
  try {
    final updated = await ref
        .read(rentalOrdersGatewayProvider(audience))
        .takeStep(order.id, action.toStatus);
    reloadRentals(ref);
    messenger.showSuccess(
      '${updated.customerName}: ${updated.quantity} × ${updated.itemName} — '
      '${updated.statusName.toLowerCase()}.',
    );
    return updated;
  } catch (e) {
    messenger.showFailure(e.toString());
    return null;
  }
}
