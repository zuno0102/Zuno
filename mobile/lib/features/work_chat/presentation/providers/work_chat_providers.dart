import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zuno/features/auth/presentation/providers/auth_notifier.dart';
import 'package:zuno/features/auth/presentation/providers/auth_providers.dart';
import 'package:zuno/features/auth/presentation/providers/auth_state.dart';
import 'package:zuno/features/booking/domain/entities/booking_message.dart';
import 'package:zuno/features/work_chat/data/datasources/work_message_remote_datasource.dart';
import 'package:zuno/features/work_chat/domain/entities/work_thread.dart';

part 'work_chat_providers.g.dart';

@Riverpod(keepAlive: true)
WorkMessageRemoteDataSource workMessageDataSource(Ref ref) =>
    WorkMessageRemoteDataSource(ref.watch(dioClientProvider));

/// Every business–worker conversation the signed-in user has — what the Messages lists show.
///
/// Polled like the booking chat list, so a reply shows up as a count without anyone refreshing.
/// Signed out, it asks nothing.
@Riverpod(keepAlive: true)
class WorkThreads extends _$WorkThreads {
  Timer? _poll;

  static const _pollEvery = Duration(seconds: 15);

  @override
  Future<List<WorkThread>> build() async {
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

  Future<List<WorkThread>> _fetch() async {
    final models = await ref.read(workMessageDataSourceProvider).getThreads();
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

/// Unread business–worker messages across every conversation.
@riverpod
int unreadWorkChatCount(Ref ref) =>
    ref
        .watch(workThreadsProvider)
        .value
        ?.fold<int>(0, (sum, t) => sum + t.unreadCount) ??
    0;

/// One business–worker conversation, kept fresh while it is open — polled for the same reasons as
/// a booking conversation, and stopped when the screen closes.
@riverpod
class WorkConversation extends _$WorkConversation {
  Timer? _poll;

  static const _pollEvery = Duration(seconds: 6);

  @override
  Future<List<BookingMessage>> build(String counterpartId) async {
    ref.onDispose(() => _poll?.cancel());
    _poll ??= Timer.periodic(_pollEvery, (_) => _refresh());
    return _fetch();
  }

  Future<List<BookingMessage>> _fetch() async {
    final models = await ref
        .read(workMessageDataSourceProvider)
        .getMessages(counterpartId);
    return models.map((m) => m.toChatMessage()).toList();
  }

  Future<void> _refresh() async {
    if (!ref.mounted) return;
    final next = await AsyncValue.guard(_fetch);
    if (!ref.mounted || next.hasError) return;
    state = next;
  }

  /// Sends, then shows it immediately rather than waiting for the next poll.
  Future<void> send(String body) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return;

    final sent = await ref
        .read(workMessageDataSourceProvider)
        .send(counterpartId: counterpartId, body: trimmed);

    if (!ref.mounted) return;
    state = AsyncData([...?state.value, sent.toChatMessage()]);

    // So the Messages list's preview and count catch up with what was just said.
    ref.invalidate(workThreadsProvider);
  }
}
