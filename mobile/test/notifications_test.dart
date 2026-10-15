import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/features/notifications/domain/entities/app_notification.dart';
import 'package:zuno/features/notifications/presentation/providers/notification_providers.dart';
import 'package:zuno/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:zuno/features/notifications/presentation/widgets/notification_bell.dart';

/// The bell, the list, and where a tap lands.
///
/// What the app is responsible for here is narrow and worth pinning down: the server writes the
/// words and decides who gets them, but the app decides whether a row looks unread, whether the
/// badge agrees with the list, and which screen a target opens. The last of those is the half that
/// makes a notification useful rather than an interruption.
class _FakeList extends NotificationList {
  _FakeList(this._notifications, {this.onMarkRead, this.onMarkAllRead});

  final List<AppNotification> _notifications;
  final void Function(String id)? onMarkRead;
  final VoidCallback? onMarkAllRead;

  @override
  Future<List<AppNotification>> build() async => _notifications;

  @override
  Future<void> markRead(String id) async {
    onMarkRead?.call(id);

    final current = state.value ?? const [];
    state = AsyncData([
      for (final n in current) n.id == id ? n.copyWith(isUnread: false) : n,
    ]);
  }

  @override
  Future<void> markAllRead() async {
    onMarkAllRead?.call();

    final current = state.value ?? const [];
    state = AsyncData([
      for (final n in current) n.copyWith(isUnread: false),
    ]);
  }
}

class _FakeCount extends UnreadNotificationCount {
  _FakeCount(this._count);

  final int _count;

  @override
  Future<int> build() async => _count;
}

