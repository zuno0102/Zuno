@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/core/share/system_share.dart';

/// The website's share button, against a stubbed `navigator.share`.
///
/// Run with `flutter test --platform chrome test/web`. The plain `flutter test` run skips it.
void main() {
  final navigator = globalContext['navigator']! as JSObject;
  final original = navigator['share'];

  tearDown(() {
    if (original == null) {
      navigator.delete('share'.toJS);
    } else {
      navigator['share'] = original;
    }
  });

  /// Replaces navigator.share. [reject] names the DOMException to fail with, or null to succeed.
  List<JSObject> stubShare({String? reject}) {
    final received = <JSObject>[];
    navigator['share'] = ((JSObject data) {
      received.add(data);
      return reject == null
          ? Future<JSAny?>.value().toJS
          : Future<JSAny?>.error(_domException(reject)).toJS;
    }).toJS;
    return received;
  }

  test('opens the browser share sheet with the title, text and link', () async {
    final received = stubShare();

    final outcome = await SystemShare.share(
      title: 'Deep cleaning',
      text: 'Deep cleaning — ₹1,200/day',
      url: 'https://example.test/#/customer/service/1',
    );

    expect(outcome, ShareOutcome.shared);
    final data = received.single;
    expect((data['title'] as JSString).toDart, 'Deep cleaning');
    expect((data['text'] as JSString).toDart, 'Deep cleaning — ₹1,200/day');
    expect(
      (data['url'] as JSString).toDart,
      'https://example.test/#/customer/service/1',
    );
  });

  test('closing the sheet is dismissed, not a failure', () async {
    stubShare(reject: 'AbortError');

    expect(await SystemShare.share(text: 'x'), ShareOutcome.dismissed);
  });

  test('a blocked sheet is unavailable, so the caller copies', () async {
    stubShare(reject: 'NotAllowedError');

    expect(await SystemShare.share(text: 'x'), ShareOutcome.unavailable);
  });

  test('a browser without Web Share is unavailable', () async {
    navigator.delete('share'.toJS);

    expect(await SystemShare.share(text: 'x'), ShareOutcome.unavailable);
  });
}

@JS('DOMException')
extension type _DomException._(JSObject _) implements JSObject {
  external factory _DomException(String message, String name);
}

JSObject _domException(String name) => _DomException('stub', name);
