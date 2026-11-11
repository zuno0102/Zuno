import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/shared/legal/legal_document.dart';

import 'file_asset_bundle.dart';

/// Keeps the Privacy policy true to the app (PRIVACY_AND_LEGAL.md, CODING_STANDARDS.md §16).
///
/// When a change asks for a new phone permission or adds a package that sends data off the phone,
/// this fails until the policy explains it. Do not silence a failure here: update the policy, then
/// the table below.
void main() {
  final policy = File('assets/legal/privacy_policy.md').readAsStringSync();
  final fields = (jsonDecode(File(legalFieldsAsset).readAsStringSync()) as Map)
      .cast<String, Object?>();

  /// Each phone permission the app asks for, and what the policy must say about it. A permission
  /// not listed here fails: add it, and explain it in "From your phone".
  const permissions = <String, String>{
    // Android (AndroidManifest.xml)
    'android.permission.CAMERA': '**Camera and photos**',
    'android.permission.ACCESS_COARSE_LOCATION': '**Location**',
    'android.permission.ACCESS_FINE_LOCATION': '**Location**',
    'android.permission.POST_NOTIFICATIONS': '**Notifications**',
    // Asks for nothing personal.
    'android.permission.INTERNET': '',
    // iOS (Info.plist)
    'NSLocationWhenInUseUsageDescription': '**Location**',
    'NSCameraUsageDescription': '**Camera and photos**',
    'NSPhotoLibraryUsageDescription': '**Camera and photos**',
  };

  test('every phone permission the app asks for is explained', () {
    final asked = {
      ...RegExp(r'android:name="(android\.permission\.\w+)"')
          .allMatches(
            File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
          )
          .map((m) => m[1]!),
      ...RegExp(r'<key>(NS\w+UsageDescription)</key>')
          .allMatches(File('ios/Runner/Info.plist').readAsStringSync())
          .map((m) => m[1]!),
    };

    for (final permission in asked) {
      expect(
        permissions.containsKey(permission),
        isTrue,
        reason:
            '$permission is new. Explain it in privacy_policy.md › From your phone, '
            'then add it to the table in this test.',
      );
      expect(
        policy.contains(permissions[permission]!),
        isTrue,
        reason: 'privacy_policy.md must explain $permission',
      );
    }
  });

  /// Packages that send data off the phone or reach a person's data, and the words the policy must
  /// contain for each. A package matching a pattern here that the policy does not name fails.
  const watched = <String, String>{
    r'^razorpay': 'Razorpay',
    r'^flutter_map$': 'OpenStreetMap',
    r'^geolocator': '**Location**',
    r'^image_picker': '**Camera and photos**',
    r'^mobile_scanner': 'scan',
    r'^file_picker': '**Files**',
    r'^flutter_local_notifications': '**Notifications**',
    r'^flutter_secure_storage': 'secure storage',
    r'^shared_preferences': 'kept on your phone',
    r'^firebase_': 'Firebase',
    r'^google_sign_in': 'Google sign-in',
    r'^google_maps': 'Google Maps',
    r'^(sentry|crashlytics|bugsnag)': 'crash report',
    r'^(mixpanel|amplitude|appsflyer|adjust|segment|posthog|clevertap|moengage)':
        'analytics',
    r'^(facebook|flutter_facebook)': 'Meta',
    r'^(onesignal|pushwoosh)': 'push',
    r'^(twilio|msg91)': 'SMS',
    r'^(google_mobile_ads|unity_ads|applovin)': 'advertising',
  };

  test('every package that touches personal data is named in the policy', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final deps = RegExp(
      r'^dependencies:\n([\s\S]*?)^dev_dependencies:',
      multiLine: true,
    ).firstMatch(pubspec)![1]!;
    final packages = RegExp(
      r'^  ([a-z0-9_]+):',
      multiLine: true,
    ).allMatches(deps).map((m) => m[1]!);

    for (final package in packages) {
      for (final MapEntry(key: pattern, value: words) in watched.entries) {
        if (!RegExp(pattern).hasMatch(package)) continue;
        expect(
          policy.contains(words),
          isTrue,
          reason:
              '$package sends or reaches personal data. Say so in privacy_policy.md '
              '("$words"), and update the Data safety answers in PRIVACY_AND_LEGAL.md.',
        );
      }
    }
  });

  test('no advertising or analytics package, as the policy promises', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(policy, contains('we do not use advertising or analytics trackers'));
    for (final kind in [
      'google_mobile_ads',
      'firebase_analytics',
      'mixpanel',
    ]) {
      expect(
        pubspec.contains('  $kind:'),
        isFalse,
        reason: 'The policy says there are no trackers. Change it first.',
      );
    }
  });

  for (final doc in LegalDoc.values) {
    group(doc.title, () {
      final text = File(doc.asset).readAsStringSync();

      test('every {{field}} is in legal.json', () {
        for (final m in RegExp(r'\{\{(\w+)\}\}').allMatches(text)) {
          expect(fields.containsKey(m[1]), isTrue, reason: '{{${m[1]}}}');
        }
      });

      test('uses only the Markdown the app and website can draw', () {
        for (final line in const LineSplitter().convert(text)) {
          final t = line.trim();
          expect(
            RegExp(r'^(\* |\d+\. |\||>|```|!\[|\[)').hasMatch(t),
            isFalse,
            reason: 'Not supported: "$t". Use #, ##, ###, "- " and **bold**.',
          );
        }
      });

      test('the web page publishes this same file', () {
        final page = switch (doc) {
          LegalDoc.privacy => 'web/privacy.html',
          LegalDoc.terms => 'web/terms.html',
          LegalDoc.help => 'web/help.html',
        };
        expect(
          File(page).readAsStringSync(),
          contains('data-doc="${doc.asset.split('/').last}"'),
        );
      });
    });
  }

  group('fillLegalFields', () {
    test('fills a value, and marks a blank as to be added', () {
      expect(
        fillLegalFields('Write to {{email}} at {{address}}.', {
          'email': 'help@zuno.example',
          'address': ' ',
        }),
        'Write to help@zuno.example at $legalFieldMissing.',
      );
    });
  });

  group('parseLegalMarkdown', () {
    test('headings, paragraphs and bullets', () {
      final blocks = parseLegalMarkdown(
        '# Title\n\nOne line\nrunning on.\n\n## Part\n\n- first\n- **second** item\n\n### Small\n',
      );
      expect(blocks.map((b) => (b.runtimeType, b.text)).toList(), [
        (LegalHeading, 'Title'),
        (LegalParagraph, 'One line running on.'),
        (LegalHeading, 'Part'),
        (LegalBullet, 'first'),
        (LegalBullet, '**second** item'),
        (LegalHeading, 'Small'),
      ]);
      expect((blocks[2] as LegalHeading).level, 2);
      expect((blocks[5] as LegalHeading).level, 3);
    });

    test('bold is drawn bold', () {
      final spans = legalSpans('Plain **bold** plain');
      expect(spans.map((s) => s.text), ['Plain ', 'bold', ' plain']);
      expect(spans[1].style?.fontWeight, FontWeight.w700);
      expect(spans[0].style, isNull);
    });
  });

  for (final doc in LegalDoc.values) {
    testWidgets('${doc.title} opens and reads with the owner details filled', (
      tester,
    ) async {
      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: FileAssetBundle(),
          child: MaterialApp(home: LegalDocumentScreen(doc: doc)),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text(doc.title),
        ),
        findsOneWidget,
      );
      expect(find.byType(ListView), findsOneWidget);
      expect(find.textContaining('{{', findRichText: true), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
