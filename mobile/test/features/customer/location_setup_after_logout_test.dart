import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/features/auth/domain/entities/user.dart';
import 'package:zuno/features/auth/presentation/providers/auth_state.dart';
import 'package:zuno/features/customer/presentation/providers/customer_location_sync.dart';
import 'package:zuno/features/rental/presentation/screens/customer_app_shell.dart';

/// The location setup sheet showed over the login screen after logout: the open-time check
/// re-runs when the customer signs out and, while it does, still carries its last answer.
void main() {
  const customer = AuthAuthenticated(
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
  const signedOut = AuthState.unauthenticated();
  const needs = CustomerLocationOpen.needsChoice;

  // What the check really gives while it re-runs after the account changes: loading, still
  // carrying "needs a location" from before — read from a provider, as the app sees it.
  late AsyncValue<CustomerLocationOpen> reRunning;
  setUpAll(() async => reRunning = await _reRunningAfterNeedsChoice());

  test(
    'the re-running value does carry the old answer (why the bug happened)',
    () {
      expect(reRunning.isLoading, isTrue);
      expect(reRunning.value, needs);
    },
  );

  final cases =
      <(String, AsyncValue<CustomerLocationOpen> Function(), AuthState?, bool)>[
        (
          'signed in, check says no location',
          () => const AsyncData(needs),
          customer,
          true,
        ),
        (
          'signed in, location set',
          () => const AsyncData(CustomerLocationOpen.settled),
          customer,
          false,
        ),
        (
          'check still running the first time',
          () => const AsyncLoading(),
          customer,
          false,
        ),
        (
          'logout: check re-running with the last answer',
          () => reRunning,
          signedOut,
          false,
        ),
        ('re-running while still signed in', () => reRunning, customer, false),
        (
          'signed out, old answer',
          () => const AsyncData(needs),
          signedOut,
          false,
        ),
        ('auth not known yet', () => const AsyncData(needs), null, false),
        (
          'check failed',
          () => AsyncError(Exception('offline'), StackTrace.empty),
          customer,
          false,
        ),
      ];

  for (final (name, check, auth, ask) in cases) {
    test('$name → ${ask ? 'asks' : 'does not ask'}', () {
      expect(shouldAskCustomerLocation(check(), auth), ask);
    });
  }
}

Future<AsyncValue<CustomerLocationOpen>> _reRunningAfterNeedsChoice() async {
  final account = StateProvider<String?>((ref) => 'c1');
  final check = FutureProvider<CustomerLocationOpen>((ref) async {
    ref.watch(account);
    return CustomerLocationOpen.needsChoice;
  });
  final container = ProviderContainer();
  final sub = container.listen(check, (_, _) {});
  await container.read(check.future);
  container.read(account.notifier).state = null; // logout
  final value = sub.read();
  container.dispose();
  return value;
}
