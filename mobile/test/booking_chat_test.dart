import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/features/booking/domain/entities/booking_message.dart';
import 'package:zuno/features/booking/presentation/providers/booking_message_providers.dart';
import 'package:zuno/features/booking/presentation/screens/booking_chat_screen.dart';
import 'package:zuno/features/customer/presentation/screens/customer_chat_tab.dart';

/// Messaging between a customer and a business, one conversation per booking.
///
/// The screens are thin — the server decides which messages are yours and what is unread — so these
/// cover what the app is responsible for: putting each side on the right of the screen, saying which
/// booking a thread belongs to, and never losing what somebody typed when a send fails.
class _FakeConversation extends BookingConversation {
  _FakeConversation(this._messages, {this.onSend, this.sendThrows = false});

  final List<BookingMessage> _messages;
  final void Function(String)? onSend;
  final bool sendThrows;

  @override
  Future<List<BookingMessage>> build(String bookingId) async => _messages;

  @override
  Future<void> send(String body) async {
    if (sendThrows) throw Exception('No connection');
    onSend?.call(body);
  }
}

/// The chat list without its 15-second poll, which would stop `pumpAndSettle` from ever settling.
class _FakeThreads extends BookingThreads {
  _FakeThreads(this._threads);

  final List<BookingThread> _threads;

  @override
  Future<List<BookingThread>> build() async => _threads;
}

