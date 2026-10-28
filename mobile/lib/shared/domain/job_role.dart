/// What a crew member is on one particular job: Supervisor, Lead or Support.
///
/// Three fixed roles, not free text. "Painter" and "Chef" describe the trade somebody practises —
/// a fact about the person, the same on every job they take. These describe what they are doing on
/// **this order**, which is the only thing worth recording per job.
///
/// They apply to every category. Leading a painting job and leading a catering job are the same
/// job of leading; the work differs, the leading does not.
///
/// Mirrors `JobRole` on the server. Kept as plain strings rather than an enum because the value
/// travels as a string and old assignments still carry free text from before these three existed.
library;

import 'package:zuno/core/ui_config/ui_config.dart';
import 'package:zuno/core/utils/ui_lookup.dart';

class JobRole {
  const JobRole._();

  /// Watches how the work is going. Sees the job; changes nothing.
  static const String supervisor = 'Supervisor';

  /// Runs the work on the day — and the only role that can move its status.
  static const String lead = 'Lead';

  /// Fixes what the job needs around the work: food for the crew, a missing supply, a problem
  /// nobody else has time for.
  static const String support = 'Support';

  /// The three, in the order they are offered.
  static const List<String> all = [supervisor, lead, support];

  /// What each one is for, shown under its name so the choice is not a guess. From the `JobRole`
  /// labels' detail.
  static Map<String, String> get descriptions => {
    for (final role in all)
      role: ?UiConfig.current.own('JobRole', role)?.detail,
  };

  /// Whether holding this role lets somebody start and finish the job's work.
  ///
  /// Only Lead. The one line in the app that decides what a role grants — asked here rather than
  /// compared inline, so the screen that offers a button and the server that honours it can never
  /// disagree. Case-insensitive, and false for the legacy free-text roles, which is right: nobody
  /// who typed "Painter" meant "may close this job".
  static bool grantsWorkControl(String? role) =>
      role != null && role.trim().toLowerCase() == lead.toLowerCase();

  /// Whether this is one of the three.
  static bool isKnown(String? role) =>
      role != null &&
      all.any((r) => r.toLowerCase() == role.trim().toLowerCase());
}
