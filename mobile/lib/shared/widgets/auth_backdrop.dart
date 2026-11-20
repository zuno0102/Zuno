import 'package:flutter/material.dart';
import 'package:zuno/core/theme/app_colors.dart';

/// The frame of the sign-in, sign-up and reset screens: a band of the brand's deep teal across
/// the top with the Zuno name and what it is for, and the form's card standing over the band's
/// lower edge.
///
/// Flat colour blocking rather than decoration: the band is the brand, and the card overlapping
/// it is what makes the form the one thing on the screen.
class AuthBackdrop extends StatelessWidget {
  const AuthBackdrop({required this.child, super.key});

  /// The form's card, usually centred and scrollable; it is laid out below the brand line.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ColoredBox(
      color: AppColors.authBackdrop(theme.brightness),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            // Down past the brand line and into the card, so the card always stands across its
            // edge.
            height: MediaQuery.sizeOf(context).height * 0.42,
            child: ColoredBox(color: AppColors.circleDark),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: SizedBox(
                      width: double.infinity,
                      child: Column(
                        key: const ValueKey('auth-brand'),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Zuno',
                            style: theme.textTheme.displaySmall?.copyWith(
                              color: AppColors.onMedia,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Book local services, rent for your event and '
                            'shop from businesses near you.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.onMediaMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
