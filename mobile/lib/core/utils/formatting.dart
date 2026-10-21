/// One place for the strings the whole app renders money, dates and rates with.
///
/// These had grown into nine near-identical `switch (priceType)` blocks and two copies of the
/// month-name list. A label that differs by a slash between two screens reads as two different
/// apps, and a currency rule changed in one place and missed in eight is a bug waiting to be
/// reported by a customer rather than by a test.
library;

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

// Every date below is shown in the phone's own time. The server sends UTC, and a screen that
// forgot `.toLocal()` showed the business a job at 10:00 that the customer saw at 15:30. Converting
// here covers every caller; on a date that is already local it changes nothing.

/// "14 Sep 2026".
String formatDate(DateTime date) {
  final d = date.toLocal();
  return '${d.day} ${_months[d.month - 1]} ${d.year}';
}

/// "14 Sep" — for rows where the year is obvious from context.
String formatDayMonth(DateTime date) {
  final d = date.toLocal();
  return '${d.day} ${_months[d.month - 1]}';
}

/// "15:30", 24-hour and zero-padded.
String formatTime(DateTime date) {
  final d = date.toLocal();
  return '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';
}

/// "Today" / "Tomorrow" / "In 3 days" / "Yesterday" / "5 days ago".
///
/// A bare date makes the reader count; this says the thing they were counting towards. Shown
/// beside the real date rather than instead of it, so nothing is lost. [now] is injectable so
/// tests do not depend on the day they run.
String relativeDayLabel(DateTime date, {DateTime? now}) {
  final days = date.difference(now ?? DateTime.now()).inDays;
  if (days == 0) return 'Today';
  if (days == 1) return 'Tomorrow';
  if (days > 1) return 'In $days days';
  if (days == -1) return 'Yesterday';
  return '${-days} days ago';
}

/// Money in the Indian grouping convention — ₹1,50,000 rather than ₹150,000.
///
/// The last three digits group together, then every two after that. Paise are shown only when
/// the amount actually has them, so a whole-rupee wage does not read as a precise invoice.
String rupees(num amount) {
  final negative = amount < 0;
  final value = amount.abs();
  final whole = value.floor();
  final paise = ((value - whole) * 100).round();

  var digits = whole.toString();
  String grouped;

  if (digits.length <= 3) {
    grouped = digits;
  } else {
    final lastThree = digits.substring(digits.length - 3);
    var rest = digits.substring(0, digits.length - 3);
    final parts = <String>[];

    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);

    grouped = '${parts.join(',')},$lastThree';
  }

  final fraction = paise == 0 ? '' : '.${paise.toString().padLeft(2, '0')}';
  return '${negative ? '-' : ''}₹$grouped$fraction';
}

/// How a service's price is quoted: `Fixed`, `Hourly`, `Daily`, `PerPerson`.
///
/// The server sends these as enum names, so they are matched as written rather than parsed.
class PriceType {
  const PriceType._();

  static const fixed = 'Fixed';
  static const hourly = 'Hourly';
  static const daily = 'Daily';

  /// A rate per worker. The crew size — and so the total — is agreed per booking.
  static const perPerson = 'PerPerson';
}

/// Whether the total depends on a crew size nobody has agreed yet.
///
/// The one price type where the figure on a service is not what the job costs, so every screen
/// showing a price has to say what the number means rather than just print it.
bool isPerPersonPrice(String? priceType) => priceType == PriceType.perPerson;

/// "/hr" — the short suffix beside a figure.
String priceUnitSuffix(String priceType) => switch (priceType) {
  PriceType.hourly => '/hr',
  PriceType.daily => '/day',
  PriceType.perPerson => ' per person',
  _ => '',
};

/// "per hour" — the spelled-out form, for a line of its own under a figure.
String priceUnitWords(String priceType) => switch (priceType) {
  PriceType.hourly => 'per hour',
  PriceType.daily => 'per day',
  PriceType.perPerson => 'per person',
  _ => '',
};

/// "₹500/hr" — a price with its unit attached.
String priceLabel(double price, String priceType) =>
    '${rupees(price)}${priceUnitSuffix(priceType)}';

/// "20 × ₹500 = ₹10,000" — a per-person price with its working shown.
///
/// The arithmetic is spelled out rather than only the total, because the number of people is the
/// thing being negotiated: a business dropping from 20 to 18 should be able to see why the figure
/// moved, and so should the customer.
String perPersonTotalLabel(double rate, int workerCount) =>
    '$workerCount × ${rupees(rate)} = ${rupees(rate * workerCount)}';

/// "Rate per hour (INR)" — the form-field label that matches the chosen price type.
String rateFieldLabel(String priceType) => switch (priceType) {
  PriceType.hourly => 'Rate per hour (INR)',
  PriceType.daily => 'Rate per day (INR)',
  PriceType.perPerson => 'Rate per person (INR)',
  _ => 'Price (INR)',
};

/// "Typical duration (hours)" — the duration field's label follows the same choice.
///
/// Per person is priced by headcount, not by time, so its duration is entered in plain minutes
/// like a fixed-price job.
String durationFieldLabel(String priceType) => switch (priceType) {
  PriceType.hourly => 'Typical duration (hours)',
  PriceType.daily => 'Typical duration (days)',
  _ => 'Duration (mins)',
};

/// How a wage is quoted on a hiring post: `PerEvent`, `PerDay`, `PerHour`.
class SalaryUnit {
  const SalaryUnit._();

  static const perEvent = 'PerEvent';
  static const perDay = 'PerDay';
  static const perHour = 'PerHour';
}

/// "per event" — a wage's unit, spelled out.
String salaryUnitWords(String salaryUnit) => switch (salaryUnit) {
  SalaryUnit.perHour => 'per hour',
  SalaryUnit.perDay => 'per day',
  _ => 'per event',
};

/// "45 min" / "2 hr" / "1 hr 30 min".
String formatDuration(int minutes) {
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '$hours hr' : '$hours hr $rest min';
}

/// "19 hrs" / "2 days" — how long something took, from an hour count.
String formatHoursElapsed(double hours) {
  if (hours < 1) return 'under an hour';
  if (hours < 48) return '${hours.round()} hrs';
  return '${(hours / 24).round()} days';
}
