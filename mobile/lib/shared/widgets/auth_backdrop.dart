import 'package:flutter/material.dart';
import 'package:zuno/core/theme/app_colors.dart';

/// Full-screen backdrop of overlapping decorative circles (top-right and bottom-left)
/// behind a centered scrollable card — the shared visual frame for auth screens.
class AuthBackdrop extends StatelessWidget {
  const AuthBackdrop({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Container(
      // Follows the theme, as does the pale circle below. The navy one is left alone: it reads
      // against both a light and a dark page, which is what made it the brand mark here.
      color: AppColors.authBackdrop(brightness),
      child: Stack(
        children: [
          Positioned(
            top: -90,
            right: -70,
            child: _Circle(
              diameter: 260,
              color: AppColors.circleFaint(brightness).withValues(alpha: 0.7),
            ),
          ),
          Positioned(
            top: -40,
            right: -100,
            child: _Circle(diameter: 200, color: AppColors.circleDark),
          ),
          Positioned(
            bottom: -80,
            left: -90,
            child: _Circle(diameter: 220, color: AppColors.circleDark),
          ),
          Positioned(
            bottom: -120,
            left: -60,
            child: _Circle(
              diameter: 260,
              color: AppColors.circleFaint(brightness).withValues(alpha: 0.7),
            ),
          ),
          SafeArea(child: child),
        ],
      ),
    );
  }
}

class _Circle extends StatelessWidget {
  const _Circle({required this.diameter, required this.color});

  final double diameter;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
