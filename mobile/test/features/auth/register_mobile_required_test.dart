import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/core/theme/app_theme.dart';
import 'package:zuno/features/auth/presentation/providers/auth_notifier.dart';
import 'package:zuno/features/auth/presentation/providers/auth_state.dart';
import 'package:zuno/features/auth/presentation/screens/register_screen.dart';
import 'package:zuno/shared/widgets/primary_button.dart';

/// Sign-up needs a mobile number: an empty one is stopped on the form and never reaches the server.
class _SignUps extends AuthNotifier {
  final List<String?> phones = [];

  @override
  Future<AuthState> build() async => const AuthState.unauthenticated();

  @override
  Future<void> register({
    String? email,
    String? phoneNumber,
    required String password,
    required String firstName,
    required String lastName,
    required String role,
  }) async => phones.add(phoneNumber);
}

void main() {
  late _SignUps auth;

  Future<void> fill(WidgetTester tester, {required String mobile}) async {
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    auth = _SignUps();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authProvider.overrideWith(() => auth)],
        child: MaterialApp(theme: AppTheme.light, home: const RegisterScreen()),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> type(String hint, String text) =>
        tester.enterText(find.widgetWithText(TextFormField, hint), text);
    await type('First name', 'Asha');
    await type('Last name', 'Rao');
    await type('Mail id', 'asha@example.com');
    await type('Mobile number', mobile);
    await type('Password', 'Str0ng!Pass');

    final signUp = find.byType(PrimaryButton);
    await tester.ensureVisible(signUp);
    await tester.tap(signUp);
    await tester.pumpAndSettle();
  }

  testWidgets('an empty mobile number is refused on the form', (tester) async {
    await fill(tester, mobile: '');

    expect(find.text('Mobile number is required.'), findsOneWidget);
    expect(auth.phones, isEmpty);
  });

  testWidgets('spaces alone count as empty', (tester) async {
    await fill(tester, mobile: '   ');

    expect(find.text('Mobile number is required.'), findsOneWidget);
    expect(auth.phones, isEmpty);
  });

  testWidgets('a number that is not a mobile is refused', (tester) async {
    await fill(tester, mobile: '12345');

    expect(
      find.text('Enter a 10-digit mobile number, like 98765 43210.'),
      findsOneWidget,
    );
    expect(auth.phones, isEmpty);
  });

  testWidgets('a mobile typed with +91 and spaces is sent as its 10 digits', (
    tester,
  ) async {
    await fill(tester, mobile: '+91 98765 43210');

    expect(find.text('Mobile number is required.'), findsNothing);
    expect(auth.phones, ['9876543210']);
  });
}
