import 'dart:developer' as developer;

/// The app's one way to record something that went wrong but was handled.
///
/// CODING_STANDARDS section 8: a caught error is logged, never swallowed in silence; section 2:
/// `print` and `debugPrint` are not used. This writes through `dart:developer`, which shows in the
/// debugger and DevTools, costs nothing in a release build when nobody is listening, and never puts
/// anything on screen.
///
/// One place, so a crash-reporting service can be plugged in here later without touching callers.
class AppLog {
  const AppLog._();

  /// Name shown against every entry, so the app's own messages can be filtered from the rest.
  static const _name = 'zuno';

  /// A failure the code recovered from. [where] says which part of the app, e.g. "permissions".
  static void handled(String where, Object error, [StackTrace? stackTrace]) {
    developer.log(
      'Handled in $where: $error',
      name: _name,
      level: 900, // WARNING on the dart:developer / package:logging scale.
      error: error,
      stackTrace: stackTrace,
    );
  }
}
