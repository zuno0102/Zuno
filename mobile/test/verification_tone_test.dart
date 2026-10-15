import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/shared/widgets/status_pill.dart';

/// What colour an identity check wears.
///
/// The two worker screens had drifted — one amber, one grey — so the same unverified worker read as
/// two different things on two pages. Grey was the wrong call anyway: ID Pending means somebody is
/// checking right now, which is a state in motion.
///
/// The rule that matters most is the last one. On a worker's green pages, a pending badge that
/// borrowed any green would read as approval at a glance.
void main() {
  test('a passed check is the only one that gets green', () {
    expect(verificationTone('Verified'), StatusTone.success);
  });

  test('a check still running is amber, not grey', () {
    expect(verificationTone('Pending'), StatusTone.progress);
  });

  test('a rejected check is red, because it has to be acted on', () {
    expect(verificationTone('Rejected'), StatusTone.danger);
  });

  test('an unknown state is treated as still running, never as passed', () {
    // A status the server adds later must not light up green by default.
    expect(verificationTone(''), StatusTone.progress);
    expect(verificationTone('UnderReview'), StatusTone.progress);
  });

  group('the pending colour is nothing like the verified one', () {
    for (final brightness in Brightness.values) {
      test('in ${brightness.name} mode', () {
        final pending = HSLColor.fromColor(
          AppColors.status(StatusTone.progress, brightness),
        );
        final verified = HSLColor.fromColor(
          AppColors.status(StatusTone.success, brightness),
        );

        // Amber sits near 35°, green near 140°. Anything close would defeat the point of the badge.
        expect((pending.hue - verified.hue).abs(), greaterThan(60));
        expect(pending.hue, lessThan(60), reason: 'pending should read as amber');
      });
    }
  });
}
