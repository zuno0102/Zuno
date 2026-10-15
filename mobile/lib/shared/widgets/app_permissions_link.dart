import 'package:flutter/material.dart';
import 'package:zuno/features/customer/presentation/screens/app_permissions_screen.dart';

/// The way into the App permissions page.
///
/// A customer could reach that page from their profile; a worker and a business owner could not,
/// though they use the same camera for the same profile picture and the worker also points it at a
/// job's QR code. A permission somebody can grant but never find again is one they are stuck with.
///
/// One widget so the three say the same thing. The page itself is role-agnostic — it reads what the
/// phone allows, which has nothing to do with who is signed in.
class AppPermissionsLink extends StatelessWidget {
  const AppPermissionsLink({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(
          Icons.shield_outlined,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        title: const Text('App permissions'),
        subtitle: const Text('Camera, photos and location'),
        trailing: Icon(
          Icons.chevron_right,
          size: 18,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const AppPermissionsScreen()),
        ),
      ),
    );
  }
}
