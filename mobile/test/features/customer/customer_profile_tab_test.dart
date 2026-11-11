import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/core/theme/app_theme.dart';
import 'package:zuno/features/auth/domain/entities/user.dart';
import 'package:zuno/features/auth/presentation/providers/auth_notifier.dart';
import 'package:zuno/features/auth/presentation/providers/auth_state.dart';
import 'package:zuno/features/booking/domain/entities/booking.dart';
import 'package:zuno/features/booking/domain/entities/booking_message.dart';
import 'package:zuno/features/booking/presentation/providers/booking_message_providers.dart';
import 'package:zuno/features/booking/presentation/providers/customer_bookings_notifier.dart';
import 'package:zuno/features/customer/presentation/screens/customer_profile_tab.dart';
import 'package:zuno/shared/legal/legal_document.dart';

import '../../legal/file_asset_bundle.dart';

/// The customer's Profile tab: flat sections with a bold title and short rows — an icon in the
/// app's colour, a name, a chevron where it leads somewhere.
void main() {
  Future<void> pump(WidgetTester tester, {ThemeData? theme}) async {
    tester.view.physicalSize = const Size(360, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_SignedIn.new),
          customerBookingsProvider.overrideWith(_NoBookings.new),
          bookingThreadsProvider.overrideWith(_NoThreads.new),
        ],
        child: DefaultAssetBundle(
          bundle: FileAssetBundle(),
          child: MaterialApp(
            theme: theme ?? AppTheme.light,
            home: const Scaffold(body: CustomerProfileTab()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('who is signed in sits on top', (tester) async {
    await pump(tester);

    expect(find.text('Apple A'), findsOneWidget);
    expect(find.text('apple@example.com'), findsOneWidget);
    expect(find.text('8590182955'), findsOneWidget);
  });

  testWidgets('account settings read as short rows with chevrons', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Account settings'), findsOneWidget);
    for (final row in ['Edit profile', 'Change password', 'App permissions']) {
      final tile = find.widgetWithText(ListTile, row);
      expect(tile, findsOneWidget);
      expect(
        find.descendant(
          of: tile,
          matching: find.byIcon(Icons.chevron_right_rounded),
        ),
        findsOneWidget,
        reason: '$row leads somewhere',
      );
    }
    // A fact, not a link: no chevron.
    final type = find.widgetWithText(ListTile, 'Account type');
    expect(
      find.descendant(of: type, matching: find.text('Customer')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: type,
        matching: find.byIcon(Icons.chevron_right_rounded),
      ),
      findsNothing,
    );
    // The old long wording is gone.
    expect(find.text('Edit your details'), findsNothing);
    expect(find.text('Name and mobile number'), findsNothing);
  });

  for (final (name, theme) in [
    ('light', AppTheme.light),
    ('dark', AppTheme.dark),
  ]) {
    testWidgets('row icons are the primary colour, Log out the error ($name)', (
      tester,
    ) async {
      await pump(tester, theme: theme);
      final scheme = theme.colorScheme;

      for (final icon in [
        Icons.person_outline_rounded,
        Icons.lock_outline_rounded,
        Icons.shield_outlined,
        Icons.badge_outlined,
      ]) {
        expect(tester.widget<Icon>(find.byIcon(icon)).color, scheme.primary);
      }
      expect(
        tester.widget<Icon>(find.byIcon(Icons.logout_rounded)).color,
        scheme.error,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Help and legal lists help, privacy, terms and licences', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Help and legal'), findsOneWidget);
    for (final row in [
      'Help and support',
      'Privacy policy',
      'Terms of use',
      'Open-source licences',
    ]) {
      expect(find.widgetWithText(ListTile, row), findsOneWidget);
    }

    await tester.tap(find.text('Privacy policy'));
    await tester.pumpAndSettle();
    expect(find.byType(LegalDocumentScreen), findsOneWidget);
    expect(
      find.textContaining('We do not sell your data', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('Log out asks first', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();

    expect(find.text('Log out?'), findsOneWidget);
    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();
    expect(find.text('Log out?'), findsNothing);
  });

  testWidgets('fits a 320dp phone', (tester) async {
    tester.view.physicalSize = const Size(320, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_SignedIn.new),
          customerBookingsProvider.overrideWith(_NoBookings.new),
          bookingThreadsProvider.overrideWith(_NoThreads.new),
        ],
        child: DefaultAssetBundle(
          bundle: FileAssetBundle(),
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(body: CustomerProfileTab()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('About Zuno'), findsOneWidget);
  });
}

class _SignedIn extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthAuthenticated(
    User(
      id: 'c1',
      firstName: 'Apple',
      lastName: 'A',
      email: 'apple@example.com',
      phoneNumber: '8590182955',
      role: 'Customer',
      emailConfirmed: true,
      phoneNumberConfirmed: true,
    ),
  );
}

class _NoBookings extends CustomerBookingsNotifier {
  @override
  Future<List<Booking>> build() async => const [];
}

class _NoThreads extends BookingThreads {
  @override
  Future<List<BookingThread>> build() async => const [];
}
