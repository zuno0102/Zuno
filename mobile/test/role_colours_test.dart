import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/core/theme/app_theme.dart';

/// Each side of the marketplace gets its own colour so a glance at a screen says which app it is.
///
/// That only works if the colours can actually be told apart. Business, customer and admin were once
/// three shades of the same blue-violet, because Material's seeding pulls chroma in hard and the
/// seeds started close. The palette is now the region's own: backwater teal for the customer,
/// turmeric for the worker, kokum plum for the business, ink blue for admin. These tests are what
/// stop a future seed drifting back into a neighbour, or into the error red.
void main() {
  double hueOf(ZunoRole role, Brightness brightness) => HSLColor.fromColor(
    AppTheme.forRole(role, brightness).colorScheme.primary,
  ).hue;

  /// The shorter way round the wheel, so 350° and 10° read as 20° apart rather than 340°.
  double separation(double a, double b) {
    final gap = (a - b).abs() % 360;
    return gap > 180 ? 360 - gap : gap;
  }

  for (final brightness in Brightness.values) {
    group('in ${brightness.name} mode', () {
      test('no two roles share a hue', () {
        // Roughly the point where two colours stop reading as "the same blue" side by side. The old
        // customer blue sat nine degrees from admin and failed this outright.
        const minimumSeparation = 25.0;

        for (final a in ZunoRole.values) {
          for (final b in ZunoRole.values) {
            if (a == b) continue;
            final gap = separation(hueOf(a, brightness), hueOf(b, brightness));
            expect(
              gap,
              greaterThan(minimumSeparation),
              reason:
                  '${a.name} and ${b.name} are only ${gap.toStringAsFixed(0)}° apart',
            );
          }
        }
      });

      test('the customer is backwater teal', () {
        final customer = hueOf(ZunoRole.customer, brightness);
        expect(customer, greaterThan(160));
        expect(customer, lessThan(195));
      });

      test('and the business is well clear of it', () {
        expect(
          separation(
            hueOf(ZunoRole.customer, brightness),
            hueOf(ZunoRole.business, brightness),
          ),
          greaterThan(40),
        );
      });

      test('no role can be mistaken for the error red', () {
        // A brand colour sitting on the error red makes a danger badge stop reading as one. Hue
        // alone is not the test: two colours can share a hue and still be plainly different if one
        // is a dusty tone and the other a clear signal. So either must hold.
        final danger = AppColors.status(StatusTone.danger, brightness);
        final dangerHue = HSLColor.fromColor(danger).hue;
        final dangerSaturation = HSLColor.fromColor(danger).saturation;

        for (final role in ZunoRole.values) {
          final primary = AppTheme.forRole(
            role,
            brightness,
          ).colorScheme.primary;
          final hueApart = separation(
            HSLColor.fromColor(primary).hue,
            dangerHue,
          );
          final saturationApart =
              (HSLColor.fromColor(primary).saturation - dangerSaturation).abs();

          expect(
            hueApart > 25 || saturationApart > 0.2,
            isTrue,
            reason:
                '${role.name} in ${brightness.name} is ${hueApart.toStringAsFixed(0)}° from the '
                'error red and only ${saturationApart.toStringAsFixed(2)} apart in saturation',
          );
        }
      });

      test('the worker is turmeric', () {
        final worker = hueOf(ZunoRole.worker, brightness);
        expect(worker, greaterThan(25));
        expect(worker, lessThan(55));
      });

      test('writing on a role colour is legible', () {
        for (final role in ZunoRole.values) {
          final scheme = AppTheme.forRole(role, brightness).colorScheme;
          final gap =
              (scheme.primary.computeLuminance() -
                      scheme.onPrimary.computeLuminance())
                  .abs();
          // Messages, buttons and headers all put onPrimary on primary, so a seed that narrowed
          // this would make text on a role colour hard to read everywhere at once.
          expect(
            gap,
            greaterThan(0.4),
            reason: '${role.name} in ${brightness.name}',
          );
        }
      });
    });
  }
}