void main() {
  final sent = DateTime(2026, 10, 6, 14, 30);

  BookingMessage message({
    required String body,
    required bool isMine,
    DateTime? readAt,
    int minutesAfter = 0,
  }) => BookingMessage(
    id: 'm-$body',
    bookingId: 'b-1',
    senderRole: isMine ? 'Customer' : 'Business',
    isMine: isMine,
    senderName: isMine ? 'Zuno Customer' : 'Kerala Painters',
    body: body,
    sentAt: sent.add(Duration(minutes: minutesAfter)),
    readAt: readAt,
  );

  BookingThread thread({
    String lastMessage = 'We arrive at 9.',
    bool lastMessageIsMine = false,
    int unreadCount = 0,
  }) => BookingThread(
    bookingId: 'b-1',
    title: 'Interior wall painting',
    counterpartName: 'Kerala Painters',
    scheduledDate: DateTime(2026, 10, 20),
    bookingStatus: 'Confirmed',
    lastMessage: lastMessage,
    lastMessageAt: sent,
    lastMessageIsMine: lastMessageIsMine,
    unreadCount: unreadCount,
  );

  Future<void> pumpThread(
    WidgetTester tester,
    List<BookingMessage> messages, {
    void Function(String)? onSend,
    bool sendThrows = false,
  }) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookingConversationProvider('b-1').overrideWith(
            () => _FakeConversation(messages, onSend: onSend, sendThrows: sendThrows),
          ),
        ],
        child: const MaterialApp(
          home: BookingChatScreen(
            bookingId: 'b-1',
            title: 'Interior wall painting',
            counterpartName: 'Kerala Painters',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('the thread', () {
    testWidgets('names the other side and which booking it is about', (
      tester,
    ) async {
      // Three jobs from one business would otherwise read as one conversation.
      await pumpThread(tester, [message(body: 'Hello', isMine: false)]);

      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('Kerala Painters')),
        findsOneWidget,
      );
      expect(find.text('Interior wall painting'), findsOneWidget);
    });

    testWidgets('the other side is on the left, named once per run of their messages', (
      tester,
    ) async {
      await pumpThread(tester, [
        message(body: 'Hai', isMine: false),
        message(body: 'Are you free?', isMine: false, minutesAfter: 1),
        message(body: 'Hello', isMine: true, minutesAfter: 2),
      ]);

      final theirs = tester.getCenter(find.text('Hai')).dx;
      final mine = tester.getCenter(find.text('Hello')).dx;
      expect(theirs, lessThan(mine), reason: 'their message on the left, mine on the right');

      // Header + one label over the first of their two messages — not one per line.
      expect(find.text('Kerala Painters'), findsNWidgets(2));
      // Never a name over your own messages.
      expect(find.text('Zuno Customer'), findsNothing);
    });

    testWidgets('shows both sides of the conversation', (tester) async {
      await pumpThread(tester, [
        message(body: 'Is 9 too early?', isMine: true),
        message(body: 'We arrive at 9.', isMine: false, minutesAfter: 5),
      ]);

      expect(find.text('Is 9 too early?'), findsOneWidget);
      expect(find.text('We arrive at 9.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('puts your own messages on the right', (tester) async {
      await pumpThread(tester, [
        message(body: 'theirs', isMine: false),
        message(body: 'mine', isMine: true, minutesAfter: 1),
      ]);

      final mine = tester.getCenter(find.text('mine')).dx;
      final theirs = tester.getCenter(find.text('theirs')).dx;

      expect(mine, greaterThan(theirs));
    });

    testWidgets('a double tick once the other side has read it', (tester) async {
      await pumpThread(tester, [
        message(body: 'read', isMine: true, readAt: sent),
      ]);

      expect(find.byIcon(Icons.done_all), findsOneWidget);
    });

    testWidgets('and a single tick while it is still unread', (tester) async {
      await pumpThread(tester, [message(body: 'unread', isMine: true)]);

      expect(find.byIcon(Icons.done), findsOneWidget);
      expect(find.byIcon(Icons.done_all), findsNothing);
    });

    testWidgets('no ticks on the other side messages', (tester) async {
      // "Read" is something the other side did; showing it on their own message would claim they
      // had read themselves.
      await pumpThread(tester, [message(body: 'theirs', isMine: false)]);

      expect(find.byIcon(Icons.done), findsNothing);
      expect(find.byIcon(Icons.done_all), findsNothing);
    });

    testWidgets('one timestamp per run of messages from the same side', (
      tester,
    ) async {
      // A rapid exchange should not repeat the clock under every line.
      await pumpThread(tester, [
        message(body: 'one', isMine: true),
        message(body: 'two', isMine: true, minutesAfter: 1),
      ]);

      expect(find.byIcon(Icons.done), findsOneWidget);
    });

    testWidgets('an empty thread invites the first message', (tester) async {
      await pumpThread(tester, []);

      expect(find.text('No messages yet'), findsOneWidget);
      expect(find.textContaining('Kerala Painters'), findsWidgets);
    });
  });

  group('sending', () {
    testWidgets('hands the typed message over and clears the box', (
      tester,
    ) async {
      String? captured;
      await pumpThread(tester, [], onSend: (body) => captured = body);

      await tester.enterText(find.byType(TextField), 'See you at 9');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      expect(captured, 'See you at 9');
      expect(find.text('See you at 9'), findsNothing);
    });

    testWidgets('sends nothing when the box is empty', (tester) async {
      var calls = 0;
      await pumpThread(tester, [], onSend: (_) => calls++);

      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      expect(calls, 0);
    });

    testWidgets('nor when it is only spaces', (tester) async {
      var calls = 0;
      await pumpThread(tester, [], onSend: (_) => calls++);

      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      expect(calls, 0);
    });

    testWidgets('puts the words back when sending fails', (tester) async {
      // The one failure a chat must never have: losing what somebody wrote because the network
      // dropped between the tap and the server.
      await pumpThread(tester, [], sendThrows: true);

      await tester.enterText(find.byType(TextField), 'Running late');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Running late'), findsOneWidget);
      expect(find.textContaining('No connection'), findsOneWidget);
    });
  });

  group('the chat list', () {
    Future<void> pumpList(
      WidgetTester tester,
      List<BookingThread> threads,
    ) async {
      tester.view.physicalSize = const Size(900, 1800);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookingThreadsProvider.overrideWith(() => _FakeThreads(threads)),
            // The thread this list opens. Faked as well, because the real conversation provider
            // polls every six seconds and a repeating timer stops `pumpAndSettle` ever settling.
            bookingConversationProvider('b-1').overrideWith(
              () => _FakeConversation(const []),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(body: CustomerChatTab(onGoToBookings: () {})),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('sends you to your bookings when there is nothing yet', (
      tester,
    ) async {
      // Conversations start from a booking, so an empty list has to point there.
      await pumpList(tester, []);

      expect(find.text('No messages yet'), findsOneWidget);
      expect(find.text('Go to my bookings'), findsOneWidget);
    });

    testWidgets('shows who, which booking, and what was last said', (
      tester,
    ) async {
      await pumpList(tester, [thread()]);

      expect(find.text('Kerala Painters'), findsOneWidget);
      expect(find.text('Interior wall painting'), findsOneWidget);
      expect(find.text('We arrive at 9.'), findsOneWidget);
    });

    testWidgets('marks your own last message as yours', (tester) async {
      // Otherwise a preview of something you wrote reads as a reply you have not answered.
      await pumpList(tester, [
        thread(lastMessage: 'See you at 9', lastMessageIsMine: true),
      ]);

      expect(find.text('You: See you at 9'), findsOneWidget);
    });

    testWidgets('counts what the other side sent and you have not read', (
      tester,
    ) async {
      await pumpList(tester, [thread(unreadCount: 3)]);

      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('and shows no badge on a thread with nothing new', (
      tester,
    ) async {
      await pumpList(tester, [thread()]);

      expect(find.text('0'), findsNothing);
    });

    test('the Chat tab counts unread messages across every conversation', () async {
      final container = ProviderContainer(
        overrides: [
          bookingThreadsProvider.overrideWith(
            () => _FakeThreads([thread(unreadCount: 2), thread(unreadCount: 0), thread(unreadCount: 3)]),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.listen(unreadChatCountProvider, (_, _) {});
      await container.read(bookingThreadsProvider.future);

      expect(container.read(unreadChatCountProvider), 5);
    });

    testWidgets('opens the conversation when tapped', (tester) async {
      await pumpList(tester, [thread()]);

      await tester.tap(find.text('Kerala Painters'));
      await tester.pumpAndSettle();

      expect(find.byType(BookingChatScreen), findsOneWidget);
    });

    testWidgets('long press offers to clear it, and asks first', (tester) async {
      await pumpList(tester, [thread()]);

      await tester.longPress(find.text('Kerala Painters'));
      await tester.pumpAndSettle();

      expect(find.text('Clear this conversation?'), findsOneWidget);
      expect(find.text('Keep'), findsOneWidget);
      expect(find.text('Clear'), findsOneWidget);
    });

    testWidgets('and says plainly that the other side keeps theirs', (
      tester,
    ) async {
      // "Delete" sounds total and this is not. Somebody must not walk away believing they have
      // erased something the business can still read.
      await pumpList(tester, [thread()]);

      await tester.longPress(find.text('Kerala Painters'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Kerala Painters keeps'),
        findsOneWidget,
      );
      expect(find.textContaining('comes back if either of you writes'), findsOneWidget);
    });

    testWidgets('keeping it changes nothing', (tester) async {
      await pumpList(tester, [thread()]);

      await tester.longPress(find.text('Kerala Painters'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep'));
      await tester.pumpAndSettle();

      expect(find.text('Clear this conversation?'), findsNothing);
      expect(find.text('Kerala Painters'), findsOneWidget);
    });
  });
}
