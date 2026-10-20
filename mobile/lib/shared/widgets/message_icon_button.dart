import 'package:flutter/material.dart';
import 'package:zuno/features/booking/presentation/screens/booking_chat_screen.dart';

/// Opens one booking's conversation from a list row — the small sibling of `CallIconButton`.
///
/// Takes the words rather than a booking, in the same way the call button takes a number rather
/// than a person: the chat screen needs a title and the other side's name, and which of the two
/// parties counts as "the other side" is the caller's business, not this button's.
class MessageIconButton extends StatelessWidget {
  const MessageIconButton({
    required this.bookingId,
    required this.title,
    required this.counterpartName,
    this.tooltip,
    this.iconSize,
    super.key,
  });

  final String bookingId;

  /// What the conversation is about — the service or variant, as the row above it reads.
  final String title;

  /// The person on the other end, from the reader's side.
  final String counterpartName;

  final String? tooltip;

  /// Null keeps IconButton's own default, so the button sits at whatever size the
  /// surrounding screen uses. Set it where the neighbouring icons are smaller than
  /// standard and a full-size message button would tower over them.
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.chat_bubble_outline),
      iconSize: iconSize,
      tooltip: tooltip ?? 'Message',
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => BookingChatScreen(
            bookingId: bookingId,
            title: title,
            counterpartName: counterpartName,
          ),
        ),
      ),
    );
  }
}
