/// How the on-screen keyboard makes room for itself in the phone's browser, picked per platform at
/// compile time. Same pattern as `core/share/system_share.dart`.
///
/// Chrome on Android, left to itself, makes room by *sliding the page up* to show the focused field
/// — while Flutter, as asked, also lifts its content above the keyboard. Done together, the form
/// slides off the top and an empty strip shows between the field and the keyboard. Asking Chrome to
/// shrink the page instead (`interactive-widget=resizes-content`) leaves the lifting to Flutter alone.
/// The installed app has no browser, so there it does nothing.
library;

export 'package:zuno/core/web/keyboard_viewport_native.dart'
    if (dart.library.js_interop) 'package:zuno/core/web/keyboard_viewport_web.dart';
