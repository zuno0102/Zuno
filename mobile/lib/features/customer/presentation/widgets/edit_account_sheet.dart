import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/features/auth/domain/entities/user.dart';
import 'package:zuno/features/auth/presentation/providers/auth_notifier.dart';

/// Lets somebody correct their own name and phone number.
///
/// Email is shown but not editable. It is the account's identity and half of how somebody signs in,
/// so changing it needs proof the new address is theirs — and offering a field that silently refuses
/// would be worse than not offering one.
Future<bool> showEditAccountSheet(
  BuildContext context, {
  required User user,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _EditAccountSheet(user: user),
  );

  return saved ?? false;
}

class _EditAccountSheet extends ConsumerStatefulWidget {
  const _EditAccountSheet({required this.user});

  final User user;

  @override
  ConsumerState<_EditAccountSheet> createState() => _EditAccountSheetState();
}

class _EditAccountSheetState extends ConsumerState<_EditAccountSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _firstName = TextEditingController(text: widget.user.firstName);
  late final _lastName = TextEditingController(text: widget.user.lastName);
  late final _phone = TextEditingController(
    text: widget.user.phoneNumber ?? '',
  );

  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    super.dispose();
  }

  /// Whether anything in the form actually differs from the account as it stands.
  bool get _hasChanges {
    final phone = _phone.text.trim();
    return _firstName.text.trim() != widget.user.firstName ||
        _lastName.text.trim() != widget.user.lastName ||
        phone != (widget.user.phoneNumber ?? '');
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Opened, read, closed with Save: nothing was changed, so nothing is claimed. Saying "Your
    // details are saved" over an untouched form tells somebody something happened when it did not,
    // and it is the one message they cannot check. The worker's own edit sheet has always stopped
    // here; this one did not, and sent a pointless write besides.
    if (!_hasChanges) {
      Navigator.of(context).pop(false);
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await ref
          .read(authProvider.notifier)
          .updateMyAccount(
            firstName: _firstName.text.trim(),
            lastName: _lastName.text.trim(),
            phoneNumber: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
          );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        // Shown in the sheet rather than a snackbar behind it: "that phone number is already in
        // use" is about the field they are looking at, and belongs next to it.
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
                  'Edit your details',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _firstName,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'First name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'Enter your first name.'
                      : null,
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _lastName,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Last name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'Enter your last name.'
                      : null,
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  // Digits only, so the ten-digit rule cannot be failed by a space somebody did not
                  // know they had typed.
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Mobile number',
                    helperText: 'How a business reaches you about a booking',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final phone = (value ?? '').trim();
                    if (phone.isEmpty) return null;
                    return RegExp(r'^[6-9]\d{9}$').hasMatch(phone)
                        ? null
                        : 'Enter a 10-digit mobile number.';
                  },
                ),

                if (widget.user.email case final email?) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: email,
                    enabled: false,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      helperText:
                          'You sign in with this, so it cannot be changed here',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],

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
                        : const Text('Save'),
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
