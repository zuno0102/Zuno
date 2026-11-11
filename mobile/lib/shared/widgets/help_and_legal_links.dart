import 'package:flutter/material.dart';
import 'package:zuno/core/router/push_screen.dart';
import 'package:zuno/shared/legal/legal_document.dart';

/// One way into Help, the Privacy policy, the Terms of use and the open-source licences.
typedef HelpAndLegalLink = ({
  IconData icon,
  String title,
  void Function(BuildContext context) open,
});

/// The rows every profile shows — customer, business and worker alike — in this order. A store
/// requires the privacy policy to be reachable inside the app, whoever is signed in.
final List<HelpAndLegalLink> helpAndLegalLinks = [
  for (final doc in LegalDoc.values)
    (
      icon: doc.icon,
      title: doc.title,
      open: (context) => pushScreen(context, LegalDocumentScreen(doc: doc)),
    ),
  (
    icon: Icons.code_rounded,
    title: 'Open-source licences',
    open: (context) =>
        showLicensePage(context: context, applicationName: 'Zuno'),
  ),
];

/// [helpAndLegalLinks] as a card, for the business and worker profiles.
class HelpAndLegalLinks extends StatelessWidget {
  const HelpAndLegalLinks({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      key: const ValueKey('help-and-legal'),
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < helpAndLegalLinks.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 56),
            ListTile(
              leading: Icon(
                helpAndLegalLinks[i].icon,
                color: scheme.onSurfaceVariant,
              ),
              title: Text(helpAndLegalLinks[i].title),
              trailing: Icon(
                Icons.chevron_right,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
              onTap: () => helpAndLegalLinks[i].open(context),
            ),
          ],
        ],
      ),
    );
  }
}
