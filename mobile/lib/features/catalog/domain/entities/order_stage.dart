import 'package:zuno/core/theme/app_colors.dart';

/// How one order stage is shown — its name, colour, place and which tabs filter by it.
///
/// Comes from the server (`/order-stages`), not from the app: renaming a stage or reordering the
/// filters is a change to a database row, not a new release.
class OrderStage {
  const OrderStage({
    required this.code,
    required this.label,
    this.sortOrder = 0,
    this.tone = '',
    this.showOnBookings = false,
    this.showOnWork = false,
  });

  /// Matches the `stage` on an order or own event: `AwaitingPayment`.
  final String code;

  /// What the chip and filter say: "Awaiting payment".
  final String label;
  final int sortOrder;

  /// The colour family's name — `success`, `progress`, `waiting`, `danger`.
  final String tone;
  final bool showOnBookings;
  final bool showOnWork;

  /// The theme's colour family for [tone]. A name the app does not know reads as waiting rather
  /// than failing, so a new tone on the server cannot break an old app.
  StatusTone get statusTone =>
      StatusTone.values.asNameMap()[tone] ?? StatusTone.waiting;
}

/// Looking stages up by an order's code.
extension OrderStageLookup on List<OrderStage> {
  OrderStage? byCode(String code) {
    for (final stage in this) {
      if (stage.code == code) return stage;
    }
    return null;
  }

  /// The stage for [code], or — while the list is still loading, or for a code it does not have —
  /// one made from the code itself ("AwaitingPayment" reads "Awaiting payment"), so a chip is never
  /// blank and no stage name has to be written into the app.
  OrderStage resolve(String code) =>
      byCode(code) ?? OrderStage(code: code, label: _words(code));

  static String _words(String code) {
    final spaced = code.replaceAllMapped(
      RegExp('(?<=[a-z])(?=[A-Z])'),
      (_) => ' ',
    );
    return spaced.isEmpty
        ? spaced
        : spaced[0] + spaced.substring(1).toLowerCase();
  }

  /// The Bookings tab's filters, in the server's order.
  List<OrderStage> get onBookings =>
      where((s) => s.showOnBookings).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  /// The Status management tab's filters, in the server's order.
  List<OrderStage> get onWork =>
      where((s) => s.showOnWork).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
}
