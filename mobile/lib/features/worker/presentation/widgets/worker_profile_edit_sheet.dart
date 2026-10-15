import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/features/worker/domain/entities/worker_profile.dart';
import 'package:zuno/features/worker/presentation/providers/worker_dashboard_notifier.dart';
import 'package:zuno/shared/widgets/app_messages.dart';

/// Lets a worker change their own details.
///
/// Until this existed a worker could change nothing: their phone number and payout address were
/// written once at registration with no way back. The two costs were concrete — a worker who signed
/// up with an email only could never be phoned about a job, and one without a UPI address could
/// never be paid, with no way for either of them to put it right.
Future<bool> showWorkerProfileEditSheet(
  BuildContext context, {
  required WorkerProfile profile,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _WorkerProfileEditSheet(profile: profile),
  );

  return saved ?? false;
}

class _WorkerProfileEditSheet extends ConsumerStatefulWidget {
  const _WorkerProfileEditSheet({required this.profile});

  final WorkerProfile profile;

  @override
  ConsumerState<_WorkerProfileEditSheet> createState() =>
      _WorkerProfileEditSheetState();
}

class _WorkerProfileEditSheetState
    extends ConsumerState<_WorkerProfileEditSheet> {
  final _formKey = GlobalKey<FormState>();

  /// The profile carries one `fullName`, so the two halves are split on the first space.
  ///
  /// Imperfect for a three-part name, which is why the last-name box keeps everything after that
  /// space rather than only the next word — nothing is dropped, and whatever a worker types back is
  /// what gets saved.
  late final _firstName = TextEditingController(
    text: widget.profile.fullName.trim().split(' ').first,
  );
  late final _lastName = TextEditingController(
    text: widget.profile.fullName.trim().contains(' ')
        ? widget.profile.fullName.trim().split(' ').skip(1).join(' ')
        : '',
  );

  late final _phone = TextEditingController(
    text: widget.profile.phoneNumber ?? '',
  );
  late final _upi = TextEditingController(text: widget.profile.upiVpa ?? '');
  late final _rate = TextEditingController(
    text: widget.profile.hourlyRate?.toStringAsFixed(0) ?? '',
  );
  late final _experience = TextEditingController(
    text: widget.profile.experienceYears?.toString() ?? '',
  );

  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _upi.dispose();
    _rate.dispose();
    _experience.dispose();
    super.dispose();
  }

  /// Only what actually changed, so an untouched field stays untouched server-side.
  String? _changed(TextEditingController field, String? original) {
    final value = field.text.trim();
    if (value.isEmpty) return null;
    return value == (original ?? '') ? null : value;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // Compared against the halves the boxes were filled from, so re-saving a name that was only
    // split and rejoined does not count as a change.
    final currentFirst = _firstName.text.trim();
    final currentLast = _lastName.text.trim();
    final originalFull = widget.profile.fullName.trim();
    final nameChanged = '$currentFirst $currentLast'.trim() != originalFull;

    final firstName = nameChanged ? currentFirst : null;
    final lastName = nameChanged ? currentLast : null;

    final phone = _changed(_phone, widget.profile.phoneNumber);
    final upi = _changed(_upi, widget.profile.upiVpa);
    final rate = _changed(_rate, widget.profile.hourlyRate?.toStringAsFixed(0));
    final years = _changed(
      _experience,
      widget.profile.experienceYears?.toString(),
    );

    if (!nameChanged &&
        phone == null &&
        upi == null &&
        rate == null &&
        years == null) {
      Navigator.of(context).pop(false);
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    // Captured before the await: saving reloads the dashboard, and reading ref off a widget that
    // has been disposed in the meantime throws.
    final navigator = Navigator.of(context);
    final messenger = AppMessenger.of(context);
    final notifier = ref.read(workerDashboardProvider.notifier);

    try {
      await notifier.updateProfile(
        firstName: firstName,
        lastName: lastName,
        phoneNumber: phone,
        upiVpa: upi,
        hourlyRate: rate == null ? null : double.tryParse(rate),
        experienceYears: years == null ? null : int.tryParse(years),
      );
      navigator.pop(true);

      // Said here rather than by whoever opened the sheet. Two screens open it, neither said
      // anything, and a worker who changed the account their wages are paid into watched the sheet
      // close with no sign it had worked.
      messenger.showSuccess('Profile updated.');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        // The server's own words. It is the only thing that knows a number is already taken.
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        // Clears the keyboard, which otherwise covers the field being typed into.
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your details', style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Businesses use this to reach you, and to pay you.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),

              if (_error != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.onErrorContainer),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // The name goes first, because it is the thing a business reads before anything else
              // on a crew list — and the one detail that had no way back until now.
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
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
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
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
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Businesses see this on every job you apply for.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  prefixText: '+91 ',
                  border: OutlineInputBorder(),
                  helperText: 'How a business calls you about a job.',
                ),
                validator: (value) {
                  final v = value?.trim() ?? '';
                  if (v.isEmpty) return null;
                  // The same rule the server applies, so a typo is caught before a round trip.
                  return RegExp(r'^[6-9]\d{9}$').hasMatch(v)
                      ? null
                      : 'Enter a valid 10-digit mobile number.';
                },
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _upi,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'UPI address',
                  border: OutlineInputBorder(),
                  helperText: 'Where your wages are sent. Checked before the first payment.',
                ),
                validator: (value) {
                  final v = value?.trim() ?? '';
                  if (v.isEmpty) return null;
                  return RegExp(r'^[\w.\-]{2,}@[A-Za-z]{2,}$').hasMatch(v)
                      ? null
                      : 'A UPI address looks like name@bank.';
                },
              ),
              const SizedBox(height: 14),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _rate,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Hourly rate',
                        prefixText: '₹ ',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final v = value?.trim() ?? '';
                        if (v.isEmpty) return null;
                        final rate = int.tryParse(v);
                        return rate != null && rate > 0
                            ? null
                            : 'More than zero.';
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _experience,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(2),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Experience',
                        suffixText: 'yrs',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),

              if (_isSaving)
                const Center(child: CircularProgressIndicator())
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _save,
                        child: const Text('Save'),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
