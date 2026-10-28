import 'package:flutter/material.dart';
import 'package:zuno/core/theme/app_colors.dart';

/// A compact, rounded inline message — used both for the brief success confirmation
/// shown inside the form sheet itself (rather than a SnackBar on the underlying screen,
/// so feedback stays scoped to the component the user is looking at) and for validation
/// errors, so both share the same visual language instead of two different banner styles.
///
/// Shared by the service and service-item forms, which had identical copies of it.
class ServiceFormMessageBanner extends StatelessWidget {
  const ServiceFormMessageBanner({
    required this.message,
    required this.color,
    required this.onColor,
    required this.icon,
    super.key,
  });

  final String message;
  final Color color;

  /// The text and icon on [color].
  final Color onColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowSoft.withValues(alpha: 0.15),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: onColor, size: 14),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                message,
                style: TextStyle(
                  color: onColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
