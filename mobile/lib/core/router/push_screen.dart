import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Opens [screen] as a new page, and tells the router about it.
///
/// Use this instead of `Navigator.push(MaterialPageRoute(...))` for anything that is a whole
/// screen. The difference only shows on the device's back button: a route pushed straight onto
/// the Navigator is invisible to the router, so it leaves no history entry, and back either
/// jumped past the screen to wherever the router thought it was or appeared dead. Going through
/// the router gives the screen an entry of its own, and back closes it like the arrow does.
///
/// Returns whatever the screen pops with, so `await`ing a result still works.
///
/// Dialogs and bottom sheets are not screens and do not belong here — they are already handled
/// by the back button through their own routes.
Future<T?> pushScreen<T extends Object?>(BuildContext context, Widget screen) {
  final router = GoRouter.maybeOf(context);

  // Widget tests pump screens under a bare MaterialApp with no router above them. Falling back
  // keeps this usable anywhere rather than making a router a condition of opening a page.
  if (router == null) {
    return Navigator.of(
      context,
    ).push<T>(MaterialPageRoute<T>(builder: (_) => screen));
  }

  return router.push<T>('/screen', extra: screen);
}

/// Opens [sheet] as a bottom sheet that the device's back button closes, like [pushScreen] does
/// for a screen.
///
/// A sheet shown with `showModalBottomSheet` leaves no history entry, so on the web the phone's
/// back button skipped past it and left the app. Going through the router gives the sheet an entry
/// of its own: back closes the sheet — asking first through [SheetLeaveGuard] when it has unsaved
/// changes. The sheet draws its own SheetDragHandle: the stock one closes past any question.
Future<T?> pushSheet<T extends Object?>(BuildContext context, Widget sheet) {
  final router = GoRouter.maybeOf(context);

  // Widget tests pump under a bare MaterialApp with no router: the same sheet, opened directly.
  if (router == null) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      showDragHandle: false,
      builder: (_) => sheet,
    );
  }

  return router.push<T>('/sheet', extra: sheet);
}

/// The bottom sheet behind the `/sheet` route — as `showModalBottomSheet` would show it, but a
/// page, so the router (and the browser's history) knows about it.
class SheetPage<T> extends Page<T> {
  const SheetPage({required this.child, super.key, super.name});

  final Widget child;

  @override
  Route<T> createRoute(BuildContext context) => ModalBottomSheetRoute<T>(
    settings: this,
    isScrollControlled: true,
    enableDrag: false,
    showDragHandle: false,
    builder: (_) => child,
  );
}

/// Lets a sheet opened with [pushSheet] say whether it may be left, for the times the router takes
/// it away without asking the sheet itself — the browser's back button. The sheet registers
/// [watch] while it is open; the `/sheet` route asks [mayLeave] before it goes.
abstract final class SheetLeaveGuard {
  static final _asks = Expando<Future<bool> Function()>('sheet leave guard');

  /// [sheet] is the widget given to [pushSheet]; [ask] answers whether it may close now.
  static void watch(Widget sheet, Future<bool> Function() ask) =>
      _asks[sheet] = ask;

  static void forget(Widget sheet) => _asks[sheet] = null;

  /// True unless [sheet] is open with a change it was told to keep.
  static Future<bool> mayLeave(Object? sheet) async {
    final ask = sheet is Widget ? _asks[sheet] : null;
    return ask == null ? true : await ask();
  }
}
