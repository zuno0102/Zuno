import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/features/booking/domain/entities/booking.dart';
import 'package:zuno/features/booking/presentation/widgets/booking_status_chip.dart';
import 'package:zuno/features/catalog/data/models/order_stage_model.dart';
import 'package:zuno/features/catalog/domain/entities/order_stage.dart';
import 'package:zuno/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:zuno/shared/widgets/status_pill.dart';

/// Order stages are data: the app shows whatever names, colours and order the server sends, and
/// knows none of them itself (CODING_STANDARDS §1).
///
/// The names below are deliberately not the live ones — if the app had any built in, these tests
/// would catch it showing those instead.
void main() {
  const fromServer = [
    OrderStage(
      code: 'StageB',
      label: 'Second in line',
      sortOrder: 2,
      tone: 'danger',
      showOnWork: true,
    ),
    OrderStage(
      code: 'StageA',
      label: 'First in line',
      sortOrder: 1,
      tone: 'success',
      showOnBookings: true,
      showOnWork: true,
    ),
  ];

  Booking orderAt(String stage) => Booking(
    id: 'b-1',
    businessOwnerProfileId: 'bo-1',
    businessName: 'Demo',
    customerProfileId: 'c-1',
    customerName: 'Asha',
    businessServiceId: 's-1',
    serviceName: 'Painting',
    serviceCategoryName: 'Painting',
    status: 'Confirmed',
    stage: stage,
    scheduledDate: DateTime(2026, 11, 1),
    priceQuoted: 1000,
  );

  group('the stage list', () {
    test('reads every field the server sends', () {
      final stage = OrderStageModel.fromJson({
        'code': 'StageA',
        'label': 'First in line',
        'sortOrder': 4,
        'tone': 'progress',
        'showOnBookings': true,
        'showOnWork': false,
      }).toEntity();

      expect(stage.code, 'StageA');
      expect(stage.label, 'First in line');
      expect(stage.sortOrder, 4);
      expect(stage.statusTone, StatusTone.progress);
      expect(stage.showOnBookings, isTrue);
      expect(stage.showOnWork, isFalse);
    });

    test('each tab gets the stages marked for it, in the server\'s order', () {
      expect(fromServer.onBookings.map((s) => s.code), ['StageA']);
      expect(fromServer.onWork.map((s) => s.code), ['StageA', 'StageB']);
    });

    test('a tone this app does not know reads as waiting, never a crash', () {
      expect(
        const OrderStage(code: 'X', label: 'X', tone: 'sparkly').statusTone,
        StatusTone.waiting,
      );
    });

    test('a code the list does not have still gets readable words', () {
      // While the list loads, or for a stage added on the server after this app was built.
      expect(fromServer.resolve('AwaitingPayment').label, 'Awaiting payment');
      expect(fromServer.resolve('StageB').label, 'Second in line');
    });
  });

  group('the status chip', () {
    Future<void> pump(WidgetTester tester, Booking order) => tester.pumpWidget(
      ProviderScope(
        overrides: [
          orderStagesProvider.overrideWith((ref) async => fromServer),
        ],
        child: MaterialApp(
          home: Scaffold(body: BookingStatusChip(order: order)),
        ),
      ),
    );

    testWidgets(
      'shows the name and colour the server gave the order\'s stage',
      (tester) async {
        await pump(tester, orderAt('StageB'));
        await tester.pumpAndSettle();

        expect(find.text('Second in line'), findsOneWidget);
        expect(
          tester.widget<StatusPill>(find.byType(StatusPill)).tone,
          StatusTone.danger,
        );
      },
    );
  });
}
