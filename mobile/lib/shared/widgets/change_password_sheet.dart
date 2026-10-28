import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/features/auth/presentation/providers/auth_notifier.dart';
import 'package:zuno/features/auth/presentation/providers/auth_providers.dart';
import 'package:zuno/shared/widgets/app_messages.dart';

/// Lets somebody change their own password without signing out.
///
/// Shared rather than per-role: a customer, a worker and a business owner change a password the same
/// way, and the endpoint behind it does not care which they are.
///
/// The current password is required by the server, which is the point of it — a phone left unlocked
/// on a table should not be enough to lock its owner out of their own account.
Future<void> showChangePasswordSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _ChangePasswordSheet(),
    );

class _ChangePasswordSheet extends ConsumerStatefulWidget {
  const _ChangePasswordSheet();

  @override
  ConsumerState<_ChangePasswordSheet> createState() =>
      _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends ConsumerState<_ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();

  bool _isSaving = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });

    final messenger = AppMessenger.of(context);
    // Read before the sheet closes: its ref is gone once it is popped.
    final auth = ref.read(authProvider.notifier);

    try {
      await ref
          .read(authRepositoryProvider)
          .changePassword(
            currentPassword: _current.text,
            newPassword: _next.text,
          );

      if (!mounted) return;
      Navigator.of(context).pop();
      // The server ends every session when a password changes, so a stolen session cannot outlive
      // it. Sign out here at once rather than fail on the next token refresh.
      messenger.showSuccess(
        'Your password is changed. Sign in again with your new password.',
      );
      await auth.logout();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Change password',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _current,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Current password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      // One toggle for all three: somebody checking what they typed wants to see
                      // the lot, and three separate eyes is three taps for one question.
                      icon: Icon(
                        _obscure ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                      tooltip: _obscure ? 'Show passwords' : 'Hide passwords',
                    ),
                  ),
                  validator: (value) => (value ?? '').isEmpty
                      ? 'Enter your current password.'
                      : null,
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _next,
                  obscureText: _obscure,
                  decoration: const InputDecoration(
                    labelText: 'New password',
                    helperText:
                        'At least 8 characters, with a capital, a number and a symbol',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final password = value ?? '';
                    if (password.length < 8) {
                      return 'Use at least 8 characters.';
                    }
                    // Mirrors the server's rule so somebody is told here rather than after a round
                    // trip. The server remains the one that decides.
                    if (!RegExp(r'[A-Z]').hasMatch(password) ||
                        !RegExp(r'[a-z]').hasMatch(password) ||
                        !RegExp(r'\d').hasMatch(password) ||
                        !RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
                      return 'Include a capital, a lower case letter, a number and a symbol.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _confirm,
                  obscureText: _obscure,
                  decoration: const InputDecoration(
                    labelText: 'Confirm new password',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value == _next.text ? null : 'The two do not match.',
                ),

                if (_error case final message?) ...[
                  const SizedBox(height: 12),
                  Text(
                    message,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          )
                        : const Text('Change password'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
