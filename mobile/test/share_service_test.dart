import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/core/share/system_share.dart';
import 'package:zuno/features/customer/presentation/widgets/share_service.dart';

/// Sharing a service.
///
/// It used to copy a link and nothing else, so a customer who tapped Share expected WhatsApp and
/// got a "Link copied" toast. It now opens the device's share sheet and copies only where there is
/// no sheet to open.
void main() {
  // ---- shareService ---------------------------------------------------------------------------

  group('shareService', () {
    late List<String> copied;
    late List<Map<String, String?>> requests;

    setUp(() {
      copied = [];
      requests = [];
    });

    ShareLauncher fakeShare(ShareOutcome outcome) =>
        ({required String text, String? title, String? url}) async {
          requests.add({'text': text, 'title': title, 'url': url});
          return outcome;
        };

    Future<void> tapShare(WidgetTester tester, ShareLauncher share) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => shareService(
                  context,
                  name: 'Deep cleaning',
                  price: '₹1,200/day',
                  share: share,
                ),
                child: const Text('Share'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();
    }

    testWidgets('opens the share sheet with the service, and copies nothing', (
      tester,
    ) async {
      await tapShare(tester, fakeShare(ShareOutcome.shared));

      // Tests run outside a browser, so this is the app's case: name and price, no page link.
      expect(requests, [
        {
          'text': 'Deep cleaning — ₹1,200/day',
          'title': 'Deep cleaning',
          'url': null,
        },
      ]);
      expect(copied, isEmpty);
      expect(find.text('Details copied.'), findsNothing);
    });

    testWidgets('closing the sheet does nothing else', (tester) async {
      await tapShare(tester, fakeShare(ShareOutcome.dismissed));

      expect(requests, hasLength(1));
      expect(copied, isEmpty);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('with no share sheet, falls back to copying', (tester) async {
      await tapShare(tester, fakeShare(ShareOutcome.unavailable));

      expect(copied, ['Deep cleaning — ₹1,200/day']);
      expect(find.text('Details copied.'), findsOneWidget);
    });
  });

  // ---- SystemShare on Android -----------------------------------------------------------------

  group('SystemShare (Android)', () {
    const channel = MethodChannel('com.zuno.zuno/share');
    late List<MethodCall> calls;

    setUp(() => calls = []);

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    void answer(Future<Object?> Function(MethodCall call) handler) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) {
            calls.add(call);
            return handler(call);
          });
    }

    test('asks MainActivity for the chooser, link on its own line', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      answer((_) async => null);

      final outcome = await SystemShare.share(
        text: 'Deep cleaning — ₹1,200/day',
        title: 'Deep cleaning',
        url: 'https://example.test/s/1',
      );

      expect(outcome, ShareOutcome.shared);
      expect(calls.single.method, 'share');
      expect(calls.single.arguments, {
        'text': 'Deep cleaning — ₹1,200/day\nhttps://example.test/s/1',
        'title': 'Deep cleaning',
      });
    });

    test('without a link, sends the text alone', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      answer((_) async => null);

      await SystemShare.share(text: 'Deep cleaning — ₹1,200/day');

      expect(
        (calls.single.arguments as Map)['text'],
        'Deep cleaning — ₹1,200/day',
      );
    });

    test('a chooser that cannot open reports unavailable', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      answer((_) async => throw PlatformException(code: 'unavailable'));

      final outcome = await SystemShare.share(text: 'x');

      expect(outcome, ShareOutcome.unavailable);
    });

    test('an app built without the channel reports unavailable', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      final outcome = await SystemShare.share(text: 'x');

      expect(outcome, ShareOutcome.unavailable);
    });

    test('not Android: no channel call, unavailable', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      answer((_) async => null);

      final outcome = await SystemShare.share(text: 'x');

      expect(outcome, ShareOutcome.unavailable);
      expect(calls, isEmpty);
    });
  });
}
