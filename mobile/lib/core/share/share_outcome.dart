/// What happened when the system share sheet was asked for.
enum ShareOutcome {
  /// The sheet opened. On the web this also means the person picked an app to share to.
  shared,

  /// The person closed the sheet without sharing. Nothing else should happen.
  dismissed,

  /// This platform or browser has no share sheet. The caller falls back to copying.
  unavailable,
}
