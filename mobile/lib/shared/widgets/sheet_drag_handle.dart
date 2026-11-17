import 'package:flutter/material.dart';

/// The bar at the top of a bottom sheet: pulled down (or tapped by a screen reader), it asks the
/// sheet to close through [onDismiss].
///
/// Drawn like Material's own handle, but used where that one cannot be: Material's closes the
/// sheet outright, past any "Discard changes?" the sheet asks. [onDismiss] is usually
/// `Navigator.maybePop`, which lets the sheet ask first.
class SheetDragHandle extends StatefulWidget {
  const SheetDragHandle({required this.onDismiss, super.key});

  final VoidCallback onDismiss;

  /// How far down, or how fast, a pull has to go to close the sheet.
  static const double closeDistance = 48;
  static const double closeVelocity = 700;

  @override
  State<SheetDragHandle> createState() => _SheetDragHandleState();
}

class _SheetDragHandleState extends State<SheetDragHandle> {
  double _pulled = 0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sheetTheme = Theme.of(context).bottomSheetTheme;
    final size = sheetTheme.dragHandleSize ?? const Size(32, 4);

    return Semantics(
      label: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      button: true,
      onTap: widget.onDismiss,
      child: GestureDetector(
        key: const ValueKey('sheet-drag-handle'),
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onVerticalDragStart: (_) => _pulled = 0,
        onVerticalDragUpdate: (details) => _pulled += details.delta.dy,
        onVerticalDragEnd: (details) {
          final fast =
              (details.primaryVelocity ?? 0) > SheetDragHandle.closeVelocity;
          if (fast || _pulled > SheetDragHandle.closeDistance) {
            widget.onDismiss();
          }
          _pulled = 0;
        },
        child: SizedBox(
          height: 36,
          width: double.infinity,
          child: Center(
            child: Container(
              width: size.width,
              height: size.height,
              decoration: BoxDecoration(
                color:
                    sheetTheme.dragHandleColor ??
                    scheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(size.height / 2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
