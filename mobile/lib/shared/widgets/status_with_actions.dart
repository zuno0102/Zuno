import 'package:flutter/material.dart';

/// The right-hand side of an order or job card, laid out the same way for every role:
///
/// ```
///   [ Confirmed ]
///        ↕ space
///      💬    📞
/// ```
///
/// The status on top, a clear gap, then the actions (message, call) underneath, right-aligned.
/// Each card used to stack these its own way — the business squeezed them 6px apart with buttons
/// shrunk below a comfortable tap size, the customer and worker cards put a phone icon straight
/// under the pill — so the same order looked different depending on who was looking at it.
///
/// The card around this must be able to grow to fit it (a plain row, not a `ListTile`, whose
/// height comes from its text alone and leaves this side about 62px).
class StatusWithActions extends StatelessWidget {
  const StatusWithActions({
    super.key,
    required this.status,
    this.actions = const [],
  });

  /// The status pill.
  final Widget status;

  /// Icon buttons shown under the status, left to right. Nothing is drawn when empty.
  final List<Widget> actions;

  /// Between the status and the buttons, so they read as two things rather than one block.
  static const statusGap = 12.0;

  /// Between two buttons.
  static const actionGap = 8.0;

  /// Material's minimum tap target for dense layouts.
  static const minTapTarget = 40.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        status,
        if (actions.isNotEmpty) ...[
          const SizedBox(height: statusGap),
          CardActions(actions: actions),
        ],
      ],
    );
  }
}

/// A card's icon buttons in a row — the same size and spacing wherever they appear, so a Message or
/// Call button looks alike on every role's cards. [StatusWithActions] uses it under the status;
/// cards laid out differently use it on their own.
class CardActions extends StatelessWidget {
  const CardActions({required this.actions, super.key});

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return IconButtonTheme(
      data: IconButtonThemeData(
        style: IconButton.styleFrom(
          visualDensity: VisualDensity.compact,
          minimumSize: const Size(
            StatusWithActions.minTapTarget,
            StatusWithActions.minTapTarget,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, action) in actions.indexed) ...[
            if (i > 0) const SizedBox(width: StatusWithActions.actionGap),
            action,
          ],
        ],
      ),
    );
  }
}
