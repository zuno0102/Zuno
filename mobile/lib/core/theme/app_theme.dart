import 'package:flutter/material.dart';
import 'package:zuno/core/theme/app_colors.dart';

/// Corner radii, one per level of nesting, so a thing inside another never has the same corners
/// as its container: small for chips and tags, medium for buttons and fields, large for cards,
/// extra large for sheets and dialogs.
class AppRadius {
  const AppRadius._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
}

/// The app's look, built once per role.
///
/// Flat and colour-blocked: surfaces are told apart by colour and a hairline edge, never by
/// shadow or gradient. One typeface, Figtree, bundled with the app — headings heavy and set a
/// little tight, body text plain, and every figure the same width so prices and counts line up.
///
/// Everything structural — card shape, chip density, field borders, spacing — is defined here
/// rather than repeated at each call site, so the role themes differ only by hue and a screen
/// written for one looks right in all of them.
class AppTheme {
  const AppTheme._();

  /// The bundled typeface (see `pubspec.yaml`).
  static const fontFamily = 'Figtree';

  /// Before anyone signs in (sign-in, sign-up, reset): the brand's own teal, matching the band
  /// across the top of those screens, rather than any one role's colour.
  static ThemeData light = _build(AppColors.primary, Brightness.light);
  static ThemeData dark = _build(AppColors.primary, Brightness.dark);

  static ThemeData forRole(ZunoRole role, Brightness brightness) =>
      _build(AppColors.seedFor(role), brightness);

  static ThemeData _build(Color seed, Brightness brightness) {
    // The default (tonal) variant, not "fidelity": fidelity makes the container colours as deep
    // as the seed, and chips, the navigation indicator and highlighted rows are written for a
    // pale container with dark text on it.
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: fontFamily,
    );
    final text = _textTheme(base.textTheme, scheme);

    // Cards, sheets, dialogs and bars: white on the off-white page, and a step lighter than the
    // page in dark mode (Lowest would sit darker than the page there).
    final raised = AppColors.raised(scheme, brightness);

    // A hairline that still shows on both grounds.
    final edge = BorderSide(color: scheme.outlineVariant);

    return base.copyWith(
      textTheme: text,
      scaffoldBackgroundColor: AppColors.scaffold(brightness),

      // Counts — unread messages, orders waiting — in the role's own colour, not Material's
      // default red. Red is what the app uses when something has gone wrong; a new message is not
      // a fault.
      badgeTheme: BadgeThemeData(
        backgroundColor: scheme.primary,
        textColor: scheme.onPrimary,
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.scaffold(brightness),
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(color: scheme.onSurface),
      ),

      // Flat: a list of shadowed cards reads as a pile of separate objects. A card is a white
      // block with a hairline edge on the page's off-white ground.
      cardTheme: CardThemeData(
        elevation: 0,
        color: raised,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: edge,
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          side: BorderSide(color: scheme.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: text.labelLarge,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        extendedTextStyle: text.labelLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),

      // Chosen segment in the role colour, the same one the buttons use: picking an option and
      // submitting the form are the same decision, so they match.
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? scheme.primary
                : Colors.transparent,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? scheme.onPrimary
                : scheme.onSurfaceVariant,
          ),
          side: WidgetStatePropertyAll(BorderSide(color: scheme.outline)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
          textStyle: WidgetStatePropertyAll(text.labelLarge),
        ),
      ),

