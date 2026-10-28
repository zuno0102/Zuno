import 'package:zuno/core/ui_config/ui_config.dart';
import 'package:zuno/core/utils/formatting.dart';
import 'package:zuno/features/vacancy/domain/entities/vacancy.dart';
import 'package:zuno/shared/widgets/status_pill.dart';

const _payPeriodGroup = 'VacancyPayPeriod';
const _fieldKindGroup = 'VacancyFieldKind';
const _workerGroup = 'VacancyApplication.Worker';
const _businessGroup = 'VacancyApplication.Business';

/// "/ month", "/ week", "/ day".
String payPeriodSuffix(String payPeriod) =>
    UiConfig.current.entry(_payPeriodGroup, payPeriod).shortLabel;

/// "Per month" — for the form's dropdown.
String payPeriodWords(String payPeriod) =>
    UiConfig.current.label(_payPeriodGroup, payPeriod);

/// The pay periods in the order the form offers them.
List<String> get payPeriodOptions =>
    _inTableOrder(VacancyPayPeriod.all, _payPeriodGroup);

/// What a custom field's answer type is called on the form.
String fieldKindLabel(String kind) =>
    UiConfig.current.label(_fieldKindGroup, kind);

/// The answer types in the order the form offers them.
List<String> get fieldKindOptions =>
    _inTableOrder(VacancyRequirementKind.all, _fieldKindGroup);

/// The codes this app can send, ordered as the table lists them. Only the app's own codes, so a
/// code added to the table before the app can handle it never reaches a form; one the table lacks
/// goes last rather than vanishing.
List<String> _inTableOrder(List<String> known, String group) {
  final order = UiConfig.current.codes(group);
  int rank(String code) {
    final i = order.indexOf(code);
    return i < 0 ? order.length : i;
  }

  return [...known]..sort((a, b) => rank(a).compareTo(rank(b)));
}

/// "₹15,000 – ₹20,000 / month", or a single figure when there is no range.
String vacancySalaryLabel(Vacancy v) {
  final range = v.salaryMax != null && v.salaryMax! > v.salaryMin
      ? '${rupees(v.salaryMin)} – ${rupees(v.salaryMax!)}'
      : rupees(v.salaryMin);
  return '$range ${payPeriodSuffix(v.payPeriod)}';
}

/// "09:30" from the server's "09:30:00".
String? shiftTimeLabel(String? time) {
  if (time == null || time.length < 5) return null;
  return time.substring(0, 5);
}

/// "6 days a week · 09:30–18:00 · 3 months".
String vacancyScheduleLabel(Vacancy v) {
  final start = shiftTimeLabel(v.shiftStart);
  final end = shiftTimeLabel(v.shiftEnd);
  final months = v.contractMonths;
  return [
    '${v.workingDaysPerWeek} ${v.workingDaysPerWeek == 1 ? 'day' : 'days'} a week',
    if (start != null && end != null) '$start–$end',
    if (months != null) '$months ${months == 1 ? 'month' : 'months'}',
  ].join(' · ');
}

/// The vacancy's state as the business sees it.
StatusPill vacancyStatusPill(Vacancy v, {bool compact = false}) {
  final code = switch (v) {
    _ when v.status == VacancyStatus.awaitingPayment => 'NotPosted',
    _ when v.needsPayment => 'Expired',
    _ when v.isStopped => 'Stopped',
    _ => 'Live',
  };
  final entry = UiConfig.current.entry('VacancyPost', code);
  return StatusPill(
    label: entry.label,
    tone: entry.statusTone,
    icon: entry.iconData,
    compact: compact,
    detail: v.isLive && v.expiresAt != null
        ? 'until ${formatDayMonth(v.expiresAt!)}'
        : null,
  );
}

/// An application's stage as the worker reads it — "Application sent", "Application viewed" …
String applicationStatusLabel(String status) =>
    UiConfig.current.label(_workerGroup, status);

/// The same stage as the business's list it sits in — New, Waiting, Shortlisted, Hired.
String businessListLabel(String status) =>
    UiConfig.current.label(_businessGroup, status);

/// What an empty business list says, so each one explains how people arrive in it.
String businessListEmptyMessage(String status) =>
    UiConfig.current.entry(_businessGroup, status).detail ?? '';

/// The worker's view of their application's stage.
StatusPill applicationStatusPill(String status, {bool compact = false}) =>
    _pill(UiConfig.current.entry(_workerGroup, status), compact: compact);

/// The business's view of the same stage, named after its list.
StatusPill businessStatusPill(String status) =>
    _pill(UiConfig.current.entry(_businessGroup, status));

StatusPill _pill(UiLabel entry, {bool compact = false}) => StatusPill(
  label: entry.label,
  tone: entry.statusTone,
  icon: entry.iconData,
  compact: compact,
);
