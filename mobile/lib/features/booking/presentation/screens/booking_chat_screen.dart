import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:zuno/features/booking/domain/entities/booking_message.dart';
import 'package:zuno/features/booking/presentation/providers/booking_message_providers.dart';
import 'package:zuno/shared/widgets/error_banner.dart';
import 'package:zuno/shared/widgets/app_messages.dart';

/// The conversation on one booking, between the customer and the business.
///
/// Opened from the Chat tab or from the booking itself, and the same screen serves both sides — a
/// customer and a business see their own messages on the right, because the server says which are
/// theirs rather than the app guessing from the role it signed in as.
class BookingChatScreen extends StatelessWidget {
  const BookingChatScreen({
    required this.bookingId,
    required this.title,
    required this.counterpartName,
    this.onOpenOrder,
    super.key,
  });

  final String bookingId;

  /// What the order is for, so somebody with three jobs from one business knows which this is.
  final String title;

  final String counterpartName;

  /// Opens the order being discussed. Left null where this side has no screen to open.
  final VoidCallback? onOpenOrder;

  @override
  Widget build(BuildContext context) => ChatScreen(
    title: title,
    counterpartName: counterpartName,
    onOpenOrder: onOpenOrder,
    messages: bookingConversationProvider(bookingId),
    onSend: (ref, body) =>
        ref.read(bookingConversationProvider(bookingId).notifier).send(body),
  );
}

/// A conversation screen: bubbles, read ticks, and a composer.
///
/// Shared by every chat in the app — customer↔business on a booking and business↔worker on a team —
/// so they look and behave the same. Each passes where its messages come from and how to send one.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    required this.title,
    required this.counterpartName,
    required this.messages,
    required this.onSend,
    this.onOpenOrder,
    super.key,
  });

  /// The line under the other side's name: what the order is for, or what the chat is about.
  final String title;

  final String counterpartName;

  /// Opens whatever the chat is about. Given one, [title] becomes the way there; given none,
  /// it stays a plain label — a worker chat is about a person, not something openable.
  final VoidCallback? onOpenOrder;

  /// The conversation, oldest first, kept fresh while the screen is open.
  final ProviderListenable<AsyncValue<List<BookingMessage>>> messages;

  /// Sends one message; throws if it could not be sent, so the words are put back.
  final Future<void> Function(WidgetRef ref, String body) onSend;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Keeps the newest message in view as the thread grows.
  void _scrollToEnd() {
    if (!_scrollController.hasClients) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty || _isSending) return;

    setState(() => _isSending = true);

    // Cleared immediately: a message that stays in the box while the request is in flight invites a
    // second tap and a duplicate.
    _controller.clear();

    try {
      await widget.onSend(ref, body);
      _scrollToEnd();
    } catch (e) {
      if (!mounted) return;
      // Put back what they wrote. Losing somebody's words because the network dropped is the one
      // failure a chat must never have.
      _controller.text = body;
      context.showFailureMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final messagesAsync = ref.watch(widget.messages);

    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.counterpartName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Shrinks before the chevron does, so a long job name is clipped rather than
            // pushing the arrow off the end of the bar.
            Flexible(
              child: Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: widget.onOpenOrder == null
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.colorScheme.primary,
                ),
              ),
            ),
            if (widget.onOpenOrder != null) ...[
              const SizedBox(width: 2),
              Icon(
                Icons.chevron_right,
                size: 16,
                color: theme.colorScheme.primary,
              ),
            ],
          ],
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        // The job name doubles as the way back to the job. Three conversations about three
        // painting jobs read identically otherwise, and the only way to tell which order was
        // being discussed was to leave the chat and hunt for it.
        title: widget.onOpenOrder == null
            ? heading
            : InkWell(
                onTap: widget.onOpenOrder,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  child: heading,
                ),
              ),
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ErrorBanner(message: error.toString()),
                ),
              ),
              data: (messages) {
                if (messages.isEmpty) {
                  return _EmptyThread(counterpartName: widget.counterpartName);
                }

                _scrollToEnd();

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) => _Bubble(
                    message: messages[index],
                    // The other person's name over the first of their messages in a run, so it is
                    // plain who wrote what without reading every line.
                    showName:
                        !messages[index].isMine &&
                        (index == 0 || messages[index - 1].isMine),
                    // The time is repeated only when the conversation moves on, rather than under
                    // every line of a rapid exchange.
                    showTime:
                        index == messages.length - 1 ||
                        messages[index + 1].isMine != messages[index].isMine,
                  ),
                );
              },
            ),
          ),
          _Composer(
            controller: _controller,
            isSending: _isSending,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.showTime,
    this.showName = false,
  });

  final BookingMessage message;
  final bool showTime;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mine = message.isMine;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: mine
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(mine ? 14 : 4),
            bottomRight: Radius.circular(mine ? 4 : 14),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showName && message.senderName.isNotEmpty) ...[
              Text(
                message.senderName,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
            ],
            Text(
              message.body,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: mine ? theme.colorScheme.onPrimary : null,
              ),
            ),
            if (showTime) ...[
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _clock(message.sentAt),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: mine
                          ? theme.colorScheme.onPrimary.withValues(alpha: 0.75)
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  // Only on your own, because "read" is something the other side did.
                  if (mine) ...[
                    const SizedBox(width: 4),
                    Icon(
                      message.isRead ? Icons.done_all : Icons.done,
                      size: 13,
                      color: theme.colorScheme.onPrimary.withValues(
                        alpha: 0.75,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _clock(DateTime at) {
    final local = at.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${local.hour < 12 ? 'am' : 'pm'}';
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                // Grows for an address, stops before it takes the whole screen.
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: const InputDecoration(
                  hintText: 'Write a message',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton.filled(
              onPressed: isSending ? null : onSend,
              icon: isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded, size: 20),
              tooltip: 'Send',
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyThread extends StatelessWidget {
  const _EmptyThread({required this.counterpartName});

  final String counterpartName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 0, 32, 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 44,
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 14),
            Text(
              'No messages yet',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Write to $counterpartName about this booking — a time, an address, '
              'anything worth having in writing.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
