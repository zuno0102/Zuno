import 'package:flutter/material.dart';
import 'package:zuno/features/work_chat/presentation/screens/work_chat_screen.dart';

/// Opens the business–worker conversation — the same icon as a booking's message button, so the
/// two read as the same action wherever they appear.
///
/// [counterpartId] is the other side's profile: the business on a worker's job card, the worker on
/// a business's crew row.
class WorkMessageButton extends StatelessWidget {
  const WorkMessageButton({
    required this.counterpartId,
    required this.counterpartName,
    this.subtitle = 'Work chat',
    this.tooltip,
    this.iconSize,
    super.key,
  });

  final String counterpartId;
  final String counterpartName;

  /// The line under the name in the chat — usually the job it was opened from.
  final String subtitle;

  final String? tooltip;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.chat_bubble_outline),
      iconSize: iconSize,
      tooltip: tooltip ?? 'Message',
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => WorkChatScreen(
            counterpartId: counterpartId,
            counterpartName: counterpartName,
            subtitle: subtitle,
          ),
        ),
      ),
    );
  }
}
