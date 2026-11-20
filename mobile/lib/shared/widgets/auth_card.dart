import 'package:flutter/material.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/core/theme/app_theme.dart';

/// The card the auth forms sit in, standing over [AuthBackdrop]'s band. Flat, with a hairline
/// edge: it is told from the page by colour, not by a shadow.
class AuthCard extends StatelessWidget {
  const AuthCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      decoration: BoxDecoration(
        // Follows the theme. Pinned to white, it fought everything inside it in dark mode.
        color: AppColors.authSurface(theme.brightness),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: child,
    );
  }
}
