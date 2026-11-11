import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/features/admin/presentation/screens/admin_catalog_screen.dart';
import 'package:zuno/features/auth/presentation/providers/auth_notifier.dart';
import 'package:zuno/features/auth/presentation/providers/auth_state.dart';
import 'package:zuno/features/marketplace/presentation/screens/admin_marketplace_categories_screen.dart';
import 'package:zuno/core/router/push_screen.dart';

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
              onTap: () => pushScreen(context, const AdminCatalogScreen()),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              key: const ValueKey('admin-marketplace-categories'),
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(
                  Icons.storefront_outlined,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              title: const Text('Marketplace categories'),
              subtitle: const Text(
                'What businesses can post — and the details each kind asks for',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () =>
                  pushScreen(context, const AdminMarketplaceCategoriesScreen()),
            ),
          ),
        ],
      ),
    );
  }
}
