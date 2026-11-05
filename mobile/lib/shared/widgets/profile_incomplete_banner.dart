import 'package:flutter/material.dart';

/// "Finish your profile: add your UPI ID" — shown until every required detail is filled in.
///
/// [missing] is the server's list (e.g. "UPI ID"), so a new required detail needs no app change.
/// [why] says what the business or worker cannot do until then; [onTap], when given, opens where
/// the details are filled in.
class ProfileIncompleteBanner extends StatelessWidget {
  const ProfileIncompleteBanner({
    required this.missing,
    required this.why,
    this.onTap,
    super.key,
  });

  final List<String> missing;
  final String why;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final danger = theme.colorScheme.error;

    return Material(
      key: const ValueKey('profile-incomplete'),
      color: danger.withValues(alpha: 0.09),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: danger.withValues(alpha: 0.32)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline, size: 19, color: danger),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Finish your profile: add your ${missing.join(', ')}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: danger,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      why,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: danger,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null) Icon(Icons.chevron_right, color: danger),
            ],
          ),
        ),
      ),
    );
  }
}
