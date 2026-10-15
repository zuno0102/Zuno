import 'package:zuno/core/utils/formatting.dart';

/// One block of time a worker is spoken for.
///
/// Times only — the work is never named. A worker's diary spans every business they serve, so
/// naming a job would show one business another's customers; and the question this screen
/// answers is only "when is this person unavailable".
///
/// Nothing is merged: two jobs at the same hour are two entries, because that is what they are,
/// and collapsing them would hide the double-booking worth seeing.
class WorkerBusyPeriod {
  const WorkerBusyPeriod({required this.startsAt, required this.endsAt});

  final DateTime startsAt;

  /// When it ends. The server computes this — a booking has no stored duration.
  final DateTime endsAt;

  /// Midnight on the day it starts — the key a schedule groups by.
  DateTime get day => DateTime(startsAt.year, startsAt.month, startsAt.day);

  /// "09:00 – 11:00".
  String get timeRange => '${formatTime(startsAt)} – ${formatTime(endsAt)}';

  /// Whether it runs past midnight, so the schedule can say so rather than showing a range
  /// that appears to run backwards.
  bool get endsNextDay =>
      DateTime(endsAt.year, endsAt.month, endsAt.day).isAfter(day);
}
