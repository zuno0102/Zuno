import 'package:flutter/material.dart';

/// Which part of the marketplace someone is looking at.
///
/// Each side gets its own colour so a screenshot, a shared link or a glance at someone else's
/// phone is instantly placeable — and so a business owner never mistakes a worker screen for
/// their own. The shapes and spacing stay identical; only the hue moves.
enum ZunoRole { business, worker, customer, admin }

class AppColors {
  const AppColors._();

  // ---- Brand ---------------------------------------------------------------------------
  static const Color primary = Color(0xFF4B3FB8);
  static const Color primaryDark = Color(0xFF2E2578);
  static const Color secondary = Color(0xFFF2A93B);
  static const Color error = Color(0xFFB3261E);

  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF121212);
  static const Color backgroundLight = Color(0xFFF4F4F7);
  static const Color backgroundDark = Color(0xFF1A1A1A);

  /// Decorative backdrop circles used behind the auth screens.
  static const Color circleDark = Color(0xFF2E3568);
  static const Color circleLight = Color(0xFFD4D5E3);

  // ---- Surfaces ------------------------------------------------------------------------
  //
  // The page behind everything, and the inside of a text field. Both were written straight into
  // AppTheme, which made them the two colours in the app that no other file could reach: a sheet
  // wanting to sit flush with the page had to guess the hex, and a guess that drifts by one digit
  // shows up as a seam.

  static const Color scaffoldLight = Color(0xFFF5F5F9);
  static const Color scaffoldDark = Color(0xFF121218);

  static const Color fieldFillLight = Color(0xFFF2F2F6);
  static const Color fieldFillDark = Color(0xFF1D1D25);

  /// The page behind everything.
  static Color scaffold(Brightness brightness) =>
      brightness == Brightness.dark ? scaffoldDark : scaffoldLight;

  /// The inside of a text field.
  static Color fieldFill(Brightness brightness) =>
      brightness == Brightness.dark ? fieldFillDark : fieldFillLight;

  /// The card the sign-in and sign-up forms sit on.
  ///
  /// Brightness-aware for a reason worth remembering: this card used to be painted white
  /// whatever the theme, while everything inside it — field fills, hint text, the button —
  /// came from the theme. In dark mode that put near-black fields and pale text on a white
  /// card, and the labels could not be read at all.
  static Color authSurface(Brightness brightness) =>
      brightness == Brightness.dark ? surfaceDark : surfaceLight;

  /// The page behind that card.
  static Color authBackdrop(Brightness brightness) =>
      brightness == Brightness.dark ? backgroundDark : backgroundLight;

  /// The pale decorative circle on that page. The light one glares against a dark page, so
  /// dark mode gets its own barely-there tint instead.
  static const Color circleFaintDark = Color(0xFF262633);

  static Color circleFaint(Brightness brightness) =>
      brightness == Brightness.dark ? circleFaintDark : circleLight;

  // ---- Marks on top of other things ----------------------------------------------------

  /// A rating star.
  ///
  /// The amber was written out three times — twice as a hex and once as `Colors.amber`, which is a
  /// different colour — so the same star was two shades depending on which screen it sat on.
  static const Color ratingStar = secondary;

  /// A soft drop shadow for something floating over a map or a photograph.
  static const Color shadowSoft = Color(0x42000000);

  /// A stronger one, for text that has to stay legible over an image.
  static const Color shadowStrong = Color(0x61000000);

  /// A dark wash over a camera preview, so controls on top of it can be read.
  static const Color scrim = Color(0x8A000000);

  /// Secondary text on a photograph or a camera preview, where the surface is not the app's.
  static const Color onMediaMuted = Color(0xB3FFFFFF);

  /// The dark foot of the gradient laid over a banner photograph, so the caption on it can be read
  /// whatever the picture happens to be.
  static const Color mediaGradientFoot = Color(0xDD000000);

  // ---- Role identity -------------------------------------------------------------------

  /// Purple, and it moved to make room rather than for its own sake.
  ///
  /// It was a blue-violet, which is the same corner the customer indigo needed. Thirteen degrees
  /// apart, a business screen and a customer screen read as the same app — and telling them apart
  /// at a glance is the only reason these colours differ at all. Purple is the nearest hue that is
  /// clear of the indigo below it and of the admin magenta above.
  static const Color businessSeed = Color(0xFF7B1FA2);
  static const Color workerSeed = Color(0xFF0E8F5B);

  /// Indigo: what a marketplace wears when the customer is the one taking the risk.
  ///
  /// A customer is paying a stranger to come into their home, and the apps in that trade settle on
  /// the blue end for it. Teal was tried and read clinical; magenta was tried and read retail.
  ///
  /// Indigo is the most crowded corner of this wheel, and taking it moved two other roles. It lands
  /// at 233°, thirteen degrees from where the business violet used to sit — close enough that the
  /// two apps would have been hard to tell apart, which is the complaint this whole palette exists
  /// to answer. So business went to purple and admin to magenta, and the four are now 51° apart at
  /// the closest.
  static const Color customerSeed = Color(0xFF3949AB);

  /// Magenta, and it moved here rather than being chosen here.
  ///
  /// Admin was a third blue — nine degrees from the customer and thirty-two from the business — so
  /// the back office looked like both of the apps it administers. Material will not seed a neutral:
  /// every grey comes back as a blue-violet, which is the crowd admin was trying to leave. Magenta
  /// is free, and an internal tool is the right place to spend a hue nobody else wants.
  static const Color adminSeed = Color(0xFFC2185B);

  /// The role behind a signed-in account, from the name the server uses for it.
  ///
  /// Null for anyone not signed in, which is what keeps the login and register screens on the
  /// neutral brand colours rather than guessing at a role nobody has chosen yet.
  static ZunoRole? roleFromName(String? name) => switch (name) {
    'Customer' => ZunoRole.customer,
    'BusinessOwner' => ZunoRole.business,
    'Worker' => ZunoRole.worker,
    'SuperAdmin' => ZunoRole.admin,
    _ => null,
  };

  static Color seedFor(ZunoRole role) => switch (role) {
    ZunoRole.business => businessSeed,
    ZunoRole.worker => workerSeed,
    ZunoRole.customer => customerSeed,
    ZunoRole.admin => adminSeed,
  };

  /// The two stops of a role's header gradient, dark end first.
  static (Color, Color) gradientFor(ZunoRole role) => switch (role) {
    ZunoRole.business => (const Color(0xFF4A0D6B), const Color(0xFF9C27B0)),
    ZunoRole.worker => (const Color(0xFF066B43), const Color(0xFF17A96C)),
    // Following the seeds above. A gradient left behind is the one place an old colour survives,
    // on the widest block of colour a role has.
    ZunoRole.customer => (const Color(0xFF1A237E), const Color(0xFF5C6BC0)),
    ZunoRole.admin => (const Color(0xFF6E0B33), const Color(0xFFD81B60)),
  };

  // ---- Status --------------------------------------------------------------------------
  //
  // Semantic and brightness-aware. Status was previously reached for as Colors.green.shade700
  // and friends, which are mixed for a light surface and turn muddy on the dark scaffold.

  static const Color _successLight = Color(0xFF1B7F42);
  static const Color _successDark = Color(0xFF5FCB8B);

  static const Color _progressLight = Color(0xFF97590A);
  static const Color _progressDark = Color(0xFFE8B168);

  static const Color _waitingLight = Color(0xFF4A5570);
  static const Color _waitingDark = Color(0xFF9BA6C2);

  static const Color _dangerLight = Color(0xFFB3261E);
  static const Color _dangerDark = Color(0xFFF2938C);

  /// Resolves a status colour for the current theme.
  static Color status(StatusTone tone, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return switch (tone) {
      StatusTone.success => isDark ? _successDark : _successLight,
      StatusTone.progress => isDark ? _progressDark : _progressLight,
      StatusTone.waiting => isDark ? _waitingDark : _waitingLight,
      StatusTone.danger => isDark ? _dangerDark : _dangerLight,
    };
  }
}

/// What a piece of state means, independent of which colour says it.
enum StatusTone {
  /// Done, settled, confirmed.
  success,

  /// Under way, awaiting an answer, needs an action soon.
  progress,

  /// Not started, or nothing to do yet.
  waiting,

  /// Disputed, failed, or otherwise wrong.
  danger,
}
