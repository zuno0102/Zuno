import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/features/rental/domain/entities/rental_payment.dart';
import 'package:zuno/features/rental/presentation/widgets/rental_advance_basis.dart';

/// The line that says how an advance is worked out, so a business that set ₹300 sees whether 2
/// pieces ask ₹300 (fixed for the order) or ₹600 (per piece).
void main() {
  for (final (type, amount, quantity, expected) in [
    (
      RentalAdvanceType.perPiece,
      300.0,
      2,
      '${rupees(300)} a piece × 2 = ${rupees(600)}',
    ),
    (
      RentalAdvanceType.perPiece,
      300.0,
      1,
      '${rupees(300)} a piece × 1 = ${rupees(300)}',
    ),
    (
      RentalAdvanceType.perPiece,
      2.0,
      300,
      '${rupees(2)} a piece × 300 = ${rupees(600)}',
    ),
    (
      RentalAdvanceType.perOrder,
      300.0,
      2,
      '${rupees(300)} for the whole order, any number of pieces',
    ),
    (RentalAdvanceType.none, 300.0, 2, null),
    (RentalAdvanceType.perPiece, null, 2, null),
    (RentalAdvanceType.perOrder, 0.0, 2, null),
  ]) {
    test('$type ₹$amount × $quantity -> $expected', () {
      expect(rentalAdvanceBasis(type, amount, quantity), expected);
    });
  }

  test('says the same amount the advance rule charges, per piece', () {
    for (final quantity in [1, 2, 5, 300]) {
      final charged = rentalAdvance(
        RentalAdvanceType.perPiece,
        300,
        quantity,
        1000000,
      );
      expect(
        rentalAdvanceBasis(RentalAdvanceType.perPiece, 300, quantity),
        endsWith(rupees(charged)),
      );
    }
  });
}
