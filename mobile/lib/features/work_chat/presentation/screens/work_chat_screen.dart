import 'package:flutter/material.dart';
import 'package:zuno/features/booking/presentation/screens/booking_chat_screen.dart';
import 'package:zuno/features/work_chat/presentation/providers/work_chat_providers.dart';

/// The conversation between a business and one worker on its team.
///
/// The same chat screen as a booking's, so both read alike. [counterpartId] is the other side's
/// profile: the worker when the business opens it, the business when the worker does.
class WorkChatScreen extends StatelessWidget {
  const WorkChatScreen({
    required this.counterpartId,
    required this.counterpartName,
    this.subtitle = 'Work chat',
    super.key,
  });

  final String counterpartId;
  final String counterpartName;

  /// The line under the name — the job it was opened from, when there is one.
  final String subtitle;

  @override
  Widget build(BuildContext context) => ChatScreen(
    title: subtitle,
    counterpartName: counterpartName,
    messages: workConversationProvider(counterpartId),
    onSend: (ref, body) =>
        ref.read(workConversationProvider(counterpartId).notifier).send(body),
  );
}
