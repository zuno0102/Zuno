import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/core/theme/app_theme.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/features/rental/domain/entities/rental_payment.dart';
import 'package:zuno/features/rental/presentation/widgets/rental_collect_sheet.dart';

/// The business's UPI QR, shown as a Google Pay style payment card: name on top, the QR with a ₹
/// mark, the amount large, and the UPI apps that pay it at the foot.
void main() {
  Future<void> pump(
    WidgetTester tester, {
    ThemeData? theme,
    double width = 360,
    String payee = 'Joy Rentals',
    String note = 'Advance for 100 Plastic chair',
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: RentalUpiQr(
              upiId: 'joy@okhdfcbank',
              payee: payee,
              amount: 500,
              note: note,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('shows the business, the amount and the UPI apps', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Joy Rentals'), findsOneWidget);
    expect(
      find.text('J'),
      findsOneWidget,
      reason: 'the initial, as GPay shows',
    );
    expect(find.text('UPI ID: joy@okhdfcbank'), findsOneWidget);
    expect(find.text(rupees(500)), findsOneWidget);
    expect(find.text('Scan to pay ${rupees(500)}'), findsOneWidget);
    expect(find.text('Advance for 100 Plastic chair'), findsOneWidget);
    expect(find.text('Scan and pay with any UPI app'), findsOneWidget);
    for (final app in RentalUpiQr.apps) {
      expect(find.text(app), findsOneWidget);
    }
    expect(find.byIcon(Icons.currency_rupee_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the QR pays the business that amount in any UPI app', (
    tester,
  ) async {
    await pump(tester);

    final qr = tester.widget<QrImageView>(find.byType(QrImageView));
    final card = tester.widget<RentalUpiQr>(find.byType(RentalUpiQr));
    final link = Uri.parse(
      rentalUpiUri(
        upiId: card.upiId,
        payee: card.payee,
        amount: card.amount,
        note: card.note,
      ),
    );
    expect(link.scheme, 'upi');
    expect(link.host, 'pay');
    expect(link.queryParameters['pa'], 'joy@okhdfcbank');
    expect(link.queryParameters['pn'], 'Joy Rentals');
    expect(link.queryParameters['am'], '500.00');
    expect(link.queryParameters['cu'], 'INR');
    // The ₹ mark covers the middle, so the QR carries the most error correction.
    expect(qr.errorCorrectionLevel, QrErrorCorrectLevel.H);
  });

  for (final (name, theme) in [
    ('light', AppTheme.light),
    ('dark', AppTheme.dark),
  ]) {
    testWidgets('stays a white card with dark modules in $name mode', (
      tester,
    ) async {
      await pump(tester, theme: theme);

      final card = tester.widget<Container>(
        find.byKey(const ValueKey('rental-upi-qr')),
      );
      expect((card.decoration! as BoxDecoration).color, AppColors.qrBackdrop);
      final qr = tester.widget<QrImageView>(find.byType(QrImageView));
      final modules = qr.dataModuleStyle.color!;
      expect(
        modules.computeLuminance(),
        lessThan(0.1),
        reason: 'a scanner reads dark modules on white',
      );
      final payee = tester.widget<Text>(
        find.byKey(const ValueKey('rental-upi-qr-payee')),
      );
      expect(payee.style!.color!.computeLuminance(), lessThan(0.2));
    });
  }

  for (final width in [320.0, 360.0, 412.0]) {
    testWidgets('fits a ${width.toInt()}dp phone with a long business name', (
      tester,
    ) async {
      await pump(
        tester,
        width: width,
        payee: 'Sri Lakshmi Tent House and Function Rentals',
      );

      expect(tester.takeException(), isNull);
      final card = tester.getRect(find.byKey(const ValueKey('rental-upi-qr')));
      final qr = tester.getRect(find.byType(QrImageView));
      expect(qr.left, greaterThanOrEqualTo(card.left));
      expect(qr.right, lessThanOrEqualTo(card.right));
      expect(qr.width, greaterThanOrEqualTo(160), reason: 'big enough to scan');
    });
  }

  testWidgets('a blank payee still shows a name', (tester) async {
    await pump(tester, payee: '  ');

    expect(find.text('UPI payment'), findsOneWidget);
  });
}
