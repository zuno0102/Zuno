import 'package:flutter/material.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/core/theme/app_theme.dart';

/// Applies a role's colours to everything beneath it.
///
/// Scoped here rather than on `MaterialApp` so signing in does not restyle the whole app, and
/// so the auth screens keep the neutral brand theme while each dashboard takes its own.
class RoleTheme extends StatelessWidget {
  const RoleTheme({required this.role, required this.child, super.key});

  final ZunoRole role;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.forRole(role, Theme.of(context).brightness),
      child: child,
    );
  }
}
