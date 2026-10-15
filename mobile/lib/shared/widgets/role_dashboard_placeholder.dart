import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/features/auth/presentation/providers/auth_notifier.dart';
import 'package:zuno/features/auth/presentation/providers/auth_state.dart';

/// Shared shell for a role's dashboard entry point. Each role feature (customer,
/// business_owner, worker, admin) wraps this with its own screen class so routing
/// and future role-specific content stay isolated per feature module.
class RoleDashboardPlaceholder extends ConsumerWidget {
  const RoleDashboardPlaceholder({required this.roleTitle, super.key});

  final String roleTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final value = authState.value;
    final user = value is AuthAuthenticated ? value.user : null;

    return Scaffold(
      appBar: AppBar(
        title: Text('$roleTitle Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: Center(
        child: Text(
          user == null ? 'Welcome to Zuno' : 'Welcome, ${user.fullName}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
    );
  }
}
