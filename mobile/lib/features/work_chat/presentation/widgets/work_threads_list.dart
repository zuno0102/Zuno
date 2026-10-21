import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/core/constants/api_constants.dart';
import 'package:zuno/core/utils/relative_time.dart';
import 'package:zuno/features/work_chat/domain/entities/work_thread.dart';
import 'package:zuno/features/work_chat/presentation/providers/work_chat_providers.dart';
import 'package:zuno/features/work_chat/presentation/screens/work_chat_screen.dart';
import 'package:zuno/shared/widgets/error_banner.dart';

/// Every business–worker conversation this person has, one per worker (for a business) or one per
/// business (for a worker) — drawn like the booking chat list so the two read the same.
///
/// A conversation appears the moment either side writes; it is started from a job card or a crew
/// row. What to show before then comes in as [emptyState], the same way as the booking list.
class WorkThreadsList extends ConsumerWidget {
  const WorkThreadsList({required this.emptyState, super.key});

  final Widget emptyState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threadsAsync = ref.watch(workThreadsProvider);

    return threadsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ErrorBanner(message: error.toString()),
        ),
      ),
      data: (threads) {
        if (threads.isEmpty) return emptyState;

        return RefreshIndicator(
          onRefresh: () => ref.refresh(workThreadsProvider.future),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: threads.length,
            separatorBuilder: (_, _) => const Divider(height: 1, indent: 76),
            itemBuilder: (context, index) =>
                _WorkThreadRow(thread: threads[index]),
          ),
        );
      },
    );
  }
}

class _WorkThreadRow extends StatelessWidget {
  const _WorkThreadRow({required this.thread});

  final WorkThread thread;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final image = thread.counterpartImageUrl;
    final hasImage = image != null && image.isNotEmpty;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: theme.colorScheme.primaryContainer,
        backgroundImage: hasImage
            ? CachedNetworkImageProvider('${ApiConstants.baseUrl}$image')
            : null,
        child: hasImage
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
                fontWeight: thread.hasUnread
                    ? FontWeight.w800
                    : FontWeight.w600,
              ),
            ),
          ),
          Text(
            timeAgo(thread.lastMessageAt),
            style: theme.textTheme.labelSmall?.copyWith(
              color: thread.hasUnread
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: thread.hasUnread ? FontWeight.w700 : null,
            ),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Row(
          children: [
            Expanded(
              child: Text(
                // "You:" so a preview of your own message is not mistaken for a reply.
                thread.lastMessageIsMine
                    ? 'You: ${thread.lastMessage}'
                    : thread.lastMessage,
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
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => WorkChatScreen(
            counterpartId: thread.counterpartId,
            counterpartName: thread.counterpartName,
          ),
        ),
      ),
    );
  }
}
