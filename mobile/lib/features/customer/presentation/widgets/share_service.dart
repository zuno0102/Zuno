import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zuno/shared/widgets/app_messages.dart';

/// Puts a service on the clipboard so it can be passed to somebody.
///
/// A copy rather than the system share sheet, which would mean another package. On the web this is
/// the page's own address, which is what a person wants to send; on a phone there is no address to
/// send, so it is the name and the price — enough for the other person to find it.
///
/// Worth replacing with a real share sheet if this gets used; the button stays where it is either
/// way, and only this function changes.
Future<void> shareService(
  BuildContext context, {
  required String name,
  required String price,
}) async {
  final messenger = AppMessenger.of(context);

  final address = Uri.base;
  final isPage = address.scheme == 'http' || address.scheme == 'https';

  await Clipboard.setData(
    ClipboardData(text: isPage ? address.toString() : '$name — $price'),
  );

  messenger.showSuccess(isPage ? 'Link copied.' : 'Details copied.');
}
