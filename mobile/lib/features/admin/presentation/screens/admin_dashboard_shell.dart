import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/features/admin/presentation/screens/admin_catalog_screen.dart';
import 'package:zuno/features/auth/presentation/providers/auth_notifier.dart';
import 'package:zuno/features/auth/presentation/providers/auth_state.dart';

/// The app owner's home.
///
/// It was a placeholder until the catalogue needed somewhere to live. Kept deliberately plain:
/// one card per thing the app owner can actually do, rather than a dashboard of figures nobody
/// asked for.
class AdminDashboardShell extends ConsumerWidget {
  const AdminDashboardShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final authState = ref.watch(authProvider);
    final value = authState.value;
    final user = value is AuthAuthenticated ? value.user : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Super Admin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            user == null ? 'Welcome to Zuno' : 'Welcome, ${user.fullName}',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 18),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(
                  Icons.category_outlined,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              title: const Text('Catalogue'),
              subtitle: const Text(
                'The kinds of work the product offers — add, rename or hide them',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AdminCatalogScreen(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
