import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/features/notifications/data/datasources/notification_remote_datasource.dart';
import 'package:zuno/features/notifications/data/models/notification_model.dart';
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
    state = AsyncData([for (final n in current) n.copyWith(isUnread: false)]);
  }
}

class _FakeCount extends UnreadNotificationCount {
  _FakeCount(this._count);

  final int _count;

  @override
  Future<int> build() async => _count;
}

/// A datasource that answers from memory, for driving the real [NotificationList].
class _FakeSource implements NotificationRemoteDataSource {
  _FakeSource(this._rows);

  final List<NotificationModel> _rows;
  int markReadCalls = 0;

  /// What the last caller asked about chat, so the bell can be held to leaving it out.
  bool? lastIncludeChat;

  @override
  Future<List<NotificationModel>> getMine({
    int take = 50,
    bool includeChat = false,
  }) async {
    lastIncludeChat = includeChat;
    return _rows;
  }

  @override
  Future<int> getUnreadCount() async => _rows.where((r) => r.isUnread).length;

  @override
  Future<void> markRead(String id) async => markReadCalls++;

  @override
  Future<void> markAllRead() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
        child: MaterialApp(home: NotificationsScreen(onOpen: onOpen ?? (_) {})),
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

    // Opening the list clears nothing by itself. It did for a while, and the Bookings tab counts
    // these same notifications — so a glance at this screen took the number off the offers still
    // waiting for an answer there. Each one clears when its own thing is opened.
    testWidgets('clears nothing merely by being opened', (tester) async {
      var cleared = false;

      await pumpList(tester, [
        notification(),
        notification(id: 'n-2'),
      ], onMarkAllRead: () => cleared = true);

      expect(cleared, isFalse);
    });

    testWidgets('and what is new still reads as new', (tester) async {
      await pumpList(tester, [notification(title: 'Booking confirmed')]);

      final title = tester.widget<Text>(find.text('Booking confirmed'));
      expect(title.style?.fontWeight, FontWeight.w700);
    });

    // The deliberate act. Clearing the lot is something the person asks for, which is also what
    // makes it safe to take the Bookings tab's marks with it.
    testWidgets('and clears the lot when asked to', (tester) async {
      var cleared = false;

      await pumpList(tester, [
        notification(),
      ], onMarkAllRead: () => cleared = true);
      await tester.tap(find.text('Mark all read'));
      await tester.pump();

      expect(cleared, isTrue);
    });

    testWidgets('and offers nothing to clear when nothing is unread', (
      tester,
    ) async {
      await pumpList(tester, [notification(isUnread: false)]);

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

      await pumpList(tester, [
        notification(target: NotificationTarget.booking, targetId: null),
      ], onOpen: (_) => opened = true);

      await tester.tap(find.text('Boss T confirmed your booking'));
      await tester.pumpAndSettle();

      expect(opened, isFalse);
    });

    testWidgets('a tab target needs no id and still opens', (tester) async {
      AppNotification? opened;

      await pumpList(tester, [
        notification(
          kind: 'TeamInvitation',
          title: 'Boss T wants you on their team',
          target: NotificationTarget.invitations,
          targetId: null,
        ),
      ], onOpen: (n) => opened = n);

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
              appBar: AppBar(actions: [NotificationBell(onOpen: (_) {})]),
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
      expect(
        NotificationTarget.fromName('Payouts'),
        NotificationTarget.payouts,
      );
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

  group('marking one read', () {
    NotificationModel row(String id, {bool isUnread = true}) =>
        NotificationModel(
          id: id,
          kind: 'BookingConfirmed',
          title: 'Boss T confirmed your booking',
          body: 'Wedding catering on Saturday.',
          target: 'Booking',
          targetId: 'b-1',
          isUnread: isUnread,
          createdAt: createdAt,
        );

    /// The badge used to drop for a notification nobody had read.
    ///
    /// A shade tap carries an id, and the list only holds a page. When the id was not on that page
    /// the lookup fell back to the *first* row instead of giving up, and if that row happened to
    /// be unread the badge was decremented while the rewrite below it changed nothing at all.
    test('an id this page does not hold leaves the badge alone', () async {
      final source = _FakeSource([row('n-1'), row('n-2')]);
      final container = ProviderContainer(
        overrides: [
          notificationDataSourceProvider.overrideWithValue(source),
          // The real one answers 0 for a signed-out container, which would make every
          // assertion below pass without proving anything.
          unreadNotificationCountProvider.overrideWith(() => _FakeCount(2)),
        ],
      );
      addTearDown(container.dispose);

      await container.read(notificationListProvider.future);
      final before = await container.read(
        unreadNotificationCountProvider.future,
      );

      await container
          .read(notificationListProvider.notifier)
          .markRead('not-on-this-page');

      expect(container.read(unreadNotificationCountProvider).value, before);

      // Told to the server all the same. A message tapped in the phone's tray lands here and is
      // deliberately kept out of this list, so giving up outright would leave it unread for ever —
      // but the badge never counted it, so there is nothing to take off.
      expect(source.markReadCalls, 1);
    });

    test('and one it does hold takes exactly one off', () async {
      final source = _FakeSource([row('n-1'), row('n-2')]);
      final container = ProviderContainer(
        overrides: [
          notificationDataSourceProvider.overrideWithValue(source),
          // The real one answers 0 for a signed-out container, which would make every
          // assertion below pass without proving anything.
          unreadNotificationCountProvider.overrideWith(() => _FakeCount(2)),
        ],
      );
      addTearDown(container.dispose);

      await container.read(notificationListProvider.future);
      final before = await container.read(
        unreadNotificationCountProvider.future,
      );

      await container.read(notificationListProvider.notifier).markRead('n-1');

      expect(container.read(unreadNotificationCountProvider).value, before - 1);
      expect(source.markReadCalls, 1);
    });

    /// The bell carries no messages: a new one already puts a number on the Chat tab, and listing
    /// it here would mark it read the moment somebody opened the bell. The banners in the phone's
    /// own tray are the one caller that does ask for them.
    test('the list asks the server to leave chat out', () async {
      final source = _FakeSource([row('n-1')]);
      final container = ProviderContainer(
        overrides: [notificationDataSourceProvider.overrideWithValue(source)],
      );
      addTearDown(container.dispose);

      await container.read(notificationListProvider.future);

      expect(source.lastIncludeChat, isFalse);
    });
  });
}
