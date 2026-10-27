import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zuno/core/share/system_share.dart';
import 'package:zuno/shared/widgets/app_messages.dart';

/// Opens the system share sheet for one share request. [SystemShare.share] by default; tests
/// pass a fake.
typedef ShareLauncher =
    Future<ShareOutcome> Function({
      required String text,
      String? title,
      String? url,
    });

/// Shares a service through the device's share sheet (WhatsApp, Instagram, Facebook, …).
///
/// On the web the page's own address goes with it, which is what a person wants to send; in the
/// app there is no address, so the name and the price are enough for the other person to find
/// it. Where there is no share sheet (some desktop browsers, plain http) it falls back to
/// copying, as it always did.
Future<void> shareService(
  BuildContext context, {
  required String name,
  required String price,
  ShareLauncher share = SystemShare.share,
}) async {
  final messenger = AppMessenger.of(context);

  final address = Uri.base;
  final isPage = address.scheme == 'http' || address.scheme == 'https';
  final details = '$name — $price';

  // Called before any other await: browsers only open the sheet straight from a tap.
  final outcome = await share(
    title: name,
    text: details,
    url: isPage ? address.toString() : null,
  );
  if (outcome != ShareOutcome.unavailable) return;

  await Clipboard.setData(
    ClipboardData(text: isPage ? address.toString() : details),
  );
  messenger.showSuccess(isPage ? 'Link copied.' : 'Details copied.');
}
