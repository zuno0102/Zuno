import 'package:flutter/material.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/core/theme/app_theme.dart';
import 'package:zuno/features/auth/domain/entities/user.dart';
import 'package:zuno/shared/widgets/profile_avatar.dart';

/// The top of a customer's home on every side (Service, Rent, Marketplace): who is signed in and
/// where they are looking, on the customer's deep teal.
///
/// It carries on the colour of the Service | Rent | Marketplace band above it, so the switch, the
/// greeting and the place read as one header, and ends in rounded corners so the search field and
/// the pictures below sit plainly on the page.
class CustomerHomeHeader extends StatelessWidget {
  const CustomerHomeHeader({
    required this.user,
    this.location,
    this.trailing,
    super.key,
  });

  final User? user;

  /// Where results are drawn from. Null until the customer picks somewhere.
  final String? location;

  /// Sits at the end of the strip — the notification bell, drawn in the header's white.
  ///
  /// Passed in rather than built here: the bell needs to know where each notification leads, and
  /// that is the shell's knowledge, not this header's.
  final Widget? trailing;

  /// "Good morning" and so on, by the phone's clock.
  static String greetingFor(DateTime now) => switch (now.hour) {
    < 12 => 'Good morning',
    < 17 => 'Good afternoon',
    _ => 'Good evening',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (deep, _) = AppColors.gradientFor(ZunoRole.customer);
    final muted = AppColors.onMediaMuted;
    final name = user == null
        ? 'Welcome'
        : '${user!.firstName} ${user!.lastName}'.trim();

    return DecoratedBox(
      key: const ValueKey('customer-home-header'),
      decoration: BoxDecoration(
        color: deep,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(AppRadius.xl),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          MediaQuery.of(context).padding.top + 6,
          8,
          20,
        ),
        child: Row(
          children: [
            ProfileAvatar(user: user, radius: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    greetingFor(DateTime.now()),
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: AppColors.onMedia,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // The place, as a quiet pill: it is what every list below is narrowed to.
                  Container(
                    padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
                    decoration: BoxDecoration(
                      color: AppColors.onMedia.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ExcludeSemantics(
                          child: Icon(
                            Icons.place_rounded,
                            size: 14,
                            color: AppColors.onMedia,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            location ?? 'Everywhere',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: AppColors.onMedia,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}
