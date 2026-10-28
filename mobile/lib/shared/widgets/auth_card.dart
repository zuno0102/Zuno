import 'package:flutter/material.dart';
import 'package:zuno/core/theme/app_colors.dart';

/// Rounded card the auth forms sit inside, floating over [AuthBackdrop]'s circles.
class AuthCard extends StatelessWidget {
  const AuthCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
      decoration: BoxDecoration(
        // Follows the theme. Pinned to white, it fought everything inside it in dark mode.
        color: AppColors.authSurface(brightness),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowSoft.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}
