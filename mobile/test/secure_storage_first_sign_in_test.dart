import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/core/storage/secure_storage_service.dart';

/// Saving the tokens after a first sign-in on the web.
///
/// The web storage encrypts with a key it creates on its first write. Two writes in flight at once,
/// in a browser that had never stored anything, each created a key of their own; the second replaced
/// the first, and the token written under the lost key could not be read back. Every request after
/// that first sign-in got 401, and the next reload signed the person out.
///
/// This storage behaves the same way, so the test fails if the writes ever overlap again.
class _FirstWriteMakesTheKey extends FlutterSecureStorage {
  _FirstWriteMakesTheKey();

  final Map<String, (int key, String value)> _saved = {};
  int? _key;
  int _keysMade = 0;
  int _inFlight = 0;
  bool overlapped = false;

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (++_inFlight > 1) overlapped = true;
    // Like the browser: look for the key, and make one if there is none — after an await, which is
    // where a second write gets in.
    final hadKey = _key != null;
    await Future<void>.delayed(Duration.zero);
    final usedKey = hadKey ? _key! : (_key = ++_keysMade);
    _saved[key] = (usedKey, value!);
    _inFlight--;
  }

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    final saved = _saved[key];
    if (saved == null) return null;
    // Encrypted under a key that has since been replaced: unreadable.
    return saved.$1 == _key ? saved.$2 : null;
  }
}

void main() {
  test(
    'a first sign-in in a fresh browser can read both tokens back',
    () async {
      final storage = _FirstWriteMakesTheKey();
      final service = SecureStorageService(storage: storage);

      await service.saveTokens(accessToken: 'access', refreshToken: 'refresh');

      expect(
        storage.overlapped,
        isFalse,
        reason: 'the two writes must not be in flight together',
      );
      expect(await service.getAccessToken(), 'access');
      expect(await service.getRefreshToken(), 'refresh');
    },
  );
}
