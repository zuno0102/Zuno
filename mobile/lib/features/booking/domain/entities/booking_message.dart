/// One message in a booking's conversation.
class BookingMessage {
  const BookingMessage({
    required this.id,
    required this.bookingId,
    required this.senderRole,
    required this.isMine,
    required this.senderName,
    required this.body,
    required this.sentAt,
    this.readAt,
  });

  final String id;
  final String bookingId;

  /// `Customer` or `Business`.
  final String senderRole;

  /// Whether the person reading wrote it.
  ///
  /// Decided by the server rather than by comparing ids here. The app would otherwise need to know
  /// which role it is signed in as to pick a side of the screen, and that question has more than one
  /// answer for an account holding two profiles.
  final bool isMine;

  final String senderName;
  final String body;
  final DateTime sentAt;

  /// When the other side read it. Only meaningful on your own messages.
  final DateTime? readAt;

  bool get isRead => readAt != null;
}

/// A booking with a conversation on it, as the chat list shows it.
class BookingThread {
  const BookingThread({
    required this.bookingId,
    required this.title,
    required this.counterpartName,
    required this.scheduledDate,
    required this.bookingStatus,
    this.counterpartLogoUrl,
    this.lastMessage,
    this.lastMessageAt,
    this.lastMessageIsMine = false,
    this.unreadCount = 0,
  });

  final String bookingId;

  /// What the order is for.
  final String title;

  /// The business to a customer; the customer to a business.
  final String counterpartName;
  final String? counterpartLogoUrl;

  final DateTime scheduledDate;
  final String bookingStatus;

  final String? lastMessage;
  final DateTime? lastMessageAt;
  final bool lastMessageIsMine;

  /// Messages from the other side not yet read.
  final int unreadCount;

  bool get hasUnread => unreadCount > 0;
}
