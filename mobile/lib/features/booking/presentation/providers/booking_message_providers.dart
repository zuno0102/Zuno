import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zuno/features/auth/presentation/providers/auth_notifier.dart';
import 'package:zuno/features/auth/presentation/providers/auth_providers.dart';
import 'package:zuno/features/auth/presentation/providers/auth_state.dart';
import 'package:zuno/features/booking/data/datasources/booking_message_remote_datasource.dart';
import 'package:zuno/features/booking/domain/entities/booking_message.dart';

part 'booking_message_providers.g.dart';

@Riverpod(keepAlive: true)
BookingMessageRemoteDataSource bookingMessageDataSource(Ref ref) =>
    BookingMessageRemoteDataSource(ref.watch(dioClientProvider));

/// Every booking the signed-in user has a conversation on — what the Chat tab lists.
///
/// Kept alive and re-asked every few seconds while somebody is signed in, so a new message shows up
/// as a count on the Chat tab and in the list without anyone pulling to refresh — the way WhatsApp
/// shows "2" before you open anything. Signed out, it asks nothing.
@Riverpod(keepAlive: true)
class BookingThreads extends _$BookingThreads {
  Timer? _poll;

  /// Quick enough that a reply is noticed while the app is open, slow enough to cost nothing much.
  static const _pollEvery = Duration(seconds: 15);

  @override
  Future<List<BookingThread>> build() async {
    ref.onDispose(() {
      _poll?.cancel();
      _poll = null;
    });

    final auth = ref.watch(authProvider).value;
    if (auth is! AuthAuthenticated) {
      _poll?.cancel();
      _poll = null;
      return const [];
    }

    _poll ??= Timer.periodic(_pollEvery, (_) => _refresh());
    return _fetch();
  }

  Future<List<BookingThread>> _fetch() async {
    final models = await ref.read(bookingMessageDataSourceProvider).getThreads();
    return models.map((m) => m.toEntity()).toList();
  }

  /// Reloads without a spinner; a failed poll keeps what is on screen.
  Future<void> _refresh() async {
    if (!ref.mounted) return;
    final next = await AsyncValue.guard(_fetch);
    if (!ref.mounted || next.hasError) return;
    state = next;
  }
}

/// Unread messages across every conversation — the number on the Chat tab.
@riverpod
int unreadChatCount(Ref ref) =>
    ref.watch(bookingThreadsProvider).value?.fold<int>(0, (sum, t) => sum + t.unreadCount) ?? 0;

/// One booking's conversation, kept fresh while the thread is open.
///
/// Polled rather than pushed. The app has no socket and adding one for this would be a second way
/// for the server to talk to the client, with its own reconnection and auth story — real work, for a
/// screen somebody has open for a minute at a time. Every few seconds is close enough to live for
/// two people arranging a time, and the poll stops the moment the screen closes because the provider
/// is disposed with it.
@riverpod
class BookingConversation extends _$BookingConversation {
  Timer? _poll;

  /// Often enough to feel like a conversation, rarely enough to be unnoticeable on a phone bill.
  static const _pollEvery = Duration(seconds: 6);

  @override
  Future<List<BookingMessage>> build(String bookingId) async {
    // Stopped when the screen goes: without this the timer would outlive the thread and keep asking
    // the server for a conversation nobody is reading.
    ref.onDispose(() => _poll?.cancel());

    _poll ??= Timer.periodic(_pollEvery, (_) => _refresh());

    return _fetch();
  }

  Future<List<BookingMessage>> _fetch() async {
    final models = await ref
        .read(bookingMessageDataSourceProvider)
        .getMessages(bookingId);
    return models.map((m) => m.toEntity()).toList();
  }

  /// Reloads without the spinner, so a poll does not blank the thread somebody is reading.
  Future<void> _refresh() async {
    if (!ref.mounted) return;

    final next = await AsyncValue.guard(_fetch);

    // A failed poll keeps what is on screen. Losing the conversation because one request timed out
    // on a bad connection would be worse than showing it a few seconds stale.
    if (!ref.mounted || next.hasError) return;
    state = next;
  }

  /// Sends, then shows it immediately rather than waiting for the next poll.
  Future<void> send(String body) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return;

    final sent = await ref
        .read(bookingMessageDataSourceProvider)
        .send(bookingId: bookingId, body: trimmed);

    if (!ref.mounted) return;

    state = AsyncData([...?state.value, sent.toEntity()]);

    // So the chat list's preview and unread badge catch up with what was just said.
    ref.invalidate(bookingThreadsProvider);
  }
}
