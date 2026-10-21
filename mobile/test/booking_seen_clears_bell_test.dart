import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Opening a booking is what clears the bell for that booking, on every side of it.
///
/// The rule is meant to work both ways round: read the notification and the order loses its mark,
/// or read the order and the notification loses its mark. It was only ever wired into the
/// customer's screen, so a business owner opened an order from their own list and the bell went on
/// counting the very thing they had just read — and the only way to clear it was to go back and tap
/// the notification, which is exactly the chore the rule exists to remove.
///
/// Checked against the source rather than by pumping three screens, because what went wrong was
/// drift: one screen had the call and the others never gained it. A missing line is what this has
/// to catch, and it catches it the moment a fourth screen is added without one.
void main() {
  /// Every screen that shows one booking, for whoever is looking at it.
  const screens = [
    'lib/features/customer/presentation/screens/customer_booking_detail_screen.dart',
    'lib/features/business_owner/presentation/screens/business_booking_detail_screen.dart',
    'lib/features/worker/presentation/screens/worker_booking_detail_screen.dart',
  ];

  for (final path in screens) {
    final role = path.split('/')[2];

    test('the $role booking screen marks its booking seen', () {
      final source = File(path).readAsStringSync();

      expect(
        source.contains('markBookingSeen'),
        isTrue,
        reason:
            '$path never tells the bell the booking has been read, so its '
            'notification keeps counting after somebody has opened the thing '
            'it is about.',
      );
    });
  }
}
