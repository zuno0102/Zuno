import 'package:flutter/material.dart';

/// A filled button's look while it is busy (saving, signing in): switched off so it cannot be
/// tapped twice, but still in its own colour.
///
/// A switched-off button normally turns grey, and in dark mode that grey is near the background
/// while the spinner — drawn in the button's text colour — is dark too: the button and its spinner
/// both vanished. Kept in the primary colour, the spinner in [ColorScheme.onPrimary] shows in light
/// and dark alike.
ButtonStyle busyFilledButtonStyle(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  return FilledButton.styleFrom(
    disabledBackgroundColor: scheme.primary,
    disabledForegroundColor: scheme.onPrimary,
  );
}

/// The spinner a busy filled button shows, in the colour that reads on [busyFilledButtonStyle].
class ButtonSpinner extends StatelessWidget {
  const ButtonSpinner({this.size = 20, super.key});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CircularProgressIndicator(
      strokeWidth: 2,
      color: Theme.of(context).colorScheme.onPrimary,
    ),
  );
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final shape = FilledButton.styleFrom(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
      textStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
      ),
    );
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: FilledButton(
        key: const ValueKey('primary-button'),
        style: isLoading ? shape.merge(busyFilledButtonStyle(context)) : shape,
        onPressed: isLoading ? null : onPressed,
        child: isLoading ? const ButtonSpinner() : Text(label.toUpperCase()),
      ),
    );
  }
}
