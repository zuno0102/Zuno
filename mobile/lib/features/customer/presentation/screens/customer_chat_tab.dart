import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/constants/api_constants.dart';
import 'package:zuno/core/utils/relative_time.dart';
import 'package:zuno/features/booking/domain/entities/booking_message.dart';
import 'package:zuno/features/booking/presentation/providers/booking_message_providers.dart';
import 'package:zuno/features/booking/presentation/screens/booking_chat_screen.dart';
import 'package:zuno/shared/widgets/empty_state.dart';
import 'package:zuno/shared/widgets/error_banner.dart';
import 'package:zuno/shared/widgets/app_messages.dart';

/// Messaging between a customer and a business, one conversation per booking.
///
/// Per booking rather than per business, because a customer who books the same caterer three times is
/// having three different conversations — "what time are you arriving?" means nothing without knowing
/// which day. The booking is already the thing both sides are looking at.
///
/// A booking appears here the moment either side writes something. An empty list of every order ever
/// placed would be worse than nothing, so conversations are started from the booking itself.
class CustomerChatTab extends ConsumerWidget {
  const CustomerChatTab({required this.onGoToBookings, super.key});

  final VoidCallback onGoToBookings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threadsAsync = ref.watch(bookingThreadsProvider);

    return threadsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ErrorBanner(message: error.toString()),
        ),
      ),
      data: (threads) {
        if (threads.isEmpty) {
          return EmptyState(
            icon: Icons.chat_bubble_outline,
            title: 'No messages yet',
            message:
                'Open a booking and send the business a message. Anything you '
                'agree there stays with that booking.',
            actionLabel: 'Go to my bookings',
            onAction: onGoToBookings,
          );
        }

        return RefreshIndicator(
          onRefresh: () => ref.refresh(bookingThreadsProvider.future),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: threads.length,
            separatorBuilder: (_, _) => const Divider(height: 1, indent: 76),
            itemBuilder: (context, index) => _ThreadRow(
              thread: threads[index],
              onDelete: () => _confirmDelete(context, ref, threads[index]),
            ),
          ),
        );
      },
    );
  }
}

/// Asks before clearing a conversation, and says plainly what clearing does.
///
/// Long-press rather than a swipe or a menu, which is where people reach for this on a chat list. The
/// confirmation matters more than the gesture: "delete" sounds total, and this is not — the business
/// keeps its copy, and the thread returns if either side writes again. Saying so stops somebody
/// believing they have erased something they have not.
Future<void> _confirmDelete(
  BuildContext context,
  WidgetRef ref,
  BookingThread thread,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Clear this conversation?'),
      content: Text(
        'It will be removed from your chats. ${thread.counterpartName} keeps '
        'their copy, and the conversation comes back if either of you writes again.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Keep'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(dialogContext).colorScheme.error,
          ),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Clear'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  // Captured before the await: the list rebuilds underneath this once the thread is gone.
  final messenger = AppMessenger.of(context);

  try {
    await ref
        .read(bookingMessageDataSourceProvider)
        .clear(thread.bookingId);
    ref.invalidate(bookingThreadsProvider);
    messenger.showSuccess('Conversation cleared.');
  } catch (e) {
    messenger.showFailure(e.toString().replaceFirst('Exception: ', ''));
  }
}

class _ThreadRow extends StatelessWidget {
  const _ThreadRow({required this.thread, required this.onDelete});

  final BookingThread thread;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final logo = thread.counterpartLogoUrl;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: theme.colorScheme.primaryContainer,
        backgroundImage: logo != null && logo.isNotEmpty
            ? CachedNetworkImageProvider('${ApiConstants.baseUrl}$logo')
            : null,
        child: logo != null && logo.isNotEmpty
            ? null
            : Text(
                thread.counterpartName.isNotEmpty
                    ? thread.counterpartName[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              thread.counterpartName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: thread.hasUnread ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
          if (thread.lastMessageAt case final at?)
            Text(
              timeAgo(at),
              style: theme.textTheme.labelSmall?.copyWith(
                color: thread.hasUnread
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: thread.hasUnread ? FontWeight.w700 : null,
              ),
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          // Which booking, so three jobs from one business do not read as one conversation.
          Text(
            thread.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: Text(
                  // "You:" so a preview of your own message is not mistaken for a reply.
                  thread.lastMessageIsMine
                      ? 'You: ${thread.lastMessage ?? ''}'
                      : thread.lastMessage ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: thread.hasUnread
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: thread.hasUnread ? FontWeight.w700 : null,
                  ),
                ),
              ),
              if (thread.hasUnread) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${thread.unreadCount}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
      isThreeLine: true,
      onLongPress: onDelete,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => BookingChatScreen(
            bookingId: thread.bookingId,
            title: thread.title,
            counterpartName: thread.counterpartName,
          ),
        ),
      ),
    );
  }
}
