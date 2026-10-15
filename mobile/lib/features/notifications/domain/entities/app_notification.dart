/// Where a notification leads when it is tapped.
///
/// A thing, not a route. The server names the thing — a booking, the Invitations tab — and the app
/// decides which screen that is, so renaming a screen cannot break notifications already sitting on
/// somebody's phone.
///
/// [unknown] is the whole reason this is an enum rather than a string: a server that grows a new
/// target must not crash an app that has not been updated. An unknown target falls back to opening
/// the dashboard.
enum NotificationTarget {
  home,
  booking,
  bookingRating,
  bookingChat,
  hiringPost,
  hiringPostApplicants,
  invitations,
  findWork,
  myJobs,
  payments,
  payouts,
  profile,
  unknown;

  /// Maps the server's name onto a target. Anything unrecognised becomes [unknown].
  static NotificationTarget fromName(String? name) => switch (name) {
    'Home' => home,
    'Booking' => booking,
    'BookingRating' => bookingRating,
    'BookingChat' => bookingChat,
    'HiringPost' => hiringPost,
    'HiringPostApplicants' => hiringPostApplicants,
    'Invitations' => invitations,
    'FindWork' => findWork,
    'MyJobs' => myJobs,
    'Payments' => payments,
    'Payouts' => payouts,
    'Profile' => profile,
    _ => unknown,
  };

  /// Whether this target needs an id to open anything.
  bool get needsId => switch (this) {
    booking || bookingRating || bookingChat => true,
    hiringPost || hiringPostApplicants || payouts => true,
    _ => false,
  };
}

/// Something that happened, told to one person.
///
/// The words come from the server already written, and are never recomposed here. A notification
/// saying "Boss T raised your wage to ₹1,100" has to keep saying that after the wage changes
/// again — it is a record of a moment, not a view over current state.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.target,
    required this.isUnread,
    required this.createdAt,
    this.targetId,
  });

  final String id;

  /// What it is about, as a name — `JobInvitation`, `WagePaid`.
  ///
  /// Used to pick the row's icon, never to decide where the row leads; that is [target]'s job.
  /// Kept as a string because an unrecognised kind should still show as a notification with a
  /// generic icon rather than be dropped.
  final String kind;

  final String title;

  /// The detail line. Empty where the title says everything.
  final String body;

  final NotificationTarget target;

  /// The thing [target] names, or null where the target needs no id.
  final String? targetId;

  final bool isUnread;
  final DateTime createdAt;

  /// Whether tapping this can actually land somewhere specific.
  ///
  /// A target that needs an id and has not got one is a server bug, and the row opens the
  /// dashboard rather than pushing a screen with a null id.
  bool get canOpen =>
      target != NotificationTarget.unknown &&
      (!target.needsId || (targetId != null && targetId!.isNotEmpty));

  AppNotification copyWith({bool? isUnread}) => AppNotification(
    id: id,
    kind: kind,
    title: title,
    body: body,
    target: target,
    targetId: targetId,
    isUnread: isUnread ?? this.isUnread,
    createdAt: createdAt,
  );
}
