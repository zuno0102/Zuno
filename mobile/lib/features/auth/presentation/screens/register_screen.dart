import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zuno/core/constants/app_constants.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/core/utils/validators.dart';
import 'package:zuno/features/auth/presentation/providers/auth_notifier.dart';
import 'package:zuno/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:zuno/shared/widgets/auth_backdrop.dart';
import 'package:zuno/shared/widgets/auth_card.dart';
import 'package:zuno/shared/widgets/error_banner.dart';
import 'package:zuno/shared/widgets/primary_button.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  String _role = AppConstants.selfRegistrableRoles.first;

  static const _roleLabels = {
    'Customer': 'Customer',
    'BusinessOwner': 'Business',
    'Worker': 'Worker',
  };

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_emailController.text.trim().isEmpty &&
        _phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Provide either an email or a phone number.'),
        ),
      );
      return;
    }

    await ref
        .read(authProvider.notifier)
        .register(
          email: _emailController.text.trim().isEmpty
              ? null
              : _emailController.text.trim(),
          phoneNumber: _phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim(),
          password: _passwordController.text,
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          role: _role,
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.isLoading;
    final errorMessage = authState.hasError ? authState.error.toString() : null;
    final theme = Theme.of(context);

    return Scaffold(
      body: AuthBackdrop(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AuthCard(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => context.pop(),
                            icon: const Icon(Icons.arrow_back, size: 20),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'SIGN UP',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      if (errorMessage != null) ...[
                        ErrorBanner(message: errorMessage),
                        const SizedBox(height: 16),
                      ],
                      Text('I am a...', style: theme.textTheme.labelMedium),
                      const SizedBox(height: 8),
                      SegmentedButton<String>(
                        segments: AppConstants.selfRegistrableRoles
                            .map(
                              (role) => ButtonSegment(
                                value: role,
                                label: Text(_roleLabels[role] ?? role),
                              ),
                            )
                            .toList(),
                        selected: {_role},
                        onSelectionChanged: (selection) =>
                            setState(() => _role = selection.first),
                        style: ButtonStyle(
                          visualDensity: VisualDensity.compact,
                          shape: WidgetStatePropertyAll(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: AuthTextField(
                              hint: 'First name',
                              controller: _firstNameController,
                              prefixIcon: Icons.person_outline,
                              textInputAction: TextInputAction.next,
                              validator: (v) =>
                                  Validators.name(v, fieldLabel: 'First name'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: AuthTextField(
                              hint: 'Last name',
                              controller: _lastNameController,
                              textInputAction: TextInputAction.next,
                              validator: (v) =>
                                  Validators.name(v, fieldLabel: 'Last name'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      AuthTextField(
                        hint: 'Mail id',
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        prefixIcon: Icons.mail_outline,
                        validator: (v) => (v == null || v.isEmpty)
                            ? null
                            : Validators.email(v),
                      ),
                      const SizedBox(height: 12),
                      AuthTextField(
                        hint: 'Mobile number',
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        prefixIcon: Icons.phone_outlined,
                        validator: Validators.indianMobile,
                      ),
                      const SizedBox(height: 12),
                      AuthTextField(
                        hint: 'Password',
                        controller: _passwordController,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        prefixIcon: Icons.lock_outline,
                        validator: Validators.password,
                      ),
                      const SizedBox(height: 22),
                      PrimaryButton(
                        label: 'Sign up',
                        onPressed: _submit,
                        isLoading: isLoading,
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          children: [
                            Text(
                              'Already have an account? ',
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => context.pop(),
                              child: const Text(
                                'SIGN IN',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
