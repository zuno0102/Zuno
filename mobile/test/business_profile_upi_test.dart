import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/features/business_owner/domain/entities/business_profile.dart';
import 'package:zuno/features/business_owner/presentation/providers/business_profile_notifier.dart';
import 'package:zuno/features/business_owner/presentation/screens/business_profile_tab.dart';
import 'package:zuno/shared/domain/upi_id.dart';
import 'package:zuno/shared/widgets/profile_incomplete_banner.dart';
import 'package:zuno/shared/widgets/primary_button.dart';

/// The business's UPI ID lives on its profile: required to save it, and asked for until it is there,
/// because every payment QR — Service and Rent — is made from it.
BusinessProfile _profile({String? upiId}) => BusinessProfile(
  id: 'b1',
  businessName: 'Joy Events',
  verificationStatus: 'Verified',
  upiId: upiId,
  missingDetails: upiId == null ? const ['UPI ID'] : const [],
);

class _FakeProfile extends BusinessProfileNotifier {
  _FakeProfile(this._start);

  final BusinessProfile _start;
  final saved = <String>[];

  @override
  Future<BusinessProfile> build() async => _start;

  @override
  Future<void> updateProfile({
    required String businessName,
    required String upiId,
    String? businessType,
    String? gstNumber,
    String? description,
    String? logoUrl,
    String? addressLine1,
    String? addressLine2,
    String? city,
    String? addressState,
    String? postalCode,
    String? country,
  }) async {
    saved.add('$businessName|$upiId');
    state = AsyncData(_profile(upiId: upiId));
  }
}

Future<_FakeProfile> _pump(WidgetTester tester, {String? upiId}) async {
  tester.view.physicalSize = const Size(1080, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final fake = _FakeProfile(_profile(upiId: upiId));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [businessProfileProvider.overrideWith(() => fake)],
      child: const MaterialApp(home: BusinessProfileScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return fake;
}

Future<void> _save(WidgetTester tester) async {
  final save = find.byType(PrimaryButton);
  await tester.ensureVisible(save);
  await tester.tap(save);
  await tester.pumpAndSettle();
}

final _upiField = find.byKey(const ValueKey('business-upi-id'));

void main() {
  testWidgets('a profile without a UPI ID asks for it first', (tester) async {
    await _pump(tester);

    expect(find.byType(ProfileIncompleteBanner), findsOneWidget);
    expect(find.text('Finish your profile: add your UPI ID'), findsOneWidget);
    expect(_upiField, findsOneWidget);
  });

  testWidgets('a complete profile shows its UPI ID and no banner', (
    tester,
  ) async {
    await _pump(tester, upiId: 'joyevents@okhdfcbank');

    expect(find.byType(ProfileIncompleteBanner), findsNothing);
    expect(find.text('joyevents@okhdfcbank'), findsOneWidget);
  });

  testWidgets('the profile cannot be saved without a UPI ID', (tester) async {
    final fake = await _pump(tester);

    await _save(tester);

    expect(
      find.text('Enter your UPI ID — customers pay you by scanning it.'),
      findsOneWidget,
    );
    expect(fake.saved, isEmpty);
  });

  testWidgets('a malformed UPI ID is refused before a round trip', (
    tester,
  ) async {
    final fake = await _pump(tester);

    for (final bad in [
      'joyevents',
      'joy@',
      '@okaxis',
      'joy@12',
      'joy events@ybl',
    ]) {
      await tester.enterText(_upiField, bad);
      await _save(tester);
      expect(find.text(upiIdHint), findsOneWidget, reason: bad);
    }
    expect(fake.saved, isEmpty);
  });

  testWidgets('a valid UPI ID saves with the profile and completes it', (
    tester,
  ) async {
    final fake = await _pump(tester);

    await tester.enterText(_upiField, '  joyevents@okhdfcbank ');
    await _save(tester);

    expect(fake.saved, ['Joy Events|joyevents@okhdfcbank']);
    expect(find.byType(ProfileIncompleteBanner), findsNothing);
    expect(find.text('Business profile updated.'), findsOneWidget);
  });

  test('the UPI ID rule matches the server', () {
    expect(upiIdProblem('ravi@okhdfcbank', missing: 'm'), isNull);
    expect(upiIdProblem('r.k-1@ybl', missing: 'm'), isNull);
    expect(upiIdProblem('', missing: 'm'), 'm');
    expect(upiIdProblem('   ', missing: 'm'), 'm');
    expect(upiIdProblem('ravi', missing: 'm'), upiIdHint);
    expect(upiIdProblem('ravi@12', missing: 'm'), upiIdHint);
    expect(
      upiIdProblem('${'a' * 95}@okaxis', missing: 'm'),
      'That UPI ID is too long.',
    );
  });
}
