/// Renders a timestamp as a short, human-readable age — "1 hour ago", "3 days ago".
///
/// Deliberately dependency-free and approximate: it is used for "when was this posted"
/// labels, where the reader wants a rough sense of recency, not an exact duration.
String timeAgo(DateTime timestamp, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final difference = reference.difference(timestamp.toLocal());

  // Clock skew between device and server can make a fresh record look slightly
  // future-dated; treat anything at or ahead of now as brand new.
  if (difference.isNegative || difference.inSeconds < 60) {
    return 'just now';
  }
  if (difference.inMinutes < 60) {
    return _plural(difference.inMinutes, 'minute');
  }
  if (difference.inHours < 24) {
    return _plural(difference.inHours, 'hour');
  }
  if (difference.inDays < 7) {
    return _plural(difference.inDays, 'day');
  }
  if (difference.inDays < 30) {
    return _plural(difference.inDays ~/ 7, 'week');
  }
  if (difference.inDays < 365) {
    return _plural(difference.inDays ~/ 30, 'month');
  }
  return _plural(difference.inDays ~/ 365, 'year');
}

String _plural(int value, String unit) =>
    '$value $unit${value == 1 ? '' : 's'} ago';
