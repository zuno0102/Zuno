import 'package:flutter/material.dart';
import 'package:zuno/features/work_chat/presentation/screens/work_chat_screen.dart';
import 'package:zuno/shared/widgets/call_icon_button.dart';

/// What the business can do with one crew member, opened by tapping their name on a crew list.
///
/// The row's small icons do the same things, but a name is what people tap. Each action is offered
/// only when it applies — a raise only before that worker is paid, a call only while the job allows
/// it — so the sheet never offers something the server would refuse.
class CrewMemberSheet extends StatelessWidget {
  const CrewMemberSheet._({
    required this.host,
    required this.name,
    required this.detail,
    this.onRaise,
    this.messageCounterpartId,
    this.phone,
  });

  /// The screen the sheet was opened from. Actions run there, after the sheet has closed.
  final BuildContext host;

  final String name;

  /// Their status and wage, as the crew row shows it.
  final String detail;
  final VoidCallback? onRaise;

  /// The worker's profile id when the business may message them.
  final String? messageCounterpartId;

  /// Their number when the business may call them.
  final String? phone;

  /// Opens the sheet, or does nothing when there is no action to offer.
  static Future<void> show(
    BuildContext context, {
    required String name,
    required String detail,
    VoidCallback? onRaise,
    String? messageCounterpartId,
    String? phone,
  }) async {
    if (onRaise == null && messageCounterpartId == null && phone == null) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => CrewMemberSheet._(
        host: context,
        name: name,
        detail: detail,
        onRaise: onRaise,
        messageCounterpartId: messageCounterpartId,
        phone: phone,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Each action closes the sheet first, then runs on the screen underneath it.
    void run(VoidCallback action) {
      Navigator.of(context).pop();
      action();
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              title: Text(
                name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(detail),
            ),
            const Divider(height: 1),
            if (onRaise case final raise?)
              ListTile(
                leading: const Icon(Icons.trending_up_rounded),
                title: const Text('Raise salary'),
                subtitle: const Text('Add extra pay before the crew is paid'),
                onTap: () => run(raise),
              ),
            if (messageCounterpartId case final id?)
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline),
                title: const Text('Message'),
                onTap: () => run(
                  () => Navigator.of(host).push(
                    MaterialPageRoute<void>(
                      builder: (_) => WorkChatScreen(
                        counterpartId: id,
                        counterpartName: name,
                        subtitle: 'Work chat',
                      ),
                    ),
                  ),
                ),
              ),
            if (phone case final number?)
              ListTile(
                leading: const Icon(Icons.call_outlined),
                title: const Text('Call'),
                subtitle: Text(number),
                onTap: () => run(() => launchPhoneCall(host, number)),
              ),
          ],
        ),
      ),
    );
  }
}
