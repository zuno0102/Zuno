import 'package:flutter/material.dart';
import 'package:zuno/core/theme/app_colors.dart';

/// The frame of the sign-in, sign-up and reset screens: a band of the brand's deep teal across
/// the top of the page, with the form's card standing over its lower edge.
///
/// Flat colour blocking rather than decoration: the band is the brand, and the card overlapping it
/// is what makes the form the one thing on the screen.
class AuthBackdrop extends StatelessWidget {
  const AuthBackdrop({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return ColoredBox(
      color: AppColors.authBackdrop(brightness),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            // Down past the middle of the page, so the centred card always stands across its edge.
            height: MediaQuery.sizeOf(context).height * 0.42,
            child: ColoredBox(color: AppColors.circleDark),
          ),
          SafeArea(child: child),
        ],
      ),
    );
  }
}
