import 'package:zuno/features/vacancy/domain/entities/vacancy.dart';

/// The listing fee waiting to be paid. The amount is the server's, from its fee plan table.
class VacancyPayment {
  const VacancyPayment({
    required this.vacancyId,
    required this.planName,
    required this.amount,
    required this.listingDays,
    this.providerOrderId,
    this.razorpayKeyId,
    required this.nothingToCollect,
    this.vacancy,
  });

  final String vacancyId;
  final String planName;
  final double amount;
  final int listingDays;
  final String? providerOrderId;
  final String? razorpayKeyId;

  /// No payment window to open: a free plan, or simulated collection in development.
  final bool nothingToCollect;

  /// Set when a free plan settled at once — the vacancy is already live.
  final Vacancy? vacancy;
}

/// One page of a cursor-paged list. [nextBefore] is null on the last page.
class VacancyPage<T> {
  const VacancyPage({required this.items, this.nextBefore});

  final List<T> items;
  final DateTime? nextBefore;
}
