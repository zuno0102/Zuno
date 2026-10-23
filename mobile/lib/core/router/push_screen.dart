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
