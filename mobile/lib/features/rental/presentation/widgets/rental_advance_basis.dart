import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/features/rental/domain/entities/rental_payment.dart';

/// How an item's advance comes to what it is, for [quantity] pieces, in words: "₹300 a piece × 2 =
/// ₹600" or "₹300 for the whole order, any number of pieces". Null when the item asks no advance.
///
/// Only explains [rentalAdvance]; it never works out a different amount.
String? rentalAdvanceBasis(String advanceType, double? amount, int quantity) {
  final each = amount ?? 0;
  if (each <= 0) return null;
  return switch (advanceType) {
    RentalAdvanceType.perPiece =>
      '${rupees(each)} a piece × $quantity = ${rupees(each * quantity)}',
    RentalAdvanceType.perOrder =>
      '${rupees(each)} for the whole order, any number of pieces',
    _ => null,
  };
}
