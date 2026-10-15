import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/features/hiring_post/domain/entities/hiring_post.dart';
import 'package:zuno/features/hiring_post/presentation/providers/worker_job_offers_notifier.dart';
import 'package:zuno/features/worker/domain/entities/worker_invitation.dart';
import 'package:zuno/features/worker/presentation/providers/worker_invitations_notifier.dart';
import 'package:zuno/features/worker/presentation/screens/hiring_business_screen.dart';
import 'package:zuno/features/worker/presentation/screens/worker_invitations_tab.dart';

/// Everything waiting on a worker's answer.
///
/// Two different things arrive here and they were not the same thing at all: a **job** a business
/// picked this worker for by name, which has a date, a place and a rate — and a **team** invitation,
/// a standing offer to be on a roster, with no job behind it.
///
/// Only the second ever reached this tab. Job offers surfaced in the Find work feed as one line on a
/// card among every other job in the radius, which is no place to find out somebody asked for you.
HiringPost _offer({
  required String title,
  String business = 'Boss T',
  double? distanceKm,
  String? location,
}) => HiringPost(
  id: 'p-$title',
  businessOwnerProfileId: 'b1',
  businessName: business,
  title: title,
  eventDate: DateTime.now().add(const Duration(days: 9)),
  location: location,
  distanceKm: distanceKm,
  workersNeeded: 3,
  salaryAmount: 900,
  salaryUnit: 'PerEvent',
  status: 'Open',
  confirmedCount: 0,
  filledCount: 0,
  createdDate: DateTime.now().subtract(const Duration(days: 1)),
  myApplicationStatus: 'Confirmed',
  myApplicationId: 'app-$title',
);

WorkerInvitation _team({
  required String business,
  String status = 'Invited',
}) => WorkerInvitation(
  id: 'bw-$business',
  businessOwnerProfileId: 'b-$business',
  businessName: business,
  status: status,
  invitedAt: DateTime.now().subtract(const Duration(days: 1)),
  respondedAt: status == 'Invited' ? null : DateTime.now(),
);

class _FakeOffers extends WorkerJobOffersNotifier {
  _FakeOffers(this._rows);
  final List<HiringPost> _rows;

  @override
  Future<List<HiringPost>> build() async => _rows;
}

class _FakeTeams extends WorkerInvitationsNotifier {
  _FakeTeams(this._rows);
  final List<WorkerInvitation> _rows;

  @override
  Future<List<WorkerInvitation>> build() async => _rows;
}

Future<void> pump(
  WidgetTester tester, {
  List<HiringPost> offers = const [],
  List<WorkerInvitation> teams = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        workerJobOffersProvider.overrideWith(() => _FakeOffers(offers)),
        workerInvitationsProvider.overrideWith(() => _FakeTeams(teams)),
      ],
      child: const MaterialApp(home: Scaffold(body: WorkerInvitationsTab())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an empty tab says so rather than showing nothing', (
    tester,
  ) async {
    await pump(tester);

    expect(find.textContaining('No invitations right now'), findsOneWidget);
  });

  group('a job somebody was picked for', () {
    testWidgets('shows what the decision rests on, not just a name', (
      tester,
    ) async {
      await pump(
        tester,
        offers: [
          _offer(
            title: 'Varkala cliff catering',
            distanceKm: 34,
            location: 'Varkala cliff',
          ),
        ],
      );

      expect(find.text('Jobs you were invited to'), findsOneWidget);
      expect(find.text('Varkala cliff catering'), findsOneWidget);
      expect(find.text('Boss T'), findsOneWidget);
      // Pay, where and how far, and how many are wanted — the facts the answer rests on.
      expect(find.textContaining('900'), findsOneWidget);
      expect(find.textContaining('Varkala cliff'), findsWidgets);
      expect(find.textContaining('34 km away'), findsOneWidget);
      expect(find.text('3 people wanted'), findsOneWidget);
    });

    testWidgets('can be answered without opening anything', (tester) async {
      await pump(tester, offers: [_offer(title: 'Varkala cliff catering')]);

      expect(find.text('Accept'), findsOneWidget);
      expect(find.text('Decline'), findsOneWidget);
    });

    testWidgets('opens the full details when tapped', (tester) async {
      await pump(tester, offers: [_offer(title: 'Varkala cliff catering')]);

      await tester.tap(find.text('Varkala cliff catering'));
      await tester.pumpAndSettle();

      expect(find.text('WHAT YOU GET PAID'), findsOneWidget);
      expect(find.text('Crew wanted'), findsOneWidget);

      // Not the business. Somebody who picked this worker by name is not a stranger to check out,
      // and a second button under Accept competes with the answer the sheet exists to collect.
      expect(find.text('About Boss T'), findsNothing);
    });

    testWidgets('declining asks first, because it cannot be undone', (
      tester,
    ) async {
      await pump(tester, offers: [_offer(title: 'Varkala cliff catering')]);

      await tester.tap(find.text('Decline'));
      await tester.pumpAndSettle();

      expect(find.text('Decline this job?'), findsOneWidget);
      expect(find.text('Keep deciding'), findsOneWidget);
    });
  });

  group('a team invitation', () {
    testWidgets('is kept apart from the jobs, and says what it is', (
      tester,
    ) async {
      await pump(
        tester,
        offers: [_offer(title: 'Varkala cliff catering')],
        teams: [_team(business: 'Clash B')],
      );

      expect(find.text('Jobs you were invited to'), findsOneWidget);
      expect(find.text('Teams asking you to join'), findsOneWidget);
      expect(
        find.text('Wants you on their team, for work as it comes up.'),
        findsOneWidget,
      );
    });

    testWidgets('opens the business, since there is no job to show', (
      tester,
    ) async {
      await pump(tester, teams: [_team(business: 'Clash B')]);

      await tester.tap(
        find.text('Wants you on their team, for work as it comes up.'),
      );
      // Pumped by hand: the business page fetches on open, so settling waits on a network call
      // that never comes in a test.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(HiringBusinessScreen), findsOneWidget);
    });
  });

  group('a business already joined', () {
    testWidgets('is listed, so accepting leads somewhere', (tester) async {
      await pump(tester, teams: [_team(business: 'Dash B', status: 'Active')]);

      expect(find.text('Businesses you work for'), findsOneWidget);
      expect(find.text('Dash B'), findsOneWidget);
      expect(find.text('See their open jobs'), findsOneWidget);
    });

    testWidgets('offers no answer to give, because it was already given', (
      tester,
    ) async {
      await pump(tester, teams: [_team(business: 'Dash B', status: 'Active')]);

      expect(find.text('Accept'), findsNothing);
      expect(find.text('Decline'), findsNothing);
    });
  });

  testWidgets('jobs come before teams, because a date can pass', (
    tester,
  ) async {
    await pump(
      tester,
      offers: [_offer(title: 'Varkala cliff catering')],
      teams: [
        _team(business: 'Clash B'),
        _team(business: 'Dash B', status: 'Active'),
      ],
    );

    final jobs = tester.getTopLeft(find.text('Jobs you were invited to')).dy;
    final teams = tester.getTopLeft(find.text('Teams asking you to join')).dy;
    final joined = tester.getTopLeft(find.text('Businesses you work for')).dy;

    expect(jobs, lessThan(teams));
    expect(teams, lessThan(joined));
  });
}
