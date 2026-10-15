import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/features/worker/domain/entities/worker_profile.dart';
import 'package:zuno/features/worker/presentation/widgets/worker_profile_edit_sheet.dart';

/// Editing a worker's own details, and saying so afterwards.
///
/// The sheet saved and closed without a word. Two screens open it and neither said anything, so a
/// worker who had just changed the account their wages are paid into watched it close with no sign
/// it had worked — and the one thing they would want confirmed is exactly that one.
WorkerProfile _profile() => const WorkerProfile(
  id: 'w1',
  fullName: 'Test Worker',
  phoneNumber: '9100007530',
  email: 'worker@zuno.local',
  availabilityStatus: 'Available',
  verificationStatus: 'Pending',
  level: 1,
  levelName: 'New',
  jobsToNextLevel: 2,
  upiVpa: 'test@oksbi',
  hasPayoutDestination: true,
  canReceivePayouts: true,
  payoutVerificationStatus: 'Verified',
  totalEarned: 0,
  owedToYou: 0,
  jobsCompleted: 0,
  jobsPaid: 0,
  businessesWorkedFor: 0,
  offersDeclined: 0,
  openDisputes: 0,
);

Future<void> openSheet(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showWorkerProfileEditSheet(context, profile: _profile()),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the sheet offers every field a worker can correct', (
    tester,
  ) async {
    await openSheet(tester);

    // The name was the one detail with no way back: typed wrong at registration, it followed the
    // worker onto every job they ever applied for.
    expect(find.widgetWithText(TextFormField, 'First name'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Last name'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Phone number'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'UPI address'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('the name boxes open filled with the name they have', (
    tester,
  ) async {
    await openSheet(tester);

    expect(find.text('Test'), findsOneWidget);
    expect(find.text('Worker'), findsOneWidget);
  });

  testWidgets('a name cannot be saved blank', (tester) async {
    await openSheet(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'First name'),
      '',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your first name.'), findsOneWidget);
    // Still open, so nothing was saved and nothing was lost.
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('saving an untouched form claims nothing and closes', (
    tester,
  ) async {
    await openSheet(tester);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Closed, with no claim of a save — and crucially no request either, since nothing changed.
    expect(find.text('Save'), findsNothing);
    expect(find.text('Profile updated.'), findsNothing);
  });
}