      // A field shows its edge: a boundary the eye can find is part of being able to use it.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.fieldFill(brightness),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: edge,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: edge,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        labelStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        floatingLabelStyle: text.bodyMedium?.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        helperStyle: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        errorStyle: text.bodySmall?.copyWith(color: scheme.error),
      ),

      chipTheme: ChipThemeData(
        // Edged rather than bare, so a filter row reads as things to press; the chosen one takes
        // the role's container colour so it is obvious at a glance. Resolved per state, since one
        // BorderSide cannot serve both grounds.
        side: WidgetStateBorderSide.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? BorderSide(color: scheme.primary)
              : edge,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        backgroundColor: raised,
        // The colour has to be named here. A labelStyle given without one replaces the style the
        // chip would otherwise have resolved, colour included, and the label comes out with no
        // colour at all — white text on a white chip.
        labelStyle: text.labelMedium?.copyWith(color: scheme.onSurface),
        // The chosen chip sits on primaryContainer, a different ground, so it needs its own
        // readable pairing rather than inheriting the one above.
        secondaryLabelStyle: text.labelMedium?.copyWith(
          color: scheme.onPrimaryContainer,
        ),
        selectedColor: scheme.primaryContainer,
        checkmarkColor: scheme.onPrimaryContainer,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),

      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        elevation: 0,
        backgroundColor: raised,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelSmall?.copyWith(
            color: states.contains(WidgetState.selected)
                ? scheme.onSurface
                : scheme.onSurfaceVariant,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
          ),
        ),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: scheme.onSurface,
        unselectedLabelColor: scheme.onSurfaceVariant,
        labelStyle: text.titleSmall,
        unselectedLabelStyle: text.titleSmall?.copyWith(
          fontWeight: FontWeight.w500,
        ),
        indicatorColor: scheme.primary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: scheme.outlineVariant,
      ),

      listTileTheme: ListTileThemeData(
        titleTextStyle: text.titleSmall?.copyWith(color: scheme.onSurface),
        subtitleTextStyle: text.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        iconColor: scheme.onSurfaceVariant,
        minVerticalPadding: 10,
      ),

      dialogTheme: DialogThemeData(
        elevation: 0,
        backgroundColor: raised,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        titleTextStyle: text.titleLarge?.copyWith(color: scheme.onSurface),
        contentTextStyle: text.bodyMedium?.copyWith(color: scheme.onSurface),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        contentTextStyle: text.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
      ),

      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),

      bottomSheetTheme: BottomSheetThemeData(
        showDragHandle: true,
        elevation: 0,
        backgroundColor: raised,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.primaryContainer,
      ),
    );
  }

  /// The type scale. Headings heavy and set slightly tight; body text at a reading size with
  /// room between lines; labels in sentence case, never tracked capitals. Every figure is tabular,
  /// so ₹1,200 above ₹800 lines up digit for digit.
  static TextTheme _textTheme(TextTheme base, ColorScheme scheme) {
    const figures = [FontFeature.tabularFigures()];
    TextStyle? style(
      TextStyle? from, {
      required double size,
      required FontWeight weight,
      double height = 1.3,
      double tracking = 0,
    }) => from?.copyWith(
      fontFamily: fontFamily,
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: tracking,
      fontFeatures: figures,
    );

    return base
        .copyWith(
          displayLarge: style(
            base.displayLarge,
            size: 48,
            weight: FontWeight.w800,
            height: 1.1,
            tracking: -1.2,
          ),
          displayMedium: style(
            base.displayMedium,
            size: 40,
            weight: FontWeight.w800,
            height: 1.1,
            tracking: -1,
          ),
          displaySmall: style(
            base.displaySmall,
            size: 32,
            weight: FontWeight.w800,
            height: 1.15,
            tracking: -0.8,
          ),
          headlineLarge: style(
            base.headlineLarge,
            size: 28,
            weight: FontWeight.w800,
            height: 1.2,
            tracking: -0.6,
          ),
          headlineMedium: style(
            base.headlineMedium,
            size: 24,
            weight: FontWeight.w800,
            height: 1.2,
            tracking: -0.5,
          ),
          headlineSmall: style(
            base.headlineSmall,
            size: 21,
            weight: FontWeight.w700,
            height: 1.25,
            tracking: -0.3,
          ),
          titleLarge: style(
            base.titleLarge,
            size: 19,
            weight: FontWeight.w700,
            height: 1.3,
            tracking: -0.2,
          ),
          titleMedium: style(
            base.titleMedium,
            size: 16,
            weight: FontWeight.w700,
            height: 1.35,
          ),
          titleSmall: style(
            base.titleSmall,
            size: 14.5,
            weight: FontWeight.w700,
            height: 1.35,
          ),
          bodyLarge: style(
            base.bodyLarge,
            size: 16,
            weight: FontWeight.w400,
            height: 1.5,
          ),
          bodyMedium: style(
            base.bodyMedium,
            size: 14.5,
            weight: FontWeight.w400,
            height: 1.45,
          ),
          bodySmall: style(
            base.bodySmall,
            size: 12.5,
            weight: FontWeight.w500,
            height: 1.4,
          ),
          labelLarge: style(
            base.labelLarge,
            size: 15,
            weight: FontWeight.w700,
            height: 1.2,
          ),
          labelMedium: style(
            base.labelMedium,
            size: 13,
            weight: FontWeight.w600,
            height: 1.25,
          ),
          labelSmall: style(
            base.labelSmall,
            size: 12,
            weight: FontWeight.w600,
            height: 1.25,
          ),
        )
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
  }
}
