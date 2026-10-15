/// How far one strand of a job has got.
///
/// A job runs several of these at once — the event, the work, the wages — and they move
/// independently but in order: each one opens when the one before it advances. Keeping them
/// apart is the whole point. "In progress" meant either that the day had arrived or that the
/// crew was on site; "completed" meant either that the work was done or that everyone had been
/// paid, and a business could not tell which.
///
/// Shared rather than owned by one feature: an order and a hiring post are the same idea of
/// progress seen from two sides, and two copies of this would drift.
enum TrackState {
  /// Nothing to do here yet; the track has not opened.
  notStarted,

  /// Open and waiting on someone.
  active,

  /// Under way.
  inProgress,

  /// Done.
  completed,

  /// The moment passed without it happening — an event whose date went by with nobody hired.
  /// Distinct from [completed] on purpose: a job nobody worked has not been completed, and
  /// calling it that would credit a business for an event that never ran.
  lapsed,
}
