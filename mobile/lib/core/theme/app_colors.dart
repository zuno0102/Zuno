import 'package:flutter/material.dart';
import 'package:zuno/core/ui_config/ui_config.dart';

/// Which part of the marketplace someone is looking at.
///
/// Each side gets its own colour so a screenshot, a shared link or a glance at someone else's
/// phone is instantly placeable — and so a business owner never mistakes a worker screen for
/// their own. The shapes and spacing stay identical; only the hue moves.
enum ZunoRole { business, worker, customer, admin }

/// Every colour the app paints with, by what it is for.
///
/// None is written here: each reads the server's `theme_colors` table through [UiConfig.current],
/// which until the server is reached holds the copy bundled in `assets/ui_config/colors.json`. So
/// changing a colour is a change to a table row, not a release. Widgets should still prefer the
/// theme's `ColorScheme` (built from the role seed below) and reach here only for what a scheme has
/// no slot for.
class AppColors {
  const AppColors._();

  static Color _light(String key) =>
      UiConfig.current.color(key, Brightness.light);

  static Color _for(String key, Brightness brightness) =>
      UiConfig.current.color(key, brightness);

  // ---- Brand ---------------------------------------------------------------------------
  static Color get primary => _light('brand.primary');
  static Color get primaryDark => _light('brand.primaryDark');
  static Color get secondary => _light('brand.secondary');
  static Color get error => _light('brand.error');

  // ---- Surfaces ------------------------------------------------------------------------

  /// The page behind everything.
  static Color scaffold(Brightness brightness) =>
      _for('surface.scaffold', brightness);

  /// The inside of a text field.
  static Color fieldFill(Brightness brightness) =>
      _for('surface.fieldFill', brightness);

  /// The card the sign-in and sign-up forms sit on. Brightness-aware: a white card in dark mode
  /// put near-black fields and pale text on white, and the labels could not be read.
  static Color authSurface(Brightness brightness) =>
      _for('surface.auth', brightness);

  /// The page behind that card.
  static Color authBackdrop(Brightness brightness) =>
      _for('surface.authBackdrop', brightness);

  /// The deep decorative circle behind the auth screens.
  static Color get circleDark => _light('decor.circle');

  /// The pale decorative circle on that page; dark mode gets its own barely-there tint.
  static Color circleFaint(Brightness brightness) =>
      _for('decor.circleFaint', brightness);

  // ---- Marks on top of other things ----------------------------------------------------

  /// A rating star — one shade wherever it sits.
  static Color get ratingStar => _light('mark.ratingStar');

  /// The white a QR code is printed on, in light and dark mode alike: a scanner reads dark modules
  /// on light, and a dark-mode surface behind one makes it unreadable.
  static Color get qrBackdrop => _light('mark.qrBackdrop');

  /// A soft drop shadow for something floating over a map or a photograph.
  static Color get shadowSoft => _light('mark.shadowSoft');

  /// A stronger one, for text that has to stay legible over an image.
  static Color get shadowStrong => _light('mark.shadowStrong');

  /// The solid backdrop behind a photograph being edited or viewed full screen.
  static Color get mediaBackdrop => _light('media.backdrop');

  /// A dark wash over a camera preview, so controls on top of it can be read.
  static Color get scrim => _light('media.scrim');

  /// Text and icons on a photograph, a video or a camera preview, where the surface is not the
  /// app's and the theme's on-colours do not apply.
  static Color get onMedia => _light('media.onMedia');

  /// Secondary text in the same place.
  static Color get onMediaMuted => _light('media.onMediaMuted');

  /// The dark foot of the gradient laid over a banner photograph, so the caption on it can be read
  /// whatever the picture happens to be.
  static Color get mediaGradientFoot => _light('media.gradientFoot');

  // ---- Role identity -------------------------------------------------------------------

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

  /// The colour a role's whole theme is grown from.
  static Color seedFor(ZunoRole role) => _light('role.${role.name}.seed');

  /// The two stops of a role's header gradient, dark end first.
  static (Color, Color) gradientFor(ZunoRole role) => (
    _light('role.${role.name}.gradientStart'),
    _light('role.${role.name}.gradientEnd'),
  );

  // ---- Status --------------------------------------------------------------------------

  /// A status colour for the current theme — mixed separately for light and dark, since a shade
  /// mixed for a light surface turns muddy on the dark scaffold.
  static Color status(StatusTone tone, Brightness brightness) =>
      _for('status.${tone.name}', brightness);
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
