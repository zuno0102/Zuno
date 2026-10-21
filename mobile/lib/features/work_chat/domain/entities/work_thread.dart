/// One business–worker conversation, as the Messages list shows it.
///
/// The other side is a worker when a business is reading, and a business when a worker is.
/// Customers never appear here: the business is the middle man between customers and workers.
class WorkThread {
  const WorkThread({
    required this.counterpartId,
    required this.counterpartName,
    required this.lastMessage,
    required this.lastMessageAt,
    this.counterpartImageUrl,
    this.lastMessageIsMine = false,
    this.unreadCount = 0,
  });

  /// The other side's profile id — what the conversation is opened with.
  final String counterpartId;
  final String counterpartName;
  final String? counterpartImageUrl;

  final String lastMessage;
  final DateTime lastMessageAt;
  final bool lastMessageIsMine;

  /// Messages from the other side not yet read.
  final int unreadCount;

  bool get hasUnread => unreadCount > 0;
}
