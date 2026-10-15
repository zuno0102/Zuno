import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zuno/shared/widgets/app_messages.dart';

Future<void> launchPhoneCall(BuildContext context, String phoneNumber) async {
  final uri = Uri(scheme: 'tel', path: phoneNumber);
  final launched = await launchUrl(uri);
  if (!launched && context.mounted) {
    context.showFailureMessage('Could not open the dialer.');
  }
}

class CallIconButton extends StatelessWidget {
  const CallIconButton({
    required this.phoneNumber,
    this.tooltip,
    this.iconSize,
    super.key,
  });

  final String phoneNumber;
  final String? tooltip;

  /// Null keeps IconButton's own default, so the button sits at whatever size the
  /// surrounding screen uses. Set it where the neighbouring icons are smaller than
  /// standard and a full-size call button would tower over them.
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.call),
      iconSize: iconSize,
      tooltip: tooltip ?? 'Call',
      onPressed: () => launchPhoneCall(context, phoneNumber),
    );
  }
}
