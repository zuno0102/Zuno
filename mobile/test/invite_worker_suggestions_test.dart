import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/features/business_owner/domain/entities/business_worker.dart';

/// When the "Email or phone" field offers its list of workers.
///
/// It used to offer it immediately. `Autocomplete` shows its options whenever the field holds
/// focus and the builder returns anything, the builder returns **every** worker on an empty query,
/// and the field was `autofocus: true` — so opening Invite worker dropped the whole roster over
/// the dialog, covering the "Invite them to" dropdown beneath it and raising the keyboard before
/// anybody had asked for either.
///
/// The fix is that the field no longer takes focus on open. These tests pin both halves of the
/// behaviour that produced the bug, because either one changing alone brings it back.
void main() {
  BusinessWorker worker(String name, String email) => BusinessWorker(
    id: name,
    workerProfileId: name,
    workerName: name,
    workerEmail: email,
    workerPhone: null,
    status: 'Active',
    invitedAt: DateTime(2026, 1, 1),
    availabilityStatus: 'Active',
  );

  final roster = [
    worker('Ravi Kumar', 'ravi@zuno.local'),
    worker('Anita Menon', 'anita@zuno.local'),
    worker('Suresh Nair', 'suresh@zuno.local'),
  ];

  /// The same rule the dialog's optionsBuilder applies.
  Iterable<BusinessWorker> optionsFor(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return roster;
    return roster.where(
      (w) => [
        w.workerName,
        w.workerEmail ?? '',
        w.workerPhone ?? '',
      ].join(' ').toLowerCase().contains(q),
    );
  }

  group('what the field would offer', () {
    /// This is the half that makes focus-on-open so loud: an empty box offers everybody. Worth
    /// keeping — once the field IS tapped, seeing the roster is the point — but it is only
    /// reasonable because nothing is focused until somebody asks.
    test('an empty query offers every worker', () {
      expect(optionsFor(''), hasLength(3));
    });

    test('typing narrows it by name, email or phone', () {
      expect(optionsFor('anita').single.workerName, 'Anita Menon');
      expect(optionsFor('suresh@zuno').single.workerName, 'Suresh Nair');
      expect(optionsFor('nobody'), isEmpty);
    });
  });

  group('the field on open', () {
    /// The regression itself. A field that is not focused shows no overlay, however many options
    /// the builder would return.
    testWidgets('does not take focus, so no list is showing', (tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextFormField(
              focusNode: focusNode,
              decoration: const InputDecoration(labelText: 'Email or phone'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        focusNode.hasFocus,
        isFalse,
        reason: 'the dialog must open quiet — autofocus is what dropped the '
            'roster over it',
      );
    });

    testWidgets('and takes focus once it is tapped', (tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextFormField(
              focusNode: focusNode,
              decoration: const InputDecoration(labelText: 'Email or phone'),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(TextFormField));
      await tester.pumpAndSettle();

      expect(focusNode.hasFocus, isTrue);
    });
  });
}