void main() {
  final createdAt = DateTime.now().subtract(const Duration(minutes: 20));

  AppNotification notification({
    String id = 'n-1',
    String kind = 'BookingConfirmed',
    String title = 'Boss T confirmed your booking',
    String body = 'Wedding catering on Saturday.',
    NotificationTarget target = NotificationTarget.booking,
    String? targetId = 'b-1',
    bool isUnread = true,
  }) => AppNotification(
    id: id,
    kind: kind,
    title: title,
    body: body,
    target: target,
    targetId: targetId,
    isUnread: isUnread,
    createdAt: createdAt,
  );

  Future<void> pumpList(
    WidgetTester tester,
    List<AppNotification> notifications, {
    void Function(AppNotification)? onOpen,
    void Function(String id)? onMarkRead,
    VoidCallback? onMarkAllRead,
  }) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationListProvider.overrideWith(
            () => _FakeList(
              notifications,
              onMarkRead: onMarkRead,
              onMarkAllRead: onMarkAllRead,
            ),
          ),
        ],
        child: MaterialApp(
          home: NotificationsScreen(onOpen: onOpen ?? (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('the list', () {
    testWidgets('shows the words the server wrote, not a rebuilt version', (
      tester,
    ) async {
      // The whole point of storing title and body: a notification is a record of a moment, and
      // the app must not recompose it from anything that has since changed.
      await pumpList(tester, [notification()]);

      expect(find.text('Boss T confirmed your booking'), findsOneWidget);
      expect(find.text('Wedding catering on Saturday.'), findsOneWidget);
    });

    testWidgets('says how long ago, so a stale one is obvious', (tester) async {
      await pumpList(tester, [notification()]);

      expect(find.textContaining('ago'), findsOneWidget);
    });

    testWidgets('a notification with no detail line shows only its title', (
      tester,
    ) async {
      await pumpList(tester, [notification(body: '')]);

      expect(find.text('Boss T confirmed your booking'), findsOneWidget);
      expect(find.text('Wedding catering on Saturday.'), findsNothing);
    });

    testWidgets('an empty inbox explains itself rather than showing nothing', (
      tester,
    ) async {
      await pumpList(tester, const []);

      expect(find.text('Nothing yet'), findsOneWidget);
    });

    testWidgets('offers "mark all read" while something is unread', (
      tester,
    ) async {
      await pumpList(tester, [notification()]);

      expect(find.text('Mark all read'), findsOneWidget);
    });

    testWidgets('and does not offer it once everything has been seen', (
      tester,
    ) async {
      await pumpList(tester, [notification(isUnread: false)]);

      expect(find.text('Mark all read'), findsNothing);
    });

    testWidgets('marking all read clears the offer', (tester) async {
      var cleared = false;

      await pumpList(
        tester,
        [notification(), notification(id: 'n-2')],
        onMarkAllRead: () => cleared = true,
      );

      await tester.tap(find.text('Mark all read'));
      await tester.pumpAndSettle();

      expect(cleared, isTrue);
      expect(find.text('Mark all read'), findsNothing);
    });
  });

  group('tapping a row', () {
    testWidgets('marks it read and opens what it is about', (tester) async {
      String? markedRead;
      AppNotification? opened;

      await pumpList(
        tester,
        [notification()],
        onOpen: (n) => opened = n,
        onMarkRead: (id) => markedRead = id,
      );

      await tester.tap(find.text('Boss T confirmed your booking'));
      await tester.pumpAndSettle();

      expect(markedRead, 'n-1');
      expect(opened?.target, NotificationTarget.booking);
      expect(opened?.targetId, 'b-1');
    });

    /// A target this build has never heard of — a newer server — must not crash the app or strand
    /// somebody on a blank screen. It has been read; that was the content.
    testWidgets('an unrecognised target is read but opens nothing', (
      tester,
    ) async {
      String? markedRead;
      var opened = false;

      await pumpList(
        tester,
        [notification(target: NotificationTarget.unknown, targetId: null)],
        onOpen: (_) => opened = true,
        onMarkRead: (id) => markedRead = id,
      );

      await tester.tap(find.text('Boss T confirmed your booking'));
      await tester.pumpAndSettle();

      expect(markedRead, 'n-1');
      expect(opened, isFalse);
    });

    /// A server bug, not a client one — but pushing a detail screen with a null id would be a
    /// crash rather than a missing screen.
    testWidgets('a target that needs an id and has none opens nothing', (
      tester,
    ) async {
      var opened = false;

      await pumpList(
        tester,
        [notification(target: NotificationTarget.booking, targetId: null)],
        onOpen: (_) => opened = true,
      );

      await tester.tap(find.text('Boss T confirmed your booking'));
      await tester.pumpAndSettle();

      expect(opened, isFalse);
    });

    testWidgets('a tab target needs no id and still opens', (tester) async {
      AppNotification? opened;

      await pumpList(
        tester,
        [
          notification(
            kind: 'TeamInvitation',
            title: 'Boss T wants you on their team',
            target: NotificationTarget.invitations,
            targetId: null,
          ),
        ],
        onOpen: (n) => opened = n,
      );

      await tester.tap(find.text('Boss T wants you on their team'));
      await tester.pumpAndSettle();

      expect(opened?.target, NotificationTarget.invitations);
    });
  });

  group('the badge', () {
    Future<void> pumpBell(WidgetTester tester, int unread) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            unreadNotificationCountProvider.overrideWith(
              () => _FakeCount(unread),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              appBar: AppBar(
                actions: [NotificationBell(onOpen: (_) {})],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows the number waiting', (tester) async {
      await pumpBell(tester, 3);

      expect(find.text('3'), findsOneWidget);
    });

    /// Nothing unread must read as nothing, not as a zero somebody has to interpret.
    testWidgets('shows no badge when there is nothing unread', (tester) async {
      await pumpBell(tester, 0);

      expect(find.text('0'), findsNothing);
      expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
    });

    /// The badge has to stay a badge. Past this it is "a lot", and the list holds the real number.
    testWidgets('caps the count so the badge stays readable', (tester) async {
      await pumpBell(tester, 254);

      expect(find.text('99+'), findsOneWidget);
    });

    testWidgets('the bell opens the list', (tester) async {
      await pumpBell(tester, 1);

      await tester.tap(find.byIcon(Icons.notifications_outlined));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Notifications'), findsOneWidget);
    });
  });

  group('the target the server names', () {
    test('is read by name, so renaming a screen cannot break old rows', () {
      expect(
        NotificationTarget.fromName('BookingRating'),
        NotificationTarget.bookingRating,
      );
      expect(
        NotificationTarget.fromName('HiringPostApplicants'),
        NotificationTarget.hiringPostApplicants,
      );
      expect(NotificationTarget.fromName('Payouts'), NotificationTarget.payouts);
    });

    test('and anything newer than this build becomes unknown', () {
      expect(
        NotificationTarget.fromName('SomethingShippedLater'),
        NotificationTarget.unknown,
      );
      expect(NotificationTarget.fromName(null), NotificationTarget.unknown);
    });

    test('knows which targets are useless without an id', () {
      expect(NotificationTarget.booking.needsId, isTrue);
      expect(NotificationTarget.bookingChat.needsId, isTrue);
      expect(NotificationTarget.hiringPost.needsId, isTrue);

      expect(NotificationTarget.invitations.needsId, isFalse);
      expect(NotificationTarget.payments.needsId, isFalse);
      expect(NotificationTarget.profile.needsId, isFalse);
    });
  });
}
